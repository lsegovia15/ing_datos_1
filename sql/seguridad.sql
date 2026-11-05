-- 1. CREACIÓN DE LOGINS Y USUARIOS
USE master;
GO

CREATE LOGIN login_admin_siam WITH PASSWORD = 'Siam_Admin_2026!';
GO

CREATE LOGIN login_vendedor_siam WITH PASSWORD = 'Siam_Vend_2026!';
GO

USE SIAM;
GO

CREATE USER usr_admin FOR LOGIN login_admin_siam;
GO

CREATE USER usr_vendedor FOR LOGIN login_vendedor_siam;
GO

-- 2. CREACIÓN DE ROLES DE SEGURIDAD
CREATE ROLE rol_administrador;
GO

CREATE ROLE rol_vendedor;
GO

-- Asignación de usuarios a sus respectivos roles
ALTER ROLE rol_administrador ADD MEMBER usr_admin;
GO

ALTER ROLE rol_vendedor ADD MEMBER usr_vendedor;
GO

-- 3. PERMISOS DEL ADMINISTRADOR 
-- Acceso total sobre tablas de catálogo, maestros y compras
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Rol TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Usuario TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Categoria TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Segmento TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Marca TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Talle TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Color TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Producto TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Proveedor TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Cliente TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.VarianteProducto TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Compra TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.DetalleCompra TO rol_administrador;

-- Tablas históricas
GRANT SELECT ON dbo.Venta TO rol_administrador;
GRANT SELECT ON dbo.DetalleVenta TO rol_administrador;
GRANT SELECT ON dbo.MovimientoStock TO rol_administrador;

-- Vistas
GRANT SELECT ON dbo.vw_StockVariante TO rol_administrador;
GRANT SELECT ON dbo.vw_VentasDetalladas TO rol_administrador;
GRANT SELECT ON dbo.vw_ProductosPremium TO rol_administrador;

-- Procedimientos Almacenados
GRANT EXECUTE ON dbo.SP_RegistrarVenta TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AnularVenta TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AjustarStock TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RegistrarCompra TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RecibirCompra TO rol_administrador;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_administrador;

-- Funciones 
GRANT EXECUTE ON dbo.fn_EstadoStock TO rol_administrador;
GRANT SELECT ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;
GO

-- 4. PERMISOS DEL VENDEDOR (Principio de menor privilegio)
-- Consultas de solo lectura sobre catálogo y stock
GRANT SELECT ON dbo.Producto TO rol_vendedor;
GRANT SELECT ON dbo.VarianteProducto TO rol_vendedor;
GRANT SELECT ON dbo.Categoria TO rol_vendedor;
GRANT SELECT ON dbo.Marca TO rol_vendedor;
GRANT SELECT ON dbo.Talle TO rol_vendedor;
GRANT SELECT ON dbo.Color TO rol_vendedor;
GRANT SELECT ON dbo.Segmento TO rol_vendedor;
GRANT SELECT ON dbo.Cliente TO rol_vendedor;

-- Vistas permitidas para ventas y consulta de existencias
GRANT SELECT ON dbo.vw_StockVariante TO rol_vendedor;
GRANT SELECT ON dbo.vw_VentasDetalladas TO rol_vendedor;
GRANT SELECT ON dbo.vw_ProductosPremium TO rol_vendedor;

-- Operaciones permitidas al vendedor: registrar ventas y consultar reposición
GRANT EXECUTE ON dbo.SP_RegistrarVenta TO rol_vendedor;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_vendedor;
GRANT EXECUTE ON dbo.fn_EstadoStock TO rol_vendedor;
GO

PRINT 'Seguridad SIAM aplicada: logins, usuarios, roles y permisos configurados.';
GO