USE SIAM;
GO

-- Vista 1: Control de stock detallado por variante

CREATE OR ALTER VIEW vw_StockVariante AS
SELECT 
    v.IdVariante,
    p.Nombre        AS Producto,
    m.Nombre        AS Marca,
    c.Nombre        AS Categoria,
    s.Nombre        AS Segmento,
    t.Descripcion   AS Talle,
    col.Nombre      AS Color,
    v.SKU,
    v.PrecioVenta,
    v.StockActual,
    v.StockMinimo,
    CASE 
        WHEN v.StockActual = 0              THEN 'SIN STOCK'
        WHEN v.StockActual <= v.StockMinimo THEN 'BAJO STOCK'
        ELSE 'STOCK SUFICIENTE'
    END AS EstadoStock 
FROM VarianteProducto v
INNER JOIN Producto  p   ON v.IdProducto  = p.IdProducto
INNER JOIN Marca     m   ON p.IdMarca     = m.IdMarca
INNER JOIN Categoria c   ON p.IdCategoria = c.IdCategoria
INNER JOIN Segmento  s   ON v.IdSegmento  = s.IdSegmento
INNER JOIN Talle     t   ON v.IdTalle     = t.IdTalle
INNER JOIN Color     col ON v.IdColor     = col.IdColor
WHERE p.Activo = 1;
GO



-- Vista 2: Ventas detalladas

CREATE OR ALTER VIEW vw_VentasDetalladas AS
SELECT
    v.IdVenta,
    v.Fecha,
    CASE 
        WHEN cl.IdCliente IS NULL THEN 'Consumidor Final'
        ELSE CONCAT(cl.Nombre, ' ', cl.Apellido)
    END                                              AS Cliente,
    ISNULL(u.NombreUsuario, 'Sin asignar')           AS Vendedor,
    v.MedioPago,
    v.Estado,
    v.Total
FROM Venta v
LEFT JOIN Cliente cl ON v.IdCliente = cl.IdCliente
LEFT JOIN Usuario u  ON v.IdUsuario = u.IdUsuario;
GO



-- Vista 3: Productos con precio superior al promedio (activos)

CREATE OR ALTER VIEW vw_ProductosPremium AS
SELECT 
    p.Nombre, 
    p.PrecioBase, 
    m.Nombre AS Marca
FROM Producto p
INNER JOIN Marca m ON p.IdMarca = m.IdMarca
WHERE p.Activo = 1 AND p.PrecioBase > (
    SELECT AVG(p2.PrecioBase)
    FROM Producto p2
    WHERE p2.Activo = 1
);
GO

-- Vista 4: Categorías más vendidas por segmento
-- Justifica la entidad Segmento a nivel VarianteProducto.

CREATE OR ALTER VIEW vw_CategoriasMasVendidasPorSegmento AS
SELECT
    s.IdSegmento,
    s.Nombre          AS Segmento,
    c.IdCategoria,
    c.Nombre          AS Categoria,
    SUM(dv.Cantidad)  AS UnidadesVendidas,
    SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento) AS TotalVendido,
    1                 AS Posicion
FROM DetalleVenta dv
INNER JOIN Venta v             ON v.IdVenta = dv.IdVenta
INNER JOIN VarianteProducto vp ON vp.IdVariante = dv.IdVariante
INNER JOIN Producto p          ON p.IdProducto = vp.IdProducto
INNER JOIN Categoria c         ON c.IdCategoria = p.IdCategoria
INNER JOIN Segmento s          ON s.IdSegmento = vp.IdSegmento
WHERE v.Estado = 'CONFIRMADA'
GROUP BY s.IdSegmento, s.Nombre, c.IdCategoria, c.Nombre
HAVING SUM(dv.Cantidad) = (
    -- Subconsulta correlacionada: calcula la máxima cantidad vendida para ese mismo segmento
    SELECT MAX(Totales.UnidadesPorCat)
    FROM (
        SELECT 
            vp2.IdSegmento,
            p2.IdCategoria,
            SUM(dv2.Cantidad) AS UnidadesPorCat
        FROM DetalleVenta dv2
        INNER JOIN Venta v2             ON v2.IdVenta = dv2.IdVenta
        INNER JOIN VarianteProducto vp2 ON vp2.IdVariante = dv2.IdVariante
        INNER JOIN Producto p2          ON p2.IdProducto = vp2.IdProducto
        WHERE v2.Estado = 'CONFIRMADA'
        GROUP BY vp2.IdSegmento, p2.IdCategoria
    ) AS Totales
    WHERE Totales.IdSegmento = s.IdSegmento
);
GO