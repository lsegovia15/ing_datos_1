# 18. Seguridad de la base de datos

Script: `sql/seguridad.sql`

La seguridad se aplica en dos niveles que se complementan:

| Nivel | Qué controla | Dónde |
|---|---|---|
| Motor (SQL Server) | Quién se conecta y qué objetos puede usar | Logins, usuarios y roles de base de datos, con `GRANT` / `DENY` / `REVOKE` |
| Aplicación | Qué empleado hace cada operación y con qué rol de negocio | Tablas `Rol` y `Usuario`, validadas dentro de los SPs |

Los roles del motor (`rol_administrador`, `rol_vendedor`) son distintos de la tabla `Rol` (`Administrador`, `Vendedor`): los primeros limitan el acceso a los objetos y los segundos identifican al empleado dentro del negocio.

## Logins, usuarios y roles

| Login de servidor | Usuario de base | Rol de base | Perfil |
|---|---|---|---|
| `login_admin_siam` | `usr_admin` | `rol_administrador` | Administrador del local |
| `login_vendedor_siam` | `usr_vendedor` | `rol_vendedor` | Vendedor |

- Los logins se crean con `CHECK_POLICY = ON`, así que el motor rechaza contraseñas que no cumplan la política de complejidad del servidor.
- El script es **idempotente**: antes de crear un login, usuario o rol verifica que no exista (`SUSER_ID`, `DATABASE_PRINCIPAL_ID`), y antes de asignar un usuario a un rol consulta `sys.database_role_members`. Se puede ejecutar varias veces sin errores.
- Los permisos se otorgan a los **roles**, nunca a los usuarios. Para sumar un vendedor nuevo alcanza con crear su usuario y agregarlo a `rol_vendedor`.

## Matriz de permisos

| Objeto | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Catálogo (`Producto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento`) | Lectura y escritura | Solo lectura |
| `Cliente` | Lectura y escritura | Solo lectura |
| `VarianteProducto` | Lectura y escritura | Solo lectura; `INSERT`, `UPDATE` y `DELETE` denegados |
| `Venta`, `DetalleVenta` | Lectura, `INSERT` y `UPDATE`; `DELETE` denegado | `INSERT`, `UPDATE` y `DELETE` denegados; consulta por vistas |
| `Compra`, `DetalleCompra`, `Proveedor` | Lectura, `INSERT` y `UPDATE`; `DELETE` denegado en compras | Sin acceso |
| `MovimientoStock` | Lectura e `INSERT`; `UPDATE` y `DELETE` los bloquea `TR_MovimientoStock_Inmutable` | Sin acceso |
| `Usuario` | Todas las columnas salvo `Contrasena` | Todas las columnas salvo `Contrasena` |
| Vistas (las 4) | `SELECT` | `SELECT` |
| `SP_RegistrarVenta` | `EXECUTE` | `EXECUTE` |
| `SP_AnularVenta`, `SP_AjustarStock` | `EXECUTE` | `DENY EXECUTE` |
| `SP_RegistrarCompra`, `SP_RecibirCompra` | `EXECUTE` | `DENY EXECUTE` |
| `SP_InformeReposicionStock`, `fn_EstadoStock` | `EXECUTE` | `EXECUTE` |
| `fn_ResumenVentasPorUsuario` | `SELECT` | `DENY SELECT` |
| Tipos `TipoDetalleVenta`, `TipoDetalleCompra` | `EXECUTE` | `EXECUTE` solo sobre `TipoDetalleVenta` |

## Uso de GRANT, DENY y REVOKE

- **`GRANT`** da un permiso. Al administrador se le otorga sobre todo el esquema (`ON SCHEMA::dbo`), así no hay que repetirlo por tabla.
- **`DENY`** prohíbe un permiso y **gana siempre sobre un `GRANT`**, aunque venga de otro rol. Se usa para las reglas que no tienen excepción: nadie lee contraseñas y nadie borra ventas ni compras, ni siquiera el administrador.
- **`REVOKE`** quita un permiso otorgado o denegado antes. El script lo usa al principio para limpiar permisos de ejecuciones anteriores antes de aplicar los `DENY`.

## Restricciones principales

- **Contraseñas:** `DENY SELECT ON dbo.Usuario (Contrasena)` para ambos roles. Un `SELECT * FROM Usuario` falla con el error 230, así que hay que listar las columnas permitidas. Además, el seed guarda las contraseñas como hash `SHA2_256`, no en texto plano.
- **Stock:** el vendedor no puede hacer `UPDATE` sobre `VarianteProducto`. El stock solo cambia por los SPs y los triggers.
- **Ventas:** el vendedor no puede insertar en `Venta` ni en `DetalleVenta`; solo registra ventas con `SP_RegistrarVenta`. Además, `TR_DetalleVenta_Insert` rechaza cualquier línea que no venga del SP (error 51013), aunque quien la inserte tenga permisos.
- **Borrado:** `DENY DELETE` sobre `Venta`, `DetalleVenta`, `Compra` y `DetalleCompra` para ambos roles. A esto se suman los triggers `INSTEAD OF DELETE`: las ventas y compras se anulan, no se borran.
- **Compras:** el vendedor no ve compras, proveedores ni movimientos de stock.
- **Información sensible:** el resumen de ventas por usuario (`fn_ResumenVentasPorUsuario`) sirve para evaluar el desempeño o calcular comisiones, por eso solo lo ve el administrador.

## Defensa en profundidad

Los permisos del motor no son la única barrera. Cada SP valida también el rol de aplicación del `@IdUsuario` que recibe (ver la [sección 13](13_stored_procedures.md)):

| Barrera | Ejemplo: un vendedor intenta anular una venta |
|---|---|
| Permiso del motor | `DENY EXECUTE ON SP_AnularVenta TO rol_vendedor` → error 229 |
| Validación en el SP | Si el `@IdUsuario` no es `Administrador` activo → error 50013 |
| Trigger | La devolución de stock solo la genera `TR_Venta_CambioEstado` a partir del cambio de estado |

Si por error se le diera `EXECUTE` a otro rol, la regla de negocio se seguiría cumpliendo.

## Ownership chaining

Las tablas, los SPs y los triggers pertenecen a `dbo`. Cuando un objeto llama a otro del mismo dueño, SQL Server no vuelve a verificar permisos. Por eso el vendedor puede ejecutar `SP_RegistrarVenta` y el trigger puede insertar en `MovimientoStock` y actualizar `VarianteProducto`, aunque el vendedor tenga esas tablas denegadas. Es lo que permite que **la única forma de operar sea a través de los SPs**.

## Verificación

```sql
USE SIAM;

-- El vendedor no puede leer contraseñas
EXECUTE AS USER = 'usr_vendedor';
SELECT * FROM dbo.Usuario;                                               -- error 230
REVERT;

-- El vendedor no puede modificar el stock directamente
EXECUTE AS USER = 'usr_vendedor';
UPDATE dbo.VarianteProducto SET StockActual = 999 WHERE IdVariante = 1;  -- error 229
REVERT;

-- El vendedor no puede anular ventas
EXECUTE AS USER = 'usr_vendedor';
EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;                    -- error 229
REVERT;

-- El administrador tampoco puede borrar ventas
EXECUTE AS USER = 'usr_admin';
DELETE FROM dbo.Venta WHERE IdVenta = 1;                                 -- error 229
REVERT;
```

## Limitaciones

- **Contraseñas de los logins:** están escritas en el script como ejemplo. En un entorno real deben cambiarse y no guardarse en el repositorio.
- **Hash sin *salt*:** las contraseñas de la tabla `Usuario` se guardan con `SHA2_256` sin *salt*, por lo que dos usuarios con la misma contraseña tienen el mismo hash.
- **Usuario de la operación:** los SPs reciben el `@IdUsuario` como parámetro y no lo relacionan con el login conectado, así que un vendedor podría informar el id de otro vendedor.
