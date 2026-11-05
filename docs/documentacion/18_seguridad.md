# 18. Seguridad de la base de datos

Script: `sql/seguridad.sql`

La seguridad se aplica en dos niveles que se complementan:

| Nivel | Qué controla | Dónde |
|---|---|---|
| Motor (SQL Server) | Quién se conecta y qué objetos puede usar | Logins, usuarios y roles de base de datos, con `GRANT` |
| Aplicación | Qué empleado hace cada operación y con qué rol de negocio | Tablas `Rol` y `Usuario`, validadas dentro de los SPs |

Los roles del motor (`rol_administrador`, `rol_vendedor`) son distintos de la tabla `Rol` (`Administrador`, `Vendedor`): los primeros limitan el acceso a los objetos y los segundos identifican al empleado dentro del negocio.

## Logins, usuarios y roles

| Login de servidor | Usuario de base | Rol de base | Perfil |
|---|---|---|---|
| `login_admin_siam` | `usr_admin` | `rol_administrador` | Administrador del local |
| `login_vendedor_siam` | `usr_vendedor` | `rol_vendedor` | Vendedor |

- **Contraseñas de los logins:** están escritas en el script como ejemplo. En un entorno real deben cambiarse y no guardarse en el repositorio.
- **Script no idempotente:** `CREATE LOGIN` y `CREATE ROLE` fallan si el objeto ya existe. Como `init_db.sql` solo elimina la base y no los logins del servidor, una segunda ejecución de `00_master.sql` falla en la parte de seguridad salvo que se borren los logins o se adapte el archivo.
- Los permisos se otorgan a los **roles**, nunca a los usuarios. Para sumar un vendedor nuevo alcanza con crear su usuario y agregarlo a `rol_vendedor`.
- El script no usa `DENY` ni `REVOKE`. Lo que no se otorga queda sin acceso.

## Matriz de permisos

| Objeto | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| `Rol`, `Usuario` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Sin acceso |
| Catálogo (`Producto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento`) | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `SELECT` |
| `Cliente` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `SELECT` |
| `VarianteProducto` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `SELECT` |
| `Proveedor` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Sin acceso |
| `Compra`, `DetalleCompra` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Sin acceso |
| `Venta`, `DetalleVenta` | Solo `SELECT` | Sin acceso directo; consulta por `vw_VentasDetalladas` |
| `MovimientoStock` | Solo `SELECT` | Sin acceso |
| `AlertaStock`, `HistorialPrecio` | Sin acceso | Sin acceso |
| `vw_StockVariante`, `vw_VentasDetalladas`, `vw_ProductosPremium` | `SELECT` | `SELECT` |
| `vw_CategoriasMasVendidasPorSegmento` | Sin acceso | Sin acceso |
| `SP_RegistrarVenta` | `EXECUTE` | `EXECUTE` |
| `SP_AnularVenta`, `SP_AjustarStock` | `EXECUTE` | Sin acceso |
| `SP_RegistrarCompra`, `SP_RecibirCompra` | `EXECUTE` | Sin acceso |
| `SP_InformeReposicionStock` | `EXECUTE` | `EXECUTE` |
| `fn_EstadoStock` | `EXECUTE` | `EXECUTE` |
| `fn_ResumenVentasPorUsuario` | `SELECT` | Sin acceso |

## Restricciones y consecuencias de la matriz

- **Contraseñas:** el administrador tiene `SELECT` sobre todas las columnas de `Usuario`, incluida `Contrasena`. El vendedor no tiene acceso a la tabla `Usuario`. El seed guarda las contraseñas como hash `SHA2_256` sin *salt*.
- **Stock:** el administrador puede modificar `VarianteProducto.StockActual` directamente, sin registrar un movimiento. El vendedor solo puede leer la tabla; sus cambios de stock pasan por los triggers de los SPs.
- **Ventas:** el administrador no puede insertar, actualizar ni borrar directamente en `Venta` ni en `DetalleVenta`; solo las consulta. Las altas y anulaciones pasan por los SPs. El vendedor tampoco tiene acceso directo y registra ventas con `SP_RegistrarVenta`.
- **Borrado de ventas:** el administrador no tiene `DELETE` sobre `Venta`, así que un `DELETE` directo falla por permisos. Además, `TR_NoBorrarVenta` (`INSTEAD OF DELETE`) impide el borrado si la sentencia llega a ejecutarse.
- **Compras:** el administrador puede borrar `Compra` y `DetalleCompra` directamente; no hay trigger ni SP que lo impida. El vendedor no ve compras, proveedores ni movimientos de stock.
- **Movimientos:** el administrador solo puede leer `MovimientoStock`; no puede insertar movimientos directamente. Los ajustes se registran con `SP_AjustarStock`.
- **Vista de categorías:** la cuarta vista no está otorgada a ninguno de los dos roles. Solo un usuario con permisos de propietario o `sysadmin` puede consultarla.
- **Alertas e historial:** ninguno de los dos roles puede leer `AlertaStock` ni `HistorialPrecio`.
- **Información de ventas:** el resumen por usuario (`fn_ResumenVentasPorUsuario`) solo está disponible para el administrador.

## Defensa en profundidad

Los permisos del motor no son la única barrera. Cada SP valida también el rol de aplicación del `@IdUsuario` que recibe (ver la [sección 13](13_stored_procedures.md)):

| Barrera | Ejemplo: un vendedor intenta anular una venta |
|---|---|
| Permiso del motor | No tiene `EXECUTE` sobre `SP_AnularVenta` → error 229 |
| Validación en el SP | Si el `@IdUsuario` no es `Administrador` activo, imprime el mensaje y retorna sin cambiar la venta |
| Trigger | La devolución de stock la hace `TR_DevolverStockAnulacion` a partir del cambio de estado |

Si por error se le diera `EXECUTE` a otro rol, la validación del SP seguiría aplicándose.

## Ownership chaining

Las tablas, los SPs y los triggers pertenecen a `dbo`. Cuando un objeto llama a otro del mismo dueño, SQL Server no vuelve a verificar permisos. Por eso el vendedor puede ejecutar `SP_RegistrarVenta` y los triggers pueden insertar en `Venta` y actualizar `VarianteProducto`, aunque el rol no tenga permisos directos sobre esas tablas.

## Verificación

```sql
USE SIAM;

-- El vendedor no puede leer la tabla Usuario
EXECUTE AS USER = 'usr_vendedor';
SELECT * FROM dbo.Usuario;                                               -- error 229
REVERT;

-- El vendedor no puede modificar el stock directamente
EXECUTE AS USER = 'usr_vendedor';
UPDATE dbo.VarianteProducto SET StockActual = 999 WHERE IdVariante = 1;  -- error 229
REVERT;

-- El vendedor no puede anular ventas
EXECUTE AS USER = 'usr_vendedor';
EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;                    -- error 229
REVERT;

-- El vendedor sí puede registrar una venta
EXECUTE AS USER = 'usr_vendedor';
EXEC dbo.SP_RegistrarVenta
     @IdCliente = NULL, @IdUsuario = 2, @MedioPago = 'EFECTIVO',
     @IdVariante = 1, @Cantidad = 1, @PrecioUnitario = 18000, @Descuento = 0;
REVERT;

-- El administrador puede leer la contraseña
EXECUTE AS USER = 'usr_admin';
SELECT Contrasena FROM dbo.Usuario;                                      -- funciona
REVERT;

-- El administrador puede borrar una compra
EXECUTE AS USER = 'usr_admin';
DELETE FROM dbo.Compra WHERE IdCompra = 3;                               -- funciona
REVERT;

-- El administrador no puede borrar ni modificar ventas directamente
EXECUTE AS USER = 'usr_admin';
DELETE FROM dbo.Venta WHERE IdVenta = 1;                                 -- error 229
UPDATE dbo.Venta SET Total = 0 WHERE IdVenta = 1;                        -- error 229
REVERT;

-- El administrador no puede consultar la cuarta vista
EXECUTE AS USER = 'usr_admin';
SELECT * FROM dbo.vw_CategoriasMasVendidasPorSegmento;                   -- error 229
REVERT;
```

## Limitaciones

- **Contraseñas de los logins:** están escritas en el script como ejemplo. En un entorno real deben cambiarse y no guardarse en el repositorio.
- **Autenticación mixta:** para conectarse con `login_admin_siam` o `login_vendedor_siam`, la instancia debe aceptar autenticación de SQL Server además de Windows. Si está en modo solo Windows, los logins existen pero no pueden iniciar sesión.
- **Hash sin *salt*:** las contraseñas de la tabla `Usuario` se guardan con `SHA2_256` sin *salt*, por lo que dos usuarios con la misma contraseña tienen el mismo hash.
- **Usuario de la operación:** los SPs reciben el `@IdUsuario` como parámetro y no lo relacionan con el login conectado, así que un vendedor podría informar el id de otro usuario.
- **Administrador con DML amplio:** puede modificar stock, catálogo, proveedores y compras directamente, y borrar compras. La centralización de la lógica depende de que las operaciones se hagan por los SPs; el motor no lo impone para ese rol.
- **Repositorio de logins:** como el script no es idempotente, la ejecución repetida del master requiere limpiar los logins del servidor.
