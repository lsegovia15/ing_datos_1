USE SIAM;
GO

-- 1. ROLES DE SEGURIDAD DE SQL SERVER
-- Se crean solamente si no existen. No modifican la tabla dbo.Rol.

IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL
    CREATE ROLE rol_administrador AUTHORIZATION dbo;

IF DATABASE_PRINCIPAL_ID(N'rol_vendedor') IS NULL
    CREATE ROLE rol_vendedor AUTHORIZATION dbo;
GO

-- 2. PERMISOS DEL ADMINISTRADOR
-- Administra catalogos, proveedores, clientes, compras y usuarios.
-- No modifica directamente el stock ni el historial de ventas.


-- Catalogos generales.
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Rol       TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Categoria TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Segmento  TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Marca     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Talle     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Color     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Producto  TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Proveedor TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Cliente   TO rol_administrador;

-- Usuarios: no exponer por SELECT el campo Contrasena (hash).
-- Para desactivar un empleado, actualizar Activo en lugar de borrarlo.
-- REVOKE elimina permisos generales de versiones anteriores del script.

REVOKE SELECT, UPDATE, DELETE ON OBJECT::dbo.Usuario FROM rol_administrador;
GRANT SELECT (IdUsuario, IdRol, NombreUsuario, Email, Nombre, Apellido, Activo, FechaAlta)
    ON OBJECT::dbo.Usuario TO rol_administrador;
GRANT INSERT ON OBJECT::dbo.Usuario TO rol_administrador;
GRANT UPDATE (IdRol, NombreUsuario, Email, Nombre, Apellido, Activo)
    ON OBJECT::dbo.Usuario TO rol_administrador;

-- Variantes: se consulta el stock, pero no se modifica StockActual directamente.

REVOKE INSERT, DELETE ON OBJECT::dbo.VarianteProducto FROM rol_administrador;
GRANT SELECT ON OBJECT::dbo.VarianteProducto TO rol_administrador;
GRANT UPDATE (IdProducto, IdSegmento, IdTalle, IdColor, SKU, PrecioVenta, StockMinimo)
    ON OBJECT::dbo.VarianteProducto TO rol_administrador;

-- Compras
-- No se permite DELETE para preservar su historial.
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Compra        TO rol_administrador;
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.DetalleCompra TO rol_administrador;

-- Ventas y movimientos historicos: solo lectura directa.
GRANT SELECT ON OBJECT::dbo.Venta           TO rol_administrador;
GRANT SELECT ON OBJECT::dbo.DetalleVenta    TO rol_administrador;
GRANT SELECT ON OBJECT::dbo.MovimientoStock TO rol_administrador;

-- Tablas que se crean al ejecutar firme38_triggers.sql.
GRANT SELECT ON OBJECT::dbo.HistorialPrecio TO rol_administrador;
GRANT SELECT ON OBJECT::dbo.AlertaStock     TO rol_administrador;
GRANT UPDATE (Atendida) ON OBJECT::dbo.AlertaStock TO rol_administrador;

-- Vistas: permiten consultar sin modificar las tablas originales.
GRANT SELECT ON OBJECT::dbo.vw_StockVariante     TO rol_administrador;
GRANT SELECT ON OBJECT::dbo.vw_VentasDetalladas TO rol_administrador;
GRANT SELECT ON OBJECT::dbo.vw_ProductosPremium TO rol_administrador;

-- Procedimientos almacenados implementados en los archivos recibidos.
GRANT EXECUTE ON OBJECT::dbo.SP_RegistrarVenta        TO rol_administrador;
GRANT EXECUTE ON OBJECT::dbo.SP_AnularVenta           TO rol_administrador;
GRANT EXECUTE ON OBJECT::dbo.SP_AjustarStock          TO rol_administrador;
GRANT EXECUTE ON OBJECT::dbo.SP_InformeReposicionStock TO rol_administrador;

-- Funciones: EXECUTE para funcion escalar, SELECT para funcion tabular.
GRANT EXECUTE ON OBJECT::dbo.fn_EstadoStock            TO rol_administrador;
GRANT SELECT  ON OBJECT::dbo.fn_ResumenVentasPorUsuario TO rol_administrador;

-- Para pasar dbo.TipoDetalleVenta como parametro a SP_RegistrarVenta.
GRANT EXECUTE, REFERENCES ON TYPE::dbo.TipoDetalleVenta TO rol_administrador;
GO


-- 3. PERMISOS DEL VENDEDOR
-- Consulta catalogo y stock, registra clientes y vende.
-- El seed_data.sql indica que tambien puede ver reportes de reposicion.
-- No administra productos, compras, usuarios, anulaciones o ajustes.


-- Vistas de lectura.
GRANT SELECT ON OBJECT::dbo.vw_StockVariante     TO rol_vendedor;
GRANT SELECT ON OBJECT::dbo.vw_ProductosPremium TO rol_vendedor;
GRANT SELECT ON OBJECT::dbo.vw_VentasDetalladas TO rol_vendedor;

-- Clientes: consulta datos minimos para identificar al cliente, incluido DNI.
-- No ve telefono, email ni direccion. Puede dar de alta, pero no editar ni borrar.
REVOKE SELECT ON OBJECT::dbo.Cliente FROM rol_vendedor;
GRANT SELECT (IdCliente, Nombre, Apellido, DNI)
    ON OBJECT::dbo.Cliente TO rol_vendedor;
GRANT INSERT ON OBJECT::dbo.Cliente TO rol_vendedor;

-- Registrar ventas exclusivamente mediante el procedimiento.
GRANT EXECUTE ON OBJECT::dbo.SP_RegistrarVenta TO rol_vendedor;
GRANT EXECUTE, REFERENCES ON TYPE::dbo.TipoDetalleVenta TO rol_vendedor;

-- Consultar el estado de stock y el reporte de reposicion.
GRANT EXECUTE ON OBJECT::dbo.fn_EstadoStock TO rol_vendedor;
GRANT EXECUTE ON OBJECT::dbo.SP_InformeReposicionStock TO rol_vendedor;
GO


PRINT 'Permisos SQL Server configurados. Revisar notas sobre compras y usuarios.';
GO