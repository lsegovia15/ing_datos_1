# Plan de correcciones y reparto de tareas

**Fecha de revisión:** 2026-11-03  
**Entrega:** 2026-11-05  
**Rama que contiene este documento:** `lucas`  
**Alcance revisado:** PDF `TRABAJO PRA'CTICO INTEGRADOR Base de Datos.pdf` y scripts `sql/*.sql` + `sql/sp/*.sql`. No se evaluaron los `.md` ni el `.docx`.

**Equipo de trabajo:** Jairo, Martin, Martina y Santi.  
**Nota:** Lucas no forma parte del reparto de tareas; deja este documento en la rama `lucas` como base para que el equipo ejecute los pendientes.

> **Nota (2026-11-04):** este plan se escribió sobre la versión anterior de `sql/siam_triggers.sql` (13 triggers basados en movimientos de stock). Esa versión se simplificó a 8 triggers. Los ítems A3, A5, A6 y A13 y las referencias a `TR_*_CambioEstado`, `TR_*_UsuarioActivo`, `TR_MovimientoStock_*` y `TR_DetalleVenta_*` ya no se corresponden con el código. El estado vigente está en `documentacion/14_triggers.md`.

---

## 1. Estado general

La revisión se ejecutó contra SQL Server 2025 con `sqlcmd -b`. El script `00_master.sql` termina con **código 0** y deja la base en el estado del seed.

Estado actual:

- 18 tablas, 4 vistas, 2 funciones, 6 stored procedures, 13 triggers y 1 cursor.
- Los 9 casos de error del seed se capturan correctamente.
- `DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS` no reporta violaciones.
- La consistencia entre `VarianteProducto.StockActual` y la suma de `MovimientoStock` no devuelve diferencias.
- Las vistas, funciones, cursor y consultas de `Subconsultas.sql` / `ConsultasAvanzadas.sql` ejecutan sin error.
- Las pruebas de seguridad con `usr_vendedor` y `usr_admin` funcionan en general.

**No hay errores bloqueantes.** Los puntos de este documento son correcciones y mejoras para dejar el TP más sólido antes de la entrega.

---

## 2. Resumen de tareas

| ID | Prioridad | Tarea | Responsable | Archivos principales |
|---|---|---|---|---|
| A1 | Alta | Excluir ventas anuladas de las subconsultas | Jairo | `sql/Subconsultas.sql`, `sql/sp/ConsultasAvanzadas.sql` |
| A2 | Alta | Vincular `@IdUsuario` con el login de base de datos | Santi | `sql/sp/SP_RegistrarVenta.sql`, `sql/seguridad.sql` (coordinar) |
| A3 | Alta | Bloquear escrituras directas que saltean stock/SPs | Martin | `sql/siam_triggers.sql`, `sql/seguridad.sql` (coordinar con Santi) |
| A4 | Alta | Crear `SP_AnularCompra` y usarlo en el seed | Santi | `sql/sp/SP_AnularCompra.sql` (nuevo), `sql/00_master.sql`, `sql/seguridad.sql`, `sql/seed_data.sql` (coordinar con Martin) |
| A5 | Media | Cerrar alertas de stock cuando se repone el stock | Martin | `sql/siam_triggers.sql`, `sql/seed_data.sql` |
| A6 | Media | Agregar pruebas de triggers faltantes al seed | Martin | `sql/seed_data.sql` |
| A7 | Media | Documentar subconsultas y vistas dentro del SQL | Jairo | `sql/Subconsultas.sql`, `sql/sp/ConsultasAvanzadas.sql`, `sql/vistas.sql` |
| A8 | Media | Documentar cursor y funciones dentro del SQL | Martina | `sql/cursores.sql`, `sql/funciones.sql` |
| A9 | Media | Revisar semántica de `> ALL` (`PrecioVenta` vs `PrecioBase`) | Jairo | `sql/Subconsultas.sql`, `sql/sp/ConsultasAvanzadas.sql` |
| A10 | Baja | Unicidad de `NroComprobante` y limpieza de `CK_Mov_Cantidad` duplicada | Martina | `sql/init_db.sql`, `sql/siam_triggers.sql` |
| A11 | Baja | Hardening: hash con sal, contraseñas y datos personales | Santi | `sql/seed_data.sql`, `sql/seguridad.sql` |
| A12 | Baja | Validaciones tempranas en `SP_RegistrarVenta` | Santi | `sql/sp/SP_RegistrarVenta.sql` |
| A13 | Baja | `TR_*_UsuarioActivo` también en `UPDATE` | Martin | `sql/siam_triggers.sql` |
| A14 | Baja | Alternativa a `00_master.sql` sin SQLCMD Mode | Martina | `sql/00_master.sql`, `docs/ORDEN_EJECUCION.md` |
| A15 | Baja | Corregir permiso de TVF: `EXECUTE` → `SELECT` | Santi | `sql/seguridad.sql` |

**Reparto por persona:**

- **Jairo:** A1, A7, A9.
- **Martin:** A3, A5, A6, A13.
- **Martina:** A8, A10, A14.
- **Santi:** A2, A4, A11, A12, A15.

---

## 3. Detalle y criterios de aceptación

### A1 — Excluir ventas anuladas de las subconsultas

**Responsable:** Jairo  
**Prioridad:** Alta

En `sql/Subconsultas.sql` y `sql/sp/ConsultasAvanzadas.sql` hay subconsultas sobre `Venta` que no filtran el estado. Hoy una venta anulada sigue contando como compra/venta realizada.

Casos concretos:

- `sql/Subconsultas.sql:9-17`: clientes que compraron ropa de la categoría `Buzos`.
- `sql/Subconsultas.sql:20-27`: productos que nunca tuvieron ventas.
- `sql/sp/ConsultasAvanzadas.sql:84-93`: productos que nunca se vendieron.

**Pista:** agregar `AND v.Estado = 'CONFIRMADA'` dentro del `WHERE` de la subconsulta correspondiente. Revisar también que el `LEFT JOIN`/`INNER JOIN` no pierda ventas válidas.

**Aceptación:**

- Una venta anulada no hace que un cliente aparezca como comprador.
- Un producto que solo participó en ventas anuladas aparece como “nunca vendido”.
- Las consultas siguen ejecutando sin error.

---

### A2 — Vincular `@IdUsuario` con el login de base de datos

**Responsable:** Santi  
**Prioridad:** Alta

`SP_RegistrarVenta` valida el rol del `@IdUsuario` recibido, pero no lo relaciona con el principal de SQL Server que ejecuta el SP. Lo probé: `usr_vendedor` puede ejecutar:

```sql
EXEC dbo.SP_RegistrarVenta
    @IdCliente = 1,
    @IdUsuario = 1, -- administrador
    ...
```

y la venta queda atribuida al administrador.

**Impacto:** no permite ejecutar operaciones de admin (esas están denegadas por permisos), pero rompe la trazabilidad y la auditoría.

**Pista:** mapear `USER_NAME()` / `SUSER_SNAME()` contra `Usuario` mediante una tabla de mapeo o `SESSION_CONTEXT`; o validar que el `@IdUsuario` corresponda al login autenticado. Si se agrega una columna/tabla, actualizar `init_db.sql` y el seed.

**Aceptación:**

- `usr_vendedor` no puede registrar una venta con `@IdUsuario = 1`.
- `usr_vendedor` sí puede registrar una venta con su propio usuario.
- `usr_admin` puede registrar ventas con su propio usuario.
- El cambio queda documentado en `docs/SEGURIDAD.md`.

---

### A3 — Bloquear escrituras directas que saltean stock/SPs

**Responsable:** Martin  
**Prioridad:** Alta  
**Coordinar con:** Santi (dueño de `sql/seguridad.sql`)

`sql/seguridad.sql:91` otorga al administrador:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_administrador;
```

Eso permite saltar la lógica centralizada:

- `INSERT INTO Compra (..., Estado) VALUES (..., 'RECIBIDA')` sin generar movimientos de stock, porque `TR_Compra_CambioEstado` solo actúa en `UPDATE`.
- `UPDATE VarianteProducto SET StockActual = ...` sin registrar un `MovimientoStock`.
- Insertar cabeceras de venta/compra sin pasar por los SPs.

**Pista:** elegir una de estas estrategias (o combinarlas):

1. Quitar el DML a nivel schema en `seguridad.sql` y otorgar permisos por objeto/SP.
2. Agregar triggers de validación/`INSTEAD OF` que bloqueen escrituras directas sobre `Venta`, `Compra` y `VarianteProducto`.
3. Usar `SESSION_CONTEXT` para permitir solo las escrituras que vienen de los SPs, similar a `PermitirDetalleVenta`.

**Aceptación:**

- Un `INSERT` directo de `Compra` con `Estado = 'RECIBIDA'` no deja stock sin movimiento.
- Un `UPDATE` directo de `VarianteProducto.StockActual` no puede modificar el stock sin un `MovimientoStock`.
- Los SPs y el seed siguen funcionando.
- Se agrega al seed al menos una prueba de escritura directa bloqueada.

---

### A4 — Crear `SP_AnularCompra` y usarlo en el seed

**Responsable:** Santi  
**Prioridad:** Alta  
**Coordinar con:** Martin (dueño de `sql/seed_data.sql`)

Hoy el seed anula una compra con un `UPDATE` directo:

```sql
-- sql/seed_data.sql:179-181
UPDATE dbo.Compra
SET Estado = 'ANULADA'
WHERE IdCompra = 3;
```

El trigger valida la transición, pero no hay un SP con validaciones y manejo de errores como en ventas.

**Pista:** crear `sql/sp/SP_AnularCompra.sql` con:

- Parámetros `@IdCompra` y `@IdUsuario`.
- Validación de usuario activo y rol `Administrador`.
- Transacción y bloqueo de la compra.
- Validación de estado `PENDIENTE`.
- `UPDATE` a `ANULADA` (sin mover stock).
- `TRY/CATCH`, `THROW` y `ROLLBACK`.
- Mensaje de éxito.

Agregar el archivo a `sql/00_master.sql` y los permisos a `sql/seguridad.sql`. Reemplazar el `UPDATE` directo del seed por `EXEC dbo.SP_AnularCompra`.

**Aceptación:**

- `SP_AnularCompra` funciona con una compra `PENDIENTE`.
- Rechaza compras inexistentes, ya anuladas o recibidas.
- Rechaza usuarios vendedores o inactivos.
- El seed usa el SP y sigue terminando con código 0.

---

### A5 — Cerrar alertas de stock cuando se repone el stock

**Responsable:** Martin  
**Prioridad:** Media

`TR_Variante_AlertaStock` (`sql/siam_triggers.sql:336-349`) solo inserta alertas cuando el stock cruza el mínimo. No marca `Atendida = 1` cuando el stock se repone. El seed cierra solo las alertas iniciales manualmente (`sql/seed_data.sql:146-153`).

**Pista:** en el mismo trigger, cuando `StockActual > StockMinimo`, actualizar a `Atendida = 1` las alertas abiertas de esa variante. Mantener el insert actual para cuando el stock cruce hacia abajo.

**Aceptación:**

- Al recibir una compra que deja el stock por encima del mínimo, las alertas abiertas de esa variante quedan atendidas.
- Al vender y cruzar el mínimo, se genera una nueva alerta.
- El seed demuestra ambos casos.

---

### A6 — Agregar pruebas de triggers faltantes al seed

**Responsable:** Martin  
**Prioridad:** Media

El seed prueba ventas, compras, ajustes y errores, pero no ejercita:

- `TR_Variante_HistorialPrecio` (no hay cambio de precio).
- `TR_MovimientoStock_Inmutable`.
- `TR_Venta_NoBorrar` / `TR_Compra_NoBorrar`.
- `TR_DetalleVenta_Inmutable`.
- `TR_Venta_UsuarioActivo` / `TR_Compra_UsuarioActivo` (los SPs rechazan antes de llegar al trigger).
- El bloqueo de inserción directa en `DetalleVenta`.

**Pista:** agregar casos con `BEGIN TRY` / `BEGIN CATCH` y `SELECT 'CASO' AS Caso, ERROR_MESSAGE() AS Resultado`, igual que los casos 8.x actuales.

**Aceptación:**

- Cada trigger tiene al menos un caso de prueba en el seed o en un script de pruebas.
- Los errores esperados se capturan sin abortar el seed.
- El resumen final del seed sigue mostrando counts coherentes.

---

### A7 — Documentar subconsultas y vistas dentro del SQL

**Responsable:** Jairo  
**Prioridad:** Media

El PDF pide que cada subconsulta explique:

- Qué información se desea obtener.
- Qué función cumple la subconsulta.
- Por qué es adecuada.

Y que cada vista documente:

- Objetivo.
- Información presentada.
- Tablas involucradas.
- Motivo de utilización.

En los `.sql` hay comentarios, pero no están completos. Si la corrección se hace solo sobre el SQL, esto queda flojo.

**Pista:** agregar bloques de comentario antes de cada subconsulta/vista. No reemplazar la documentación existente; complementarla.

**Aceptación:**

- Cada subconsulta de `Subconsultas.sql` y `ConsultasAvanzadas.sql` tiene los 3 puntos.
- Cada vista de `vistas.sql` tiene objetivo, información, tablas y motivo.
- No se modifica la lógica de las consultas en esta tarea.

---

### A8 — Documentar cursor y funciones dentro del SQL

**Responsable:** Martina  
**Prioridad:** Media

El PDF pide para el cursor:

- Problema que resuelve.
- Motivo por el cual se usa un cursor.
- Registros procesados.
- Operación realizada sobre cada registro.

Y para cada función:

- Objetivo.
- Parámetros.
- Tipo de retorno.
- Lógica implementada.
- Ejemplo de utilización.

**Pista:** agregar comentarios en `sql/cursores.sql` y `sql/funciones.sql`. Incluir un ejemplo de `SELECT dbo.fn_EstadoStock(1)` y de `SELECT * FROM dbo.fn_ResumenVentasPorUsuario(...)`.

**Aceptación:**

- El cursor y ambas funciones tienen la documentación solicitada.
- Los ejemplos son ejecutables contra el seed.
- No se modifica la lógica en esta tarea.

---

### A9 — Revisar semántica de `> ALL` (`PrecioVenta` vs `PrecioBase`)

**Responsable:** Jairo  
**Prioridad:** Media

En `sql/Subconsultas.sql:28-36` y `sql/sp/ConsultasAvanzadas.sql:95-103` se compara `VarianteProducto.PrecioVenta` contra `Producto.PrecioBase` de la marca `Nangallery`. Son dos conceptos de precio distintos.

**Pista:** decidir si la comparación correcta es contra `PrecioVenta` de las variantes de esa marca o contra `PrecioBase` de sus productos. Ajustar el comentario y la consulta para que la explicación coincida con la lógica.

**Aceptación:**

- La consulta y su comentario usan el mismo criterio de precio.
- El resultado sigue siendo coherente con el seed.
- La explicación queda documentada.

---

### A10 — Unicidad de `NroComprobante` y limpieza de `CK_Mov_Cantidad`

**Responsable:** Martina  
**Prioridad:** Baja  
**Coordinar con:** Martin (`siam_triggers.sql`)

Dos puntos de esquema:

1. `Compra.NroComprobante` (`sql/init_db.sql:131`) no es único. Si el número de comprobante debe ser único, falta la restricción.
2. `CK_Mov_Cantidad` se crea en `sql/init_db.sql:203-206` y se vuelve a crear en `sql/siam_triggers.sql:6-10`. Es redundante.

**Pista:** definir con el equipo si `NroComprobante` debe ser único. Si sí, agregar `UNIQUE` o un índice único filtrado para permitir `NULL`. Eliminar la recreación duplicada del check o dejar una sola fuente de verdad.

**Aceptación:**

- La decisión sobre `NroComprobante` queda aplicada y documentada.
- `CK_Mov_Cantidad` se define una sola vez.
- `00_master.sql` sigue ejecutando sin error.

---

### A11 — Hardening: hash con sal, contraseñas y datos personales

**Responsable:** Santi  
**Prioridad:** Baja

Puntos detectados:

- `sql/seed_data.sql:28-29` usa `HASHBYTES('SHA2_256', '...')` sin sal.
- `sql/seguridad.sql:16-17` y `25-26` tienen contraseñas de logins hardcodeadas.
- `sql/seguridad.sql:128` permite al vendedor leer todos los datos de `Cliente` (DNI, email, teléfono, dirección).

**Pista:** usar un hash con sal por usuario; mover las contraseñas a parámetros/variables de entorno o dejar una nota clara de cambio obligatorio; evaluar si el vendedor necesita todas las columnas de `Cliente` o solo algunas.

**Aceptación:**

- El seed no guarda contraseñas en texto plano ni hashes sin sal.
- Las contraseñas de logins no quedan fijas en el script o quedan marcadas como “cambiar en producción”.
- Se justifica el acceso del vendedor a los datos de `Cliente`.

---

### A12 — Validaciones tempranas en `SP_RegistrarVenta`

**Responsable:** Santi  
**Prioridad:** Baja

`SP_RegistrarVenta` valida stock y variantes, pero no valida antes de insertar:

- `Cantidad > 0`.
- `PrecioUnitario >= 0`.
- `Descuento >= 0` y `Descuento <= Cantidad * PrecioUnitario`.
- `MedioPago` permitido.

Hoy lo resuelven los `CHECK` constraints, pero el mensaje de error es genérico.

**Pista:** agregar `THROW` con mensajes claros antes de la transacción, similar a las validaciones de compras. Mantener los `CHECK` como última defensa.

**Aceptación:**

- Los casos inválidos devuelven un error claro del SP.
- Los `CHECK` siguen existiendo.
- Se agregan casos al seed o a un script de pruebas.

---

### A13 — `TR_*_UsuarioActivo` también en `UPDATE`

**Responsable:** Martin  
**Prioridad:** Baja

`TR_Venta_UsuarioActivo` y `TR_Compra_UsuarioActivo` (`sql/siam_triggers.sql:94-119`) solo validan `INSERT`. Si una venta/compra se actualiza para apuntar a un usuario inactivo, no se bloquea.

**Pista:** cambiar el trigger a `AFTER INSERT, UPDATE` y validar `inserted` en ambos casos.

**Aceptación:**

- Insertar una venta/compra con usuario inactivo se bloquea.
- Actualizar una venta/compra a un usuario inactivo también se bloquea.
- Los SPs siguen funcionando.

---

### A14 — Alternativa a `00_master.sql` sin SQLCMD Mode

**Responsable:** Martina  
**Prioridad:** Baja

`sql/00_master.sql` usa `:on error exit`, `:setvar` y `:r`, por lo que requiere SQLCMD Mode o `sqlcmd`. Si el docente lo abre en SSMS sin SQLCMD Mode, falla.

**Pista:** mantener `00_master.sql` para SQLCMD y agregar en `docs/ORDEN_EJECUCION.md` una sección “alternativa SSMS sin SQLCMD Mode” con el orden manual de ejecución. Opcionalmente, generar un script único consolidado.

**Aceptación:**

- El orden manual está documentado y probado.
- `00_master.sql` sigue funcionando con `sqlcmd`.
- No se duplica lógica innecesariamente.

---

### A15 — Corregir permiso de TVF: `EXECUTE` → `SELECT`

**Responsable:** Santi  
**Prioridad:** Baja

`sql/seguridad.sql:100` hace:

```sql
GRANT EXECUTE ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;
```

Para una función table-valued el permiso canónico es `SELECT`. El script también otorga `SELECT`, por lo que no falla, pero conviene dejarlo correcto.

**Pista:** cambiar a `GRANT SELECT ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;` y revisar el `DENY` del vendedor.

**Aceptación:**

- El admin puede consultar la función.
- El vendedor sigue sin acceso.
- `seguridad.sql` ejecuta sin error.

---

## 4. Archivos y responsables (para evitar conflictos)

| Archivo | Dueño principal | Otros que pueden necesitar tocarlo |
|---|---|---|
| `sql/Subconsultas.sql` | Jairo | — |
| `sql/sp/ConsultasAvanzadas.sql` | Jairo | — |
| `sql/vistas.sql` | Jairo | — |
| `sql/cursores.sql` | Martina | — |
| `sql/funciones.sql` | Martina | — |
| `sql/init_db.sql` | Martina | Santi (si A2 agrega tabla/columna) |
| `sql/00_master.sql` | Martina | Santi (A4), Martin (A5/A6) |
| `sql/siam_triggers.sql` | Martin | Martina (A10) |
| `sql/seed_data.sql` | Martin | Santi (A4/A11) |
| `sql/seguridad.sql` | Santi | Martin (A3), Martina (A10) |
| `sql/sp/SP_RegistrarVenta.sql` | Santi | — |
| `sql/sp/SP_AnularCompra.sql` | Santi | — |

**Regla:** si una tarea necesita tocar un archivo de otro dueño, avisar en el PR y coordinar antes de mergear. Evitar refactors masivos y cambios de formato que generen conflictos.

---

## 5. Flujo de trabajo sugerido

1. Actualizar la rama base:

   ```bash
   git checkout lucas
   git pull origin lucas
   ```

2. Crear una rama personal o una rama por tarea:

   ```bash
   git checkout -b fix/jairo-subconsultas
   # o fix/martin-triggers, fix/martina-docs, fix/santi-sp
   ```

3. Implementar la tarea y ejecutar las validaciones.

4. Commit con mensaje claro:

   ```bash
   git add <archivos>
   git commit -m "fix(sql): excluir ventas anuladas en subconsultas"
   git push -u origin fix/jairo-subconsultas
   ```

5. Abrir PR contra `develop` (o contra `lucas` si el equipo decide integrar ahí). No hacer push directo a `lucas`/`develop` sin revisión.

6. En el PR incluir:
   - Qué se cambió.
   - Cómo se probó.
   - Resultado de `00_master.sql`.
   - Capturas o salida de los casos de prueba.

---

## 6. Validación mínima antes de cerrar cada tarea

Ejecutar desde la carpeta `sql`:

```bash
sqlcmd -S localhost -E -C -b -i 00_master.sql
sqlcmd -S localhost -E -C -b -i Subconsultas.sql
sqlcmd -S localhost -E -C -b -i sp/ConsultasAvanzadas.sql
```

Verificar:

```sql
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
```

Verificar consistencia de stock:

```sql
SELECT v.IdVariante, v.StockActual,
       ISNULL(SUM(CASE WHEN m.TipoMovimiento = 'SALIDA'
                       THEN -m.Cantidad ELSE m.Cantidad END), 0) AS StockCalculado
FROM dbo.VarianteProducto v
LEFT JOIN dbo.MovimientoStock m ON m.IdVariante = v.IdVariante
GROUP BY v.IdVariante, v.StockActual
HAVING v.StockActual <> ISNULL(SUM(CASE WHEN m.TipoMovimiento = 'SALIDA'
                                        THEN -m.Cantidad ELSE m.Cantidad END), 0);
```

La consulta de stock no debe devolver filas.

Pruebas de seguridad mínimas:

- `usr_vendedor` no puede leer `Usuario.Contrasena`.
- `usr_vendedor` no puede leer `Compra`.
- `usr_vendedor` no puede actualizar `VarianteProducto`.
- `usr_vendedor` no puede ejecutar `SP_AnularVenta`, `SP_AjustarStock`, `SP_RegistrarCompra` ni `SP_RecibirCompra`.
- `usr_vendedor` sí puede ejecutar `SP_RegistrarVenta`.
- `usr_admin` no puede leer `Usuario.Contrasena`.
- `usr_admin` no puede borrar `Venta` ni `Compra`.

---

## 7. Orden recomendado de trabajo

1. **A1, A2 y A4** primero: son las que más impactan en la corrección funcional y en la seguridad.
2. **A3 y A5** después: integridad de stock y centralización.
3. **A6** para dejar evidencia de pruebas.
4. **A7, A8 y A9**: documentación y semántica.
5. **A10 a A15**: mejoras menores, si queda tiempo antes de la entrega.

---

## 8. Pendiente de repositorio

- La rama local `lucas` estaba 2 commits adelante de `origin/lucas` antes de agregar este documento. Verificar que todo quede pusheado antes de la entrega.
- Cada integrante debe mantener su rama personal y su contribución visible en GitHub, según lo pide el PDF.
