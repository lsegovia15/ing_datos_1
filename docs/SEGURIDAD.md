# Seguridad de la base SIAM

`sql/seguridad.sql` implementa el control de acceso al motor. Es independiente de las tablas de aplicación `Rol` y `Usuario`: éstas identifican al empleado dentro del negocio, mientras que los logins/usuarios/roles de SQL Server controlan quién puede conectarse y qué objetos puede usar.

## 1. Logins y usuarios

| Login de servidor | Usuario de base | Rol de base | Perfil |
|---|---|---|---|
| `login_admin_siam` | `usr_admin` | `rol_administrador` | Administrador |
| `login_vendedor_siam` | `usr_vendedor` | `rol_vendedor` | Vendedor |

Las contraseñas del script son de ejemplo y deben cambiarse en un entorno real. El script es idempotente: si el login, usuario o rol ya existe, no lo vuelve a crear.

## 2. Matriz de permisos

| Objeto / operación | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Catálogo (`Producto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento`) | SELECT / INSERT / UPDATE / DELETE | SELECT |
| `Cliente` | SELECT / INSERT / UPDATE / DELETE | SELECT |
| `VarianteProducto` | SELECT / INSERT / UPDATE / DELETE | SELECT; `UPDATE`/`INSERT`/`DELETE` denegados |
| `Venta` / `DetalleVenta` | SELECT / INSERT / UPDATE; `DELETE` denegado | SELECT solo por vistas; DML directo denegado |
| `Compra` / `DetalleCompra` / `Proveedor` | SELECT / INSERT / UPDATE; `DELETE` denegado | Sin acceso |
| `MovimientoStock` | SELECT / INSERT; `UPDATE`/`DELETE` bloqueados por `TR_MovimientoStock_Inmutable` | Sin acceso |
| `Usuario` | SELECT de columnas permitidas / INSERT / UPDATE / DELETE; `Contrasena` denegada para lectura | SELECT de columnas permitidas; `Contrasena` denegada |
| `SP_RegistrarVenta` | EXECUTE | EXECUTE |
| `SP_AnularVenta` | EXECUTE | DENY EXECUTE |
| `SP_AjustarStock` | EXECUTE | DENY EXECUTE |
| `SP_RegistrarCompra` | EXECUTE | DENY EXECUTE |
| `SP_RecibirCompra` | EXECUTE | DENY EXECUTE |
| `SP_InformeReposicionStock` | EXECUTE | EXECUTE |
| `fn_EstadoStock` | EXECUTE | EXECUTE |
| `fn_ResumenVentasPorUsuario` | SELECT | DENY SELECT |
| Vistas (`vw_StockVariante`, `vw_VentasDetalladas`, `vw_ProductosPremium`, `vw_CategoriasMasVendidasPorSegmento`) | SELECT | SELECT |

## 3. Restricciones específicas

- **Contraseñas:** `DENY SELECT ON dbo.Usuario (Contrasena)` para ambos roles. Un `SELECT * FROM Usuario` falla; se deben listar columnas permitidas.
- **Stock:** el vendedor no puede hacer `UPDATE` directo sobre `VarianteProducto`; el stock solo cambia por los SPs y triggers.
- **Borrado:** `DENY DELETE` sobre `Venta`, `DetalleVenta`, `Compra` y `DetalleCompra` para ambos roles. Las ventas/compras se anulan, no se borran.
- **Compras:** el vendedor no tiene acceso a compras, proveedores ni movimientos de stock.
- **Ventas:** el vendedor solo registra ventas mediante `SP_RegistrarVenta`; no inserta cabeceras ni líneas directamente. El trigger `TR_DetalleVenta_Insert` rechaza inserciones directas con el error `51013`.
- **Anulación:** solo un `Administrador` activo puede anular; el SP valida el rol de aplicación (error `50013`) y el motor deniega `EXECUTE` al rol de vendedor.
- **Defensa en profundidad:** los SPs administrativos (`SP_AjustarStock`, `SP_RegistrarCompra`, `SP_RecibirCompra`, `SP_AnularVenta`) validan internamente el rol `Administrador` activo. `SP_RegistrarVenta` exige un usuario activo con rol `Administrador` o `Vendedor`. Aunque se concediera `EXECUTE` a otro rol de motor, la regla de negocio seguiría aplicándose.

## 4. Verificación rápida

```sql
USE SIAM;

-- El vendedor no puede leer la contraseña
EXECUTE AS USER = 'usr_vendedor';
SELECT * FROM dbo.Usuario;          -- error 230
REVERT;

-- El vendedor no puede modificar stock directamente
EXECUTE AS USER = 'usr_vendedor';
UPDATE dbo.VarianteProducto SET StockActual = 999 WHERE IdVariante = 1; -- error 229
REVERT;

-- El vendedor sí puede registrar una venta por SP
EXECUTE AS USER = 'usr_vendedor';
EXEC dbo.SP_RegistrarVenta ...;      -- funciona
REVERT;

-- El administrador no puede leer la contraseña ni borrar ventas
EXECUTE AS USER = 'usr_admin';
SELECT Contrasena FROM dbo.Usuario; -- error 230
DELETE FROM dbo.Venta;              -- error 229
REVERT;
```

## 5. Nota sobre ownership chaining

Los SPs y triggers son propiedad de `dbo`, igual que las tablas. Por eso un vendedor puede ejecutar `SP_RegistrarVenta` y el trigger puede insertar en `MovimientoStock` o actualizar `VarianteProducto` aunque el rol no tenga permisos directos sobre esas tablas. Las pruebas de `EXECUTE AS USER` confirman que la venta funciona y que los accesos directos fallan.
