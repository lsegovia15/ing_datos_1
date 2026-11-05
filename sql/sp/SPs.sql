USE SIAM;
GO

-- Tipo TVP para el carrito de ventas
IF TYPE_ID(N'dbo.TipoDetalleVenta') IS NULL
BEGIN
    EXEC(N'
        CREATE TYPE dbo.TipoDetalleVenta AS TABLE
        (
            IdVariante      INT NOT NULL,
            Cantidad        INT NOT NULL,
            PrecioUnitario  DECIMAL(12,2) NOT NULL,
            Descuento       DECIMAL(12,2) NOT NULL DEFAULT 0
        );
    ');
END
GO

-- Tipo TVP para el detalle de compras
IF TYPE_ID(N'dbo.TipoDetalleCompra') IS NULL
BEGIN
    EXEC(N'
        CREATE TYPE dbo.TipoDetalleCompra AS TABLE
        (
            IdVariante      INT NOT NULL,
            Cantidad        INT NOT NULL,
            CostoUnitario   DECIMAL(12,2) NOT NULL
        );
    ');
END
GO
