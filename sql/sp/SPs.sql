USE SIAM;
GO

-- 1. Tabla temporal para el carrito de ventas
CREATE TABLE #DetalleVenta
(
    IdVariante      INT NOT NULL,
    Cantidad        INT NOT NULL,
    PrecioUnitario  DECIMAL(12,2) NOT NULL,
    Descuento       DECIMAL(12,2) NOT NULL DEFAULT 0
);

-- 2. Tabla temporal para el detalle de compras
CREATE TABLE #DetalleCompra
(
    IdVariante      INT NOT NULL,
    Cantidad        INT NOT NULL,
    CostoUnitario   DECIMAL(12,2) NOT NULL
);
GO