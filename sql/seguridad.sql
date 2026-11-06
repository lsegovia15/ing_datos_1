-- seguridad: logins -> usuarios -> roles -> permisos
-- a cada rol le doy con GRANT solo lo que necesita

-- 1. logins
-- no se borran al recrear la base, asi que se crean solo si no existen
-- (las contraseñas son de ejemplo)
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_admin_siam')
    CREATE LOGIN login_admin_siam WITH PASSWORD = 'Siam_Admin_2026!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_vendedor_siam')
    CREATE LOGIN login_vendedor_siam WITH PASSWORD = 'Siam_Vend_2026!';
GO

-- 2. usuarios de la base
USE SIAM;
GO

CREATE USER usr_admin FOR LOGIN login_admin_siam;
CREATE USER usr_vendedor FOR LOGIN login_vendedor_siam;
GO

-- 3. roles
CREATE ROLE rol_administrador;
CREATE ROLE rol_vendedor;
GO

ALTER ROLE rol_administrador ADD MEMBER usr_admin;
ALTER ROLE rol_vendedor ADD MEMBER usr_vendedor;
GO

-- 4. permisos del administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Rol       TO rol_administrador;

-- usuarios: el select es por columna, sin Contrasena, para que no pueda leerla
GRANT SELECT (IdUsuario, IdRol, NombreUsuario, Email, Nombre, Apellido, Activo, FechaAlta)
    ON dbo.Usuario TO rol_administrador;
GRANT INSERT, UPDATE, DELETE ON dbo.Usuario TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Categoria TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Segmento  TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Marca     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Talle     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Color     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Producto  TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Proveedor TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Cliente   TO rol_administrador;

-- variantes: sin DELETE porque las usan las ventas y compras
-- el update es solo de precio y minimo, el stock no se toca directo
GRANT SELECT, INSERT ON dbo.VarianteProducto TO rol_administrador;
GRANT UPDATE (PrecioVenta, StockMinimo) ON dbo.VarianteProducto TO rol_administrador;

-- ventas, compras y movimientos: solo lectura, se modifican con los SP
GRANT SELECT ON dbo.Venta           TO rol_administrador;
GRANT SELECT ON dbo.DetalleVenta    TO rol_administrador;
GRANT SELECT ON dbo.Compra          TO rol_administrador;
GRANT SELECT ON dbo.DetalleCompra   TO rol_administrador;
GRANT SELECT ON dbo.MovimientoStock TO rol_administrador;
GRANT SELECT ON dbo.HistorialPrecio TO rol_administrador;

-- alertas: las puede marcar como atendidas
GRANT SELECT, UPDATE ON dbo.AlertaStock TO rol_administrador;

-- vistas
GRANT SELECT ON dbo.vw_StockVariante                    TO rol_administrador;
GRANT SELECT ON dbo.vw_VentasDetalladas                 TO rol_administrador;
GRANT SELECT ON dbo.vw_ProductosPremium                 TO rol_administrador;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_administrador;

-- stored procedures
GRANT EXECUTE ON dbo.SP_RegistrarVenta         TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AnularVenta            TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AjustarStock           TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RegistrarCompra        TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RecibirCompra          TO rol_administrador;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_administrador;

-- funciones
GRANT EXECUTE ON dbo.fn_EstadoStock             TO rol_administrador;
GRANT SELECT  ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;
GO

-- 5. permisos del vendedor
GRANT SELECT ON dbo.Producto         TO rol_vendedor;
GRANT SELECT ON dbo.VarianteProducto TO rol_vendedor;
GRANT SELECT ON dbo.Categoria        TO rol_vendedor;
GRANT SELECT ON dbo.Marca            TO rol_vendedor;
GRANT SELECT ON dbo.Talle            TO rol_vendedor;
GRANT SELECT ON dbo.Color            TO rol_vendedor;
GRANT SELECT ON dbo.Segmento         TO rol_vendedor;
GRANT SELECT ON dbo.Cliente          TO rol_vendedor;

-- vistas
GRANT SELECT ON dbo.vw_StockVariante                    TO rol_vendedor;
GRANT SELECT ON dbo.vw_VentasDetalladas                 TO rol_vendedor;
GRANT SELECT ON dbo.vw_ProductosPremium                 TO rol_vendedor;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_vendedor;

-- puede registrar ventas y ver reposicion
GRANT EXECUTE ON dbo.SP_RegistrarVenta         TO rol_vendedor;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_vendedor;
GRANT EXECUTE ON dbo.fn_EstadoStock            TO rol_vendedor;
GO

-- el vendedor no puede ver usuarios, compras ni proveedores, ni anular ventas
-- ni ajustar stock (para sacar un permiso: REVOKE)

PRINT 'Seguridad SIAM aplicada: logins, usuarios, roles y permisos configurados.';
GO
