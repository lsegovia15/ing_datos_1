USE SIAM;
GO

-- vista para control de stock detallado (producto + talle + color + segmento)

CREATE VIEW vw_StockVariate AS
SELECT 
    v.IdVariante,
    P.Nombre AS Producto,
    m.Nombre AS Marca,
    c.Nombre AS Categoria,
    s.Nombre AS Segmento,
    t.Descripcion AS Talle,
    col.Nombre AS color,
    v.SKU,
    v.PrecioVenta,
    v.StockActual,
    v.StockMinimo,
    CASE 
        WHEN v.StockActual = 0 THEN 'SIN STOCK'
        WHEN v.StockActual <= v.StockMinimo THEN 'BAJO STOCK'
        ELSE 'STOCK SUFICIENTE'
    END AS EstadoStock 
FROM VarianteProducto v
INNER JOIN Producto p on v.IdCategoria = p.IdProducto
INNER JOIN Marca m ON p.IdMarca = m.IdMarca
INNER JOIN Categoria c ON p.IdCategoria = c.IdCategoria
INNER JOIN Segmento s ON v.IdSegmento = s.IdSegmento
INNER JOIN Talle t ON v.IdTalle = t.IdTalle
INNER JOIN Color col ON v.IdColor = col.IdColor
WHERE p.Activo = 1;
GO

-- Vista de ventas detalladas (Para que el admin o vendedor cosulte rapido)
CREATE VIEW vw_VentasDetalladas AS
SELECT
    v.IdVenta,
    v.Fecha,
    ISNULL(cl.Nombre + ' ' + cl.Apellido, 'Consumidor Final' ) AS Cliente,
    u.NombreUsuario AS vendedor,
    v.MedioPago,
    v.Estado,
    v.Total
FROM Venta v
LEFT JOIN Cliente cl ON v.IdCliente = cl.IdCliente
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
GO

-- Vista de productos con precio superior al promedio 

CREATE VIEW vw_ProductosPremium AS
SELECT p.Nombre, p.PrecioBase, m.Nombre AS Marca
FROM Producto p 
INNER JOIN Marca m ON p.IdMarca = m.IdMarca
WHERE p.Precio > (SELECT AVG(PrecioBase) FROM Producto);
GO