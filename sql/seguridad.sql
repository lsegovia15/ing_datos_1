-- ============================================================
-- SIAM - Seguridad de base de datos
-- Ejecutar como sysadmin, después de crear los objetos y el seed.
--
-- Importante: los roles/usuarios de SQL Server de este script son
-- distintos de las tablas de aplicación Rol/Usuario. Aquí se controla
-- el acceso al motor; Rol/Usuario identifican al empleado en el negocio.
-- ============================================================

USE master;
GO

-- Logins de servidor. Cambiar las contraseñas en un entorno real.
IF SUSER_ID(N'login_admin_siam') IS NULL
BEGIN
    CREATE LOGIN login_admin_siam
        WITH PASSWORD = 'Siam_Admin_2026!',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;
END;
GO

IF SUSER_ID(N'login_vendedor_siam') IS NULL
BEGIN
    CREATE LOGIN login_vendedor_siam
        WITH PASSWORD = 'Siam_Vend_2026!',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;
END;
GO

USE SIAM;
GO

-- ============================================================
-- 1. ROLES DE BASE DE DATOS
-- ============================================================
IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL
    CREATE ROLE rol_administrador AUTHORIZATION dbo;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_vendedor') IS NULL
    CREATE ROLE rol_vendedor AUTHORIZATION dbo;
GO

-- ============================================================
-- 2. USUARIOS DE BASE DE DATOS
-- ============================================================
IF DATABASE_PRINCIPAL_ID(N'usr_admin') IS NULL
    CREATE USER usr_admin FOR LOGIN login_admin_siam;
GO

IF DATABASE_PRINCIPAL_ID(N'usr_vendedor') IS NULL
    CREATE USER usr_vendedor FOR LOGIN login_vendedor_siam;
GO

-- Asignación idempotente de usuarios a roles
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    INNER JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    INNER JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
    WHERE r.name = N'rol_administrador' AND u.name = N'usr_admin'
)
    ALTER ROLE rol_administrador ADD MEMBER usr_admin;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    INNER JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
    INNER JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
    WHERE r.name = N'rol_vendedor' AND u.name = N'usr_vendedor'
)
    ALTER ROLE rol_vendedor ADD MEMBER usr_vendedor;
GO

-- ============================================================
-- 3. REVOKE EXPLÍCITOS
-- Se usan para quitar permisos previos antes de aplicar DENY.
-- ============================================================
REVOKE SELECT ON dbo.Usuario FROM rol_vendedor;
REVOKE UPDATE ON dbo.VarianteProducto FROM rol_vendedor;
REVOKE DELETE ON dbo.Venta FROM rol_vendedor;
REVOKE SELECT ON dbo.Compra FROM rol_vendedor;
GO

-- ============================================================
-- 4. PERMISOS DEL ADMINISTRADOR
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_administrador;
GRANT EXECUTE ON SCHEMA::dbo TO rol_administrador;
GRANT EXECUTE ON TYPE::dbo.TipoDetalleVenta TO rol_administrador;
GRANT EXECUTE ON TYPE::dbo.TipoDetalleCompra TO rol_administrador;

-- Columnas visibles de Usuario, sin Contrasena.
GRANT SELECT ON dbo.Usuario
    (IdUsuario, IdRol, NombreUsuario, Email, Nombre, Apellido, Activo, FechaAlta)
    TO rol_administrador;
GRANT SELECT ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;

-- Bloqueo de lectura directa de la columna de contraseñas.
DENY SELECT ON dbo.Usuario (Contrasena) TO rol_administrador;

-- Ventas y compras no se borran: se anulan.
DENY DELETE ON dbo.Venta TO rol_administrador;
DENY DELETE ON dbo.DetalleVenta TO rol_administrador;
DENY DELETE ON dbo.Compra TO rol_administrador;
DENY DELETE ON dbo.DetalleCompra TO rol_administrador;
GO

-- ============================================================
-- 5. PERMISOS DEL VENDEDOR
-- ============================================================
-- Consulta de catálogo, stock y vistas de negocio.
GRANT SELECT ON dbo.vw_StockVariante TO rol_vendedor;
GRANT SELECT ON dbo.vw_VentasDetalladas TO rol_vendedor;
GRANT SELECT ON dbo.vw_ProductosPremium TO rol_vendedor;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_vendedor;

GRANT SELECT ON dbo.Producto TO rol_vendedor;
GRANT SELECT ON dbo.VarianteProducto TO rol_vendedor;
GRANT SELECT ON dbo.Categoria TO rol_vendedor;
GRANT SELECT ON dbo.Marca TO rol_vendedor;
GRANT SELECT ON dbo.Talle TO rol_vendedor;
GRANT SELECT ON dbo.Color TO rol_vendedor;
GRANT SELECT ON dbo.Segmento TO rol_vendedor;
GRANT SELECT ON dbo.Cliente TO rol_vendedor;

-- Puede ver los datos del usuario, pero no la contraseña.
GRANT SELECT ON dbo.Usuario
    (IdUsuario, IdRol, NombreUsuario, Email, Nombre, Apellido, Activo, FechaAlta)
    TO rol_vendedor;

-- Operaciones permitidas: registrar ventas y consultar reposición.
GRANT EXECUTE ON dbo.SP_RegistrarVenta TO rol_vendedor;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_vendedor;
GRANT EXECUTE ON dbo.fn_EstadoStock TO rol_vendedor;
GRANT EXECUTE ON TYPE::dbo.TipoDetalleVenta TO rol_vendedor;

-- Bloqueo de la columna de contraseñas.
DENY SELECT ON dbo.Usuario (Contrasena) TO rol_vendedor;

-- El stock solo se modifica mediante SPs/triggers, no con UPDATE directo.
DENY UPDATE ON dbo.VarianteProducto TO rol_vendedor;
DENY INSERT, DELETE ON dbo.VarianteProducto TO rol_vendedor;

-- El vendedor no administra catálogo ni clientes.
DENY INSERT, UPDATE, DELETE ON dbo.Producto TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Categoria TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Marca TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Talle TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Color TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Segmento TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Cliente TO rol_vendedor;

-- El vendedor registra ventas solo por SP_RegistrarVenta; no inserta
-- cabeceras ni líneas directamente.
DENY INSERT, UPDATE, DELETE ON dbo.Venta TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleVenta TO rol_vendedor;

-- Sin acceso a compras, proveedores ni movimientos de stock.
DENY SELECT ON dbo.Compra TO rol_vendedor;
DENY SELECT ON dbo.DetalleCompra TO rol_vendedor;
DENY SELECT ON dbo.Proveedor TO rol_vendedor;
DENY SELECT ON dbo.MovimientoStock TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Compra TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleCompra TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.Proveedor TO rol_vendedor;
DENY INSERT, UPDATE, DELETE ON dbo.MovimientoStock TO rol_vendedor;

-- Funciones y SPs restringidos.
DENY SELECT ON dbo.fn_ResumenVentasPorUsuario TO rol_vendedor;
DENY EXECUTE ON dbo.SP_AnularVenta TO rol_vendedor;
DENY EXECUTE ON dbo.SP_AjustarStock TO rol_vendedor;
DENY EXECUTE ON dbo.SP_RegistrarCompra TO rol_vendedor;
DENY EXECUTE ON dbo.SP_RecibirCompra TO rol_vendedor;
GO

PRINT 'Seguridad SIAM aplicada: logins, usuarios, roles y permisos.';
GO
