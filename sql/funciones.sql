USE SIAM;
GO

-- devuelve el estado del stock de una variante
-- SELECT dbo.fn_EstadoStock(1);

CREATE OR ALTER FUNCTION dbo.fn_EstadoStock
(
    @IdVariante INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Estado VARCHAR(20);

    -- primero miro si el producto esta inactivo y despues el stock
    SELECT @Estado =
        CASE
            WHEN p.Activo = 0                     THEN 'INACTIVO'
            WHEN v.StockActual = 0                THEN 'SIN STOCK'
            WHEN v.StockActual <= v.StockMinimo   THEN 'BAJO STOCK'
            ELSE 'STOCK SUFICIENTE'
        END
    FROM dbo.VarianteProducto AS v
    INNER JOIN dbo.Producto AS p ON p.IdProducto = v.IdProducto
    WHERE v.IdVariante = @IdVariante;

    -- si la variante no existe devuelve NULL
    RETURN @Estado;
END;
GO


-- cantidad de ventas y total vendido por usuario en un periodo
-- SELECT * FROM dbo.fn_ResumenVentasPorUsuario('2026-01-01', '2026-12-31');
CREATE OR ALTER FUNCTION dbo.fn_ResumenVentasPorUsuario
(
    @FechaDesde DATE,
    @FechaHasta DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        u.IdUsuario,
        u.NombreUsuario,
        COUNT(*) AS CantidadVentas,
        CAST(SUM(v.Total) AS DECIMAL(18, 2)) AS TotalVendido
    FROM dbo.Venta AS v
    INNER JOIN dbo.Usuario AS u ON u.IdUsuario = v.IdUsuario
    -- solo confirmadas; el < dia siguiente es para que entre todo el ultimo dia
    WHERE v.Estado = 'CONFIRMADA'
      AND v.Fecha >= @FechaDesde
      AND v.Fecha < DATEADD(DAY, 1, @FechaHasta)
    GROUP BY u.IdUsuario, u.NombreUsuario
);
GO
