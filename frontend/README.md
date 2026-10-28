# Panel de pruebas SIAM

Frontend web para probar la base **SIAM** (tablas, SPs, vistas y triggers) sin escribir consultas a mano.
Se conecta a un SQL Server real y ejecuta los scripts del repo tal cual están.

## Qué permite hacer

| Sección | Qué hace |
|---|---|
| **Inicio / Reiniciar base** | Borra y recrea `SIAM` corriendo los scripts del repo en orden (`init_db` → datos de prueba → TVP → SPs → vistas → triggers). Se pueden destildar scripts (por ej. probar los SPs sin triggers). Muestra los errores de cada lote. |
| **Tablas** | Ver, insertar, editar y borrar filas de cualquier tabla. Las FK se eligen con desplegables y se muestran los triggers de cada tabla. Los errores de constraints/triggers se ven tal cual los devuelve SQL Server. |
| **Procedimientos (SP)** | Formulario generado automáticamente para cada SP, incluido el parámetro tabla `@Detalle` (`TipoDetalleVenta`) de `SP_RegistrarVenta`. Después de ejecutar muestra el **efecto en la base**: cambios de stock y movimientos nuevos. |
| **Vistas** | Consulta cualquier vista y avisa si alguna de `vistas.sql` no se pudo crear. |
| **Consultas y escenarios** | Consola SQL (acepta `GO`) con consultas de control, las de `Subconsultas.sql` y **escenarios de triggers** listos para ejecutar (recibir compra, anular venta, usuario inactivo, borrar venta, historial de precios, alerta de stock, etc.). |

## Cómo levantarlo

Requisitos: Node 18+ y un SQL Server con **autenticación SQL** (usuario/contraseña).

1. (Opcional) Si no tenés SQL Server, levantá uno con Docker:
   ```bash
   cd frontend
   docker compose up -d
   ```
2. Configurá la conexión:
   ```bash
   cp .env.example .env
   ```
   Si usás tu SQL Server local (SSMS), poné tu usuario y contraseña. Para `SQLEXPRESS` completá `DB_INSTANCE=SQLEXPRESS` y dejá `DB_PORT` vacío (tiene que estar activo el servicio SQL Server Browser y TCP/IP).
3. Instalá y arrancá:
   ```bash
   npm install
   npm start
   ```
4. Abrí http://localhost:3000 y tocá **Borrar y recrear la base**.

> El servidor escucha solo en `localhost`. La consola SQL ejecuta cualquier cosa: es una herramienta de prueba, no la expongas.

## Revisión de ramas (octubre 2026)

| Rama | Estado |
|---|---|
| `main` | `init_db.sql` con tablas, FKs e índices. Sin SPs, vistas ni triggers. |
| `develop` / `lucas` | Lo más completo: `main` + SPs (`SP_RegistrarVenta`, `SP_AnularVenta`, `SP_AjustarStock`), tipo `TipoDetalleVenta`, `vistas.sql`, `Subconsultas.sql` y docs de SPs. `lucas` es igual a `develop`. |
| `santiago` | `develop` sin el último commit (le faltan vistas y subconsultas). |
| `martin` | `main` + `sql/firme38_triggers.sql` (14 triggers + tablas `HistorialPrecio` y `AlertaStock`). **Todavía no está mergeada en `develop`.** |
| `Jairo`, `martina` | Ramas viejas del inicio del proyecto (README / primera versión de tablas). Nada que no esté ya en `develop`. |

Este frontend está en una rama basada en `develop` con `martin` mergeada, para poder probar todo junto.

### Problemas encontrados al ejecutar todo junto

Todos se reproducen desde el panel (sección SP → "Efecto en la base", o la consulta *Coherencia stock vs movimientos*):

1. **`vistas.sql`: 2 de 3 vistas no compilan.**
   - `vw_StockVariate`: `ON v.IdCategoria = p.IdProducto`. Debería ser `ON v.IdProducto = p.IdProducto`.
   - `vw_ProductosPremium`: `p.Precio` no existe. Es `p.PrecioBase`.
2. **SP + triggers duplican los movimientos de stock.** Los SPs se escribieron pensando en un trigger que solo actualice el stock, pero los triggers de `martin` también generan los movimientos:
   - `SP_RegistrarVenta` inserta `DetalleVenta` (eso dispara `TR_DetalleVenta_Insert`, que ya genera la `SALIDA`) y después inserta **otra** `SALIDA`. Vender 1 unidad descuenta 2.
   - `SP_AnularVenta` hace `UPDATE Venta SET Estado='ANULADA'` (eso dispara `TR_Venta_CambioEstado`, que ya genera la `DEVOLUCION`) y después inserta **otra** `DEVOLUCION`.
   - Hay que decidir quién genera los movimientos: o el SP o el trigger, no los dos.
3. **`SP_AjustarStock` suma cuando debería restar.** Guarda `ABS(@Diferencia)` y el trigger trata `AJUSTE` siempre como suma. Ajustar de 15 a 10 deja el stock en 20. Como `firme38_triggers.sql` ya permite `AJUSTE` negativo, alcanza con guardar `@Diferencia` sin `ABS`.
4. **Se pierde el número de error.** Los `CATCH` re-lanzan con `RAISERROR(@ErrorMessage, ...)`, así que todo error de negocio llega como `50000` en vez de `50001…50022`. Con `THROW;` (sin parámetros) se conserva el número original.
5. **Códigos de error repetidos:** `50002` es "usuario no existe" en `SP_RegistrarVenta` y "stock insuficiente" en `TR_MovimientoStock_AplicarStock`.
6. `SP_RegistrarVenta.sql` no tiene `USE SIAM; GO` al principio, a diferencia de los otros SPs. Si se ejecuta desde `master`, el SP queda creado en `master`.
7. No hay script de datos de prueba en el repo. Este panel trae `frontend/seed.sql` (roles, usuarios, uno de ellos inactivo, catálogo, variantes con stock, clientes, proveedores y una compra `PENDIENTE`).
