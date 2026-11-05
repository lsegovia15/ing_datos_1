# 18. Seguridad de la base de datos

Script: `sql/seguridad.sql`

La seguridad se aplica en dos niveles que se complementan:

| Nivel | Qué controla | Dónde |
|---|---|---|
| Motor (SQL Server) | Quién se conecta y qué objetos puede usar | Logins, usuarios y roles de base de datos, con `GRANT` (y `REVOKE` para quitar) |
| Aplicación | Qué empleado hace cada operación y con qué rol de negocio | Tablas `Rol` y `Usuario`, validadas dentro de los SPs |

Los roles del motor (`rol_administrador`, `rol_vendedor`) son distintos de la tabla `Rol` (`Administrador`, `Vendedor`): los primeros limitan el acceso a los objetos y los segundos identifican al empleado dentro del negocio.

## Logins, usuarios y roles

| Login de servidor | Usuario de base | Rol de base | Perfil |
|---|---|---|---|
| `login_admin_siam` | `usr_admin` | `rol_administrador` | Administrador del local |
| `login_vendedor_siam` | `usr_vendedor` | `rol_vendedor` | Vendedor |

- Los logins son del servidor y no se borran al recrear la base, por eso el script los crea solo si todavía no existen (`IF NOT EXISTS`). Usuarios y roles se crean con la base.
- Los permisos se otorgan a los **roles**, nunca a los usuarios. Para sumar un vendedor nuevo alcanza con crear su usuario y agregarlo a `rol_vendedor` (`ALTER ROLE ... ADD MEMBER`).

## Criterio: menor privilegio con GRANT

Solo se usa `GRANT`. Un rol sin `GRANT` sobre un objeto **no tiene acceso**, así que cada rol recibe únicamente lo que necesita para su trabajo.

## Matriz de permisos

| Objeto | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Catálogo (`Producto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento`) | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `SELECT` |
| `Cliente` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `SELECT` |
| `Proveedor`, `Rol` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Sin acceso |
| `Usuario` | `SELECT` de todas las columnas **salvo `Contrasena`**; `INSERT`, `UPDATE`, `DELETE` | Sin acceso |
| `VarianteProducto` | `SELECT`, `INSERT`; `UPDATE` **solo de `PrecioVenta` y `StockMinimo`** | `SELECT` |
| `Venta`, `DetalleVenta` | `SELECT` | Sin acceso (consulta por la vista) |
| `Compra`, `DetalleCompra`, `MovimientoStock`, `HistorialPrecio` | `SELECT` | Sin acceso |
| `AlertaStock` | `SELECT`, `UPDATE` (marcar atendida) | Sin acceso |
| Vistas (las 4) | `SELECT` | `SELECT` |
| `SP_RegistrarVenta`, `SP_InformeReposicionStock` | `EXECUTE` | `EXECUTE` |
| `SP_AnularVenta`, `SP_AjustarStock`, `SP_RegistrarCompra`, `SP_RecibirCompra` | `EXECUTE` | Sin acceso |
| `fn_EstadoStock` | `EXECUTE` | `EXECUTE` |
| `fn_ResumenVentasPorUsuario` | `SELECT` | Sin acceso |

Puntos importantes:

- **Ventas y compras solo por SP.** Ni el administrador tiene `INSERT`, `UPDATE` o `DELETE` sobre `Venta`, `DetalleVenta`, `Compra` y `DetalleCompra`: se registran, reciben y anulan con los stored procedures, que validan los datos y dejan el stock consistente.
- **Usuarios y contraseñas.** El vendedor no tiene acceso a la tabla `Usuario`. Al administrador el `SELECT` se le otorga **columna por columna**, sin `Contrasena`: puede gestionar usuarios, pero no leer contraseñas. Además, las contraseñas no se guardan en texto plano sino como hash SHA-256 (`HASHBYTES('SHA2_256', ...)`), así que aunque alguien accediera a la columna no vería la contraseña real.
- **Stock.** El `UPDATE` sobre `VarianteProducto` se otorga solo para `PrecioVenta` y `StockMinimo`. `StockActual` no se puede modificar directamente ni siquiera como administrador: solo cambia por compras recibidas, ventas, anulaciones y `SP_AjustarStock`, que deja registrado el movimiento.
- **Información sensible.** El resumen de ventas por usuario (`fn_ResumenVentasPorUsuario`) sirve para evaluar desempeño o calcular comisiones, por eso solo lo ve el administrador.

## Validación del rol en los SPs

Los permisos del motor no son la única barrera. Cada SP valida también el rol de aplicación del `@IdUsuario` que recibe (ver la [sección 13](13_stored_procedures.md)):

| Barrera | Ejemplo: un vendedor intenta anular una venta |
|---|---|
| Permiso del motor | `rol_vendedor` no tiene `EXECUTE` sobre `SP_AnularVenta` → error 229 |
| Validación en el SP | Si el `@IdUsuario` no es `Administrador` activo → error 50013 |
| Trigger | La devolución de stock la hace `TR_DevolverStockAnulacion` a partir del cambio de estado |

## Por qué el vendedor puede vender sin permisos sobre las tablas

Las tablas, los SPs y los triggers pertenecen a `dbo`. Cuando el vendedor ejecuta `SP_RegistrarVenta`, el SP puede insertar en `Venta` y `DetalleVenta`, y los triggers pueden actualizar `VarianteProducto`, aunque el vendedor no tenga permisos sobre esas tablas. Es lo que permite que **la única forma de operar sea a través de los SPs**.

## Verificación

Conectarse en SSMS con **SQL Server Authentication** usando `login_vendedor_siam` / `Siam_Vend_2026!` y ejecutar:

```sql
USE SIAM;

SELECT * FROM dbo.Usuario;                                               -- error 229: sin permiso
UPDATE dbo.VarianteProducto SET StockActual = 999 WHERE IdVariante = 1;  -- error 229: sin permiso
EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;                    -- error 229: sin permiso

SELECT * FROM dbo.vw_StockVariante;                                      -- funciona
EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'EFECTIVO',
     @IdVariante = 1, @Cantidad = 1;                                     -- funciona
```

Con `login_admin_siam` / `Siam_Admin_2026!`:

```sql
USE SIAM;

DELETE FROM dbo.Venta WHERE IdVenta = 1;                                 -- error 229: sin permiso
SELECT Contrasena FROM dbo.Usuario;                                      -- error 230: sin permiso sobre la columna
UPDATE dbo.VarianteProducto SET StockActual = 999 WHERE IdVariante = 1;  -- error 230: sin permiso sobre la columna
UPDATE dbo.VarianteProducto SET PrecioVenta = 19000 WHERE IdVariante = 1; -- funciona
SELECT IdUsuario, NombreUsuario, Activo FROM dbo.Usuario;                -- funciona
SELECT * FROM dbo.fn_ResumenVentasPorUsuario('2026-01-01', '2026-12-31'); -- funciona
```

Para quitar un permiso otorgado se usa `REVOKE`, por ejemplo:

```sql
REVOKE SELECT ON dbo.Cliente FROM rol_vendedor;
```

## Limitaciones

- **Contraseñas de los logins:** están escritas en el script como ejemplo. En un entorno real deben cambiarse y no guardarse en el repositorio.
- **Hash sin "sal":** las contraseñas se guardan como hash SHA-256 simple. Dos usuarios con la misma contraseña tienen el mismo hash; en un sistema real se le agregaría un valor aleatorio por usuario (sal) antes de calcularlo.
- **Usuario de la operación:** los SPs reciben el `@IdUsuario` como parámetro y no lo relacionan con el login conectado, así que un vendedor podría informar el id de otro vendedor.
- **Stock inicial:** el administrador puede dar de alta una variante (`INSERT`) indicando su stock inicial. Una vez creada, el stock ya no se puede modificar directamente.
