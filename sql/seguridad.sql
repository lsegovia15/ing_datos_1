USE SIAM;

GO

-- 1. ROLES FUNCIONALES: tabla dbo.Rol de la aplicacion.

IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Nombre = 'Administrador')

BEGIN

    INSERT INTO dbo.Rol (IdRol, Nombre, Descripcion)

    SELECT ISNULL(MAX(IdRol), 0) + 1,

           'Administrador', 'Administracion general del local'

    FROM dbo.Rol;

END;



IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Nombre = 'Vendedor')

BEGIN

    INSERT INTO dbo.Rol (IdRol, Nombre, Descripcion)

    SELECT ISNULL(MAX(IdRol), 0) + 1,

           'Vendedor', 'Consulta de productos y registro de ventas'

    FROM dbo.Rol;

END;

GO

-- 2. ROLES DE SEGURIDAD DE SQL SERVER.

IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL

    CREATE ROLE rol_administrador AUTHORIZATION dbo;



IF DATABASE_PRINCIPAL_ID(N'rol_vendedor') IS NULL

    CREATE ROLE rol_vendedor AUTHORIZATION dbo;

GO

-- 3. permisos del administrador
-- gestiona catalogos, usuarios, proveedores y compras.

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Rol       TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Usuario   TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Categoria TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Segmento  TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Marca     TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Talle     TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Color     TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Producto  TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Proveedor TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Cliente   TO rol_administrador;

GRANT SELECT, INSERT, DELETE ON OBJECT::dbo.VarianteProducto TO rol_administrador;

GRANT UPDATE (IdProducto, IdSegmento, IdTalle, IdColor, SKU, PrecioVenta, StockMinimo)

    ON OBJECT::dbo.VarianteProducto TO rol_administrador;


GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Compra        TO rol_administrador;

GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.DetalleCompra TO rol_administrador;


-- registro: se lee; las modificaciones se centralizan en procedimientos.

GRANT SELECT ON OBJECT::dbo.Venta           TO rol_administrador;

GRANT SELECT ON OBJECT::dbo.DetalleVenta    TO rol_administrador;

GRANT SELECT ON OBJECT::dbo.MovimientoStock TO rol_administrador;

-- vistas de consulta.

GRANT SELECT ON OBJECT::dbo.vw_StockVariante       TO rol_administrador;

GRANT SELECT ON OBJECT::dbo.vw_VentasDetalladas   TO rol_administrador;

GRANT SELECT ON OBJECT::dbo.vw_ProductosPremium   TO rol_administrador;

-- procedimientos administrativos y registro de ventas.

GRANT EXECUTE ON OBJECT::dbo.SP_RegistrarVenta       TO rol_administrador;

GRANT EXECUTE ON OBJECT::dbo.SP_AnularVenta          TO rol_administrador;

GRANT EXECUTE ON OBJECT::dbo.SP_AjustarStock         TO rol_administrador;

GRANT EXECUTE ON OBJECT::dbo.SP_InformeReposicionStock TO rol_administrador;


-- funciones: EXECUTE para escalar, SELECT para tabular.

GRANT EXECUTE ON OBJECT::dbo.fn_EstadoStock TO rol_administrador;

GRANT SELECT ON OBJECT::dbo.fn_ResumenVentasPorUsuario TO rol_administrador;


-- SP_RegistrarVenta recibe un parametro tipo tabla (TVP).

GRANT EXECUTE, REFERENCES ON TYPE::dbo.TipoDetalleVenta TO rol_administrador;

GO

-- 4. PERMISOS DEL VENDEDOR (PRINCIPIO DE MINIMO PRIVILEGIO).
-- No recibe permisos de mantenimiento de catalogos ni operaciones criticas.

-- solo lectura de productos/stock/ventas y registro de clientes.

-- registrar ventas exclusivamente desde SP_RegistrarVenta.

GRANT SELECT ON OBJECT::dbo.vw_StockVariante     TO rol_vendedor;

GRANT SELECT ON OBJECT::dbo.vw_ProductosPremium TO rol_vendedor;

GRANT SELECT ON OBJECT::dbo.vw_VentasDetalladas TO rol_vendedor;

GRANT SELECT, INSERT ON OBJECT::dbo.Cliente       TO rol_vendedor;



GRANT EXECUTE ON OBJECT::dbo.SP_RegistrarVenta TO rol_vendedor;

GRANT EXECUTE ON OBJECT::dbo.fn_EstadoStock TO rol_vendedor;

GRANT EXECUTE, REFERENCES ON TYPE::dbo.TipoDetalleVenta TO rol_vendedor;

GO