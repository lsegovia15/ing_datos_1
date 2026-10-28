USE SIAM;
GO

-- ============================================================
-- Vista 1: Control de stock detallado por variante
-- ============================================================
CREATE VIEW vw_StockVariante AS
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


-- ============================================================
-- Vista 2: Ventas detalladas
-- ============================================================
CREATE VIEW vw_VentasDetalladas AS
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


-- ============================================================
-- Vista 3: Productos con precio superior al promedio (activos)
-- ============================================================
CREATE VIEW vw_ProductosPremium AS
SELECT 
    p.Nombre, 
    p.PrecioBase, 
    m.Nombre AS Marca
FROM Producto p
INNER JOIN Marca m ON p.IdMarca = m.IdMarca
WHERE p.PrecioBase > (
    SELECT AVG(p2.PrecioBase)
    FROM Producto p2
    WHERE p2.Activo = 1
);
GO