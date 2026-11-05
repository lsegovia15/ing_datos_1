# Seguridad de la base SIAM

`sql/seguridad.sql` implementa el control de acceso al motor. Es independiente de las tablas de aplicación `Rol` y `Usuario`: éstas identifican al empleado dentro del negocio, mientras que los logins, usuarios y roles de SQL Server controlan quién puede conectarse y qué objetos puede usar.

## 1. Logins y usuarios

| Login de servidor | Usuario de base | Rol de base | Perfil |
|---|---|---|---|
| `login_admin_siam` | `usr_admin` | `rol_administrador` | Administrador |
| `login_vendedor_siam` | `usr_vendedor` | `rol_vendedor` | Vendedor |

Las contraseñas del script son de ejemplo y deben cambiarse en un entorno real. Los logins se crean sin `CHECK_POLICY`. El script no es idempotente: `CREATE LOGIN` y `CREATE ROLE` fallan si el objeto ya existe, así que una segunda ejecución del master requiere borrar los logins o adaptar el archivo.

Para iniciar sesión con esos logins, la instancia debe tener habilitada la **autenticación mixta** (SQL Server y Windows). En una instalación configurada solo para Windows, los logins se crean igual pero no pueden conectarse.

## 2. Matriz de permisos

| Objeto / operación | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| `Rol`, `Usuario` | SELECT / INSERT / UPDATE / DELETE | Sin acceso |
| Catálogo (`Producto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento`) | SELECT / INSERT / UPDATE / DELETE | SELECT |
| `Cliente` | SELECT / INSERT / UPDATE / DELETE | SELECT |
| `VarianteProducto` | SELECT / INSERT / UPDATE / DELETE | SELECT |
| `Proveedor` | SELECT / INSERT / UPDATE / DELETE | Sin acceso |
| `Compra`, `DetalleCompra` | SELECT / INSERT / UPDATE / DELETE | Sin acceso |
| `Venta`, `DetalleVenta` | SELECT | Sin acceso directo; consulta por vistas |
| `MovimientoStock` | SELECT | Sin acceso |
| `AlertaStock`, `HistorialPrecio` | Sin acceso | Sin acceso |
| `vw_StockVariante`, `vw_VentasDetalladas`, `vw_ProductosPremium` | SELECT | SELECT |
| `vw_CategoriasMasVendidasPorSegmento` | Sin acceso | Sin acceso |
| `SP_RegistrarVenta` | EXECUTE | EXECUTE |
| `SP_AnularVenta` | EXECUTE | Sin acceso |
| `SP_AjustarStock` | EXECUTE | Sin acceso |
| `SP_RegistrarCompra` | EXECUTE | Sin acceso |
| `SP_RecibirCompra` | EXECUTE | Sin acceso |
| `SP_InformeReposicionStock` | EXECUTE | EXECUTE |
| `fn_EstadoStock` | EXECUTE | EXECUTE |
| `fn_ResumenVentasPorUsuario` | SELECT | Sin acceso |

El script solo usa `GRANT`; no hay `DENY` ni `REVOKE`. Todo lo que no se otorga queda sin acceso.

## 3. Restricciones específicas

- **Contraseñas:** el administrador puede leer `Usuario.Contrasena`; el vendedor no tiene acceso a la tabla `Usuario`. El seed guarda las contraseñas como hash `SHA2_256` sin *salt*.
- **Stock:** el administrador puede modificar `VarianteProducto.StockActual` directamente, sin registrar un movimiento. El vendedor solo puede leerla; sus cambios de stock se producen por los SPs y triggers.
- **Ventas:** el administrador no puede insertar, actualizar ni borrar `Venta` ni `DetalleVenta`; solo consultarlas. El vendedor registra ventas con `SP_RegistrarVenta`.
- **Borrado de ventas:** el administrador no tiene `DELETE` sobre `Venta`, así que un `DELETE` directo falla por permisos. Además, `TR_NoBorrarVenta` (`INSTEAD OF DELETE`) impide el borrado si la sentencia llega a ejecutarse.
- **Compras:** el administrador puede borrar `Compra` y `DetalleCompra` directamente. No hay trigger ni SP que lo impida.
- **Movimientos de stock:** el administrador solo puede leer `MovimientoStock`; los ajustes se registran con `SP_AjustarStock`.
- **Vistas:** ambos roles acceden a las tres primeras vistas. La cuarta vista no está otorgada a ninguno de los dos.
- **Anulación:** solo un `Administrador` activo puede anular; el SP valida el rol de aplicación y el rol de vendedor no tiene `EXECUTE` sobre el procedimiento.
- **Defensa en profundidad:** los SPs administrativos (`SP_AjustarStock`, `SP_RegistrarCompra`, `SP_RecibirCompra`, `SP_AnularVenta`) validan internamente el rol `Administrador` activo. `SP_RegistrarVenta` exige un usuario activo con rol `Administrador` o `Vendedor`. Aunque se concediera `EXECUTE` a otro rol de motor, la validación del SP seguiría aplicándose.

## 4. Verificación rápida

```sql
USE SIAM;

-- El vendedor no puede leer la tabla Usuario
EXECUTE AS USER = 'usr_vendedor';
SELECT * FROM dbo.Usuario;          -- error 229
REVERT;

-- El vendedor no puede modificar stock directamente
EXECUTE AS USER = 'usr_vendedor';
UPDATE dbo.VarianteProducto SET StockActual = 999 WHERE IdVariante = 1; -- error 229
REVERT;

-- El vendedor no puede anular ventas
EXECUTE AS USER = 'usr_vendedor';
EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;                   -- error 229
REVERT;

-- El vendedor sí puede registrar una venta
EXECUTE AS USER = 'usr_vendedor';
EXEC dbo.SP_RegistrarVenta
     @IdCliente = NULL, @IdUsuario = 2, @MedioPago = 'EFECTIVO',
     @IdVariante = 1, @Cantidad = 1, @PrecioUnitario = 18000, @Descuento = 0;
REVERT;

-- El administrador puede leer la contraseña
EXECUTE AS USER = 'usr_admin';
SELECT Contrasena FROM dbo.Usuario; -- funciona
REVERT;

-- El administrador puede borrar una compra
EXECUTE AS USER = 'usr_admin';
DELETE FROM dbo.Compra WHERE IdCompra = 3; -- funciona
REVERT;

-- El administrador no puede modificar ni borrar ventas directamente
EXECUTE AS USER = 'usr_admin';
UPDATE dbo.Venta SET Total = 0 WHERE IdVenta = 1; -- error 229
DELETE FROM dbo.Venta WHERE IdVenta = 1;          -- error 229
REVERT;
```

## 5. Nota sobre ownership chaining

Los SPs y triggers son propiedad de `dbo`, igual que las tablas. Por eso un vendedor puede ejecutar `SP_RegistrarVenta` y los triggers pueden insertar en `Venta` y actualizar `VarianteProducto` aunque el rol no tenga permisos directos sobre esas tablas.
