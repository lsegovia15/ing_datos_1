USE SIAM;
GO

/*
    Funcion: fn_EstadoStock
    Objetivo: informar el estado del stock de una variante de producto.
    Ejemplo de uso: SELECT dbo.fn_EstadoStock(1) AS EstadoStock;
*/

CREATE OR ALTER FUNCTION dbo.fn_EstadoStock
(
    @IdVariante INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    -- Variable que guarda el estado calculado para la variante consultada.
    DECLARE @Estado VARCHAR(20);

    -- Relaciona la variante con su producto y determina el estado.
    -- Se evalua primero si el producto esta inactivo; luego, el nivel de stock.
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

    -- Devuelve el estado obtenido (NULL si no se encuentra la variante).
    RETURN @Estado;
END;
GO

/*
    Funcion: fn_ResumenVentasPorUsuario
    Objetivo: obtener la cantidad de ventas y el total vendido por usuario
              dentro de un periodo.
    Ejemplo de uso:
    SELECT * FROM dbo.fn_ResumenVentasPorUsuario('2026-01-01', '2026-12-31');
*/

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
        -- Suma los importes y muestra el total con dos decimales.
        CAST(SUM(v.Total) AS DECIMAL(18, 2)) AS TotalVendido
    FROM dbo.Venta AS v
    INNER JOIN dbo.Usuario AS u ON u.IdUsuario = v.IdUsuario
    -- Solo incluye ventas confirmadas dentro del rango de fechas.
    -- El limite superior excluye el inicio del dia siguiente para incluir
    -- todas las horas de @FechaHasta, si Fecha contiene hora.
    WHERE v.Estado = 'CONFIRMADA'
      AND v.Fecha >= @FechaDesde
      AND v.Fecha < DATEADD(DAY, 1, @FechaHasta)
    -- Calcula una fila de resumen por cada usuario con ventas en el periodo.
    GROUP BY u.IdUsuario, u.NombreUsuario
);
GO

-- Ejemplos de utilizacion:
-- SELECT dbo.fn_EstadoStock(1) AS EstadoStock;
-- SELECT * FROM dbo.fn_ResumenVentasPorUsuario('2026-01-01', '2026-12-31');