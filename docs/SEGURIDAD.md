# Seguridad de la base SIAM

`sql/seguridad.sql` implementa el control de acceso al motor. Es independiente de las tablas de aplicación `Rol` y `Usuario`: éstas identifican al empleado dentro del negocio, mientras que los logins, usuarios y roles de SQL Server controlan quién puede conectarse y qué objetos puede usar.

## 1. Logins y usuarios

| Login de servidor | Usuario de base | Rol de base | Perfil |
|---|---|---|---|
| `login_admin_siam` | `usr_admin` | `rol_administrador` | Administrador |
| `login_vendedor_siam` | `usr_vendedor` | `rol_vendedor` | Vendedor |

Las contraseñas del script son de ejemplo y deben cambiarse en un entorno real. Los logins se crean solo si no existen; usuarios y roles se crean junto con la base.

## 2. Criterio

Solo se usa `GRANT` (menor privilegio): un rol sin `GRANT` sobre un objeto no tiene acceso. Para quitar un permiso se usa `REVOKE`.

## 3. Matriz de permisos

| Objeto / operación | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Catálogo (`Producto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento`) y `Cliente` | SELECT / INSERT / UPDATE / DELETE | SELECT |
| `Proveedor`, `Rol`, `Usuario` | SELECT / INSERT / UPDATE / DELETE | Sin acceso |
| `VarianteProducto` | SELECT / INSERT / UPDATE | SELECT |
| `Venta`, `DetalleVenta`, `Compra`, `DetalleCompra`, `MovimientoStock`, `HistorialPrecio` | SELECT | Sin acceso |
| `AlertaStock` | SELECT / UPDATE | Sin acceso |
| Vistas (las 4) | SELECT | SELECT |
| `SP_RegistrarVenta`, `SP_InformeReposicionStock`, `fn_EstadoStock` | EXECUTE | EXECUTE |
| `SP_AnularVenta`, `SP_AjustarStock`, `SP_RegistrarCompra`, `SP_RecibirCompra` | EXECUTE | Sin acceso |
| `fn_ResumenVentasPorUsuario` | SELECT | Sin acceso |

Ventas y compras se registran, reciben y anulan solo con los SPs. El detalle y las pruebas están en [documentacion/18_seguridad.md](documentacion/18_seguridad.md).
