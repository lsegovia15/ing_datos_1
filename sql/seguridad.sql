-- SEGURIDAD SIAM
-- Logins (servidor) -> usuarios (base SIAM) -> roles -> permisos.
-- Criterio de menor privilegio: cada rol recibe con GRANT solo lo que
-- necesita. Lo que no se otorga queda sin acceso.

-- 1. LOGINS (nivel servidor)
-- Los logins no se borran al recrear la base, por eso se crean solo si
-- todavía no existen. Las contraseñas son de ejemplo: cambiarlas en un
-- entorno real.
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_admin_siam')
    CREATE LOGIN login_admin_siam WITH PASSWORD = 'Siam_Admin_2026!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_vendedor_siam')
    CREATE LOGIN login_vendedor_siam WITH PASSWORD = 'Siam_Vend_2026!';
GO

-- 2. USUARIOS DE LA BASE
USE SIAM;
GO

CREATE USER usr_admin FOR LOGIN login_admin_siam;
CREATE USER usr_vendedor FOR LOGIN login_vendedor_siam;
GO

-- 3. ROLES Y MIEMBROS
CREATE ROLE rol_administrador;
CREATE ROLE rol_vendedor;
GO

ALTER ROLE rol_administrador ADD MEMBER usr_admin;
ALTER ROLE rol_vendedor ADD MEMBER usr_vendedor;
GO

-- 4. PERMISOS DEL ADMINISTRADOR
-- Catálogo, maestros y usuarios: puede consultar y mantener.
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Rol       TO rol_administrador;

-- Usuarios: puede darlos de alta, modificarlos y borrarlos, pero la
-- consulta se otorga columna por columna, sin Contrasena. Así ni el
-- administrador puede leer las contraseñas (error 230 si lo intenta).
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

-- Variantes: alta y cambio de precio/mínimo. Sin DELETE porque están
-- referenciadas por ventas y compras.
-- El UPDATE se otorga solo sobre PrecioVenta y StockMinimo: StockActual
-- no se puede modificar directo (error 230). El stock solo cambia por
-- compras recibidas, ventas, anulaciones y SP_AjustarStock.
GRANT SELECT, INSERT ON dbo.VarianteProducto TO rol_administrador;
GRANT UPDATE (PrecioVenta, StockMinimo) ON dbo.VarianteProducto TO rol_administrador;

-- Ventas, compras y movimientos: solo lectura. Se registran, reciben,
-- anulan y ajustan únicamente a través de los stored procedures.
GRANT SELECT ON dbo.Venta           TO rol_administrador;
GRANT SELECT ON dbo.DetalleVenta    TO rol_administrador;
GRANT SELECT ON dbo.Compra          TO rol_administrador;
GRANT SELECT ON dbo.DetalleCompra   TO rol_administrador;
GRANT SELECT ON dbo.MovimientoStock TO rol_administrador;
GRANT SELECT ON dbo.HistorialPrecio TO rol_administrador;

-- Alertas: puede marcarlas como atendidas.
GRANT SELECT, UPDATE ON dbo.AlertaStock TO rol_administrador;

-- Vistas
GRANT SELECT ON dbo.vw_StockVariante                    TO rol_administrador;
GRANT SELECT ON dbo.vw_VentasDetalladas                 TO rol_administrador;
GRANT SELECT ON dbo.vw_ProductosPremium                 TO rol_administrador;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_administrador;

-- Stored procedures
GRANT EXECUTE ON dbo.SP_RegistrarVenta         TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AnularVenta            TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AjustarStock           TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RegistrarCompra        TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RecibirCompra          TO rol_administrador;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_administrador;

-- Funciones: la escalar se ejecuta, la de tabla se consulta con SELECT.
GRANT EXECUTE ON dbo.fn_EstadoStock             TO rol_administrador;
GRANT SELECT  ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;
GO

-- 5. PERMISOS DEL VENDEDOR
-- Solo lectura del catálogo y de clientes.
GRANT SELECT ON dbo.Producto         TO rol_vendedor;
GRANT SELECT ON dbo.VarianteProducto TO rol_vendedor;
GRANT SELECT ON dbo.Categoria        TO rol_vendedor;
GRANT SELECT ON dbo.Marca            TO rol_vendedor;
GRANT SELECT ON dbo.Talle            TO rol_vendedor;
GRANT SELECT ON dbo.Color            TO rol_vendedor;
GRANT SELECT ON dbo.Segmento         TO rol_vendedor;
GRANT SELECT ON dbo.Cliente          TO rol_vendedor;

-- Vistas de consulta
GRANT SELECT ON dbo.vw_StockVariante                    TO rol_vendedor;
GRANT SELECT ON dbo.vw_VentasDetalladas                 TO rol_vendedor;
GRANT SELECT ON dbo.vw_ProductosPremium                 TO rol_vendedor;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_vendedor;

-- Operaciones: registrar ventas y consultar reposición.
GRANT EXECUTE ON dbo.SP_RegistrarVenta         TO rol_vendedor;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_vendedor;
GRANT EXECUTE ON dbo.fn_EstadoStock            TO rol_vendedor;
GO

-- Sin GRANT, el vendedor no puede: ver usuarios ni contraseñas, ver
-- compras, proveedores ni movimientos, modificar tablas, anular ventas,
-- ajustar stock ni registrar o recibir compras.
--
-- Para quitar un permiso otorgado se usa REVOKE. Ejemplo:
--   REVOKE SELECT ON dbo.Cliente FROM rol_vendedor;

PRINT 'Seguridad SIAM aplicada: logins, usuarios, roles y permisos configurados.';
GO
