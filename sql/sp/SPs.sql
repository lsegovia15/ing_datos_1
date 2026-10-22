USE SIAM;
GO

-- Creamos un tipo de dato que represente una línea de detalle
CREATE TYPE TipoDetalleVenta AS TABLE (
    IdVariante      INT NOT NULL,
    Cantidad        INT NOT NULL,
    PrecioUnitario  DECIMAL(12,2) NOT NULL,
    Descuento       DECIMAL(12,2) NOT NULL DEFAULT 0
);
GO