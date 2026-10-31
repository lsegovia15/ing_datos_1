USE SIAM;
GO

-- ============================================================
-- Vista 1: Control de stock detallado por variante
-- ============================================================
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


-- ============================================================
-- Vista 2: Ventas detalladas
-- ============================================================
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


-- ============================================================
-- Vista 3: Productos con precio superior al promedio (activos)
-- ============================================================
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


-- ============================================================
-- Vista 4: Categorías más vendidas por segmento
-- Justifica la entidad Segmento a nivel VarianteProducto.
-- ============================================================
CREATE OR ALTER VIEW vw_CategoriasMasVendidasPorSegmento AS
WITH VentasPorCategoria AS
(
    SELECT
        s.IdSegmento,
        s.Nombre          AS Segmento,
        c.IdCategoria,
        c.Nombre          AS Categoria,
        SUM(dv.Cantidad)  AS UnidadesVendidas,
        SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento) AS TotalVendido
    FROM DetalleVenta dv
    INNER JOIN Venta v            ON v.IdVenta = dv.IdVenta
    INNER JOIN VarianteProducto vp ON vp.IdVariante = dv.IdVariante
    INNER JOIN Producto p         ON p.IdProducto = vp.IdProducto
    INNER JOIN Categoria c        ON c.IdCategoria = p.IdCategoria
    INNER JOIN Segmento s         ON s.IdSegmento = vp.IdSegmento
    WHERE v.Estado = 'CONFIRMADA'
    GROUP BY s.IdSegmento, s.Nombre, c.IdCategoria, c.Nombre
),
Ranking AS
(
    SELECT *,
           RANK() OVER (
               PARTITION BY IdSegmento
               ORDER BY UnidadesVendidas DESC, TotalVendido DESC
           ) AS Posicion
    FROM VentasPorCategoria
)
SELECT
    IdSegmento,
    Segmento,
    IdCategoria,
    Categoria,
    UnidadesVendidas,
    TotalVendido,
    Posicion
FROM Ranking
WHERE Posicion = 1;
GO