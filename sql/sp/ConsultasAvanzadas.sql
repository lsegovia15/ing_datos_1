USE SIAM;
GO

-- PARTE 1: OPERACIONES DE CONJUNTOS (UNION)

-- 1.1 Reporte de compras y ventas
-- Une las compras y ventas en un mismo listado.

SELECT
    'VENTA' AS TipoOperacion,
    v.IdVenta AS NroOperacion,
    v.Fecha,
    ISNULL(c.Nombre + ' ' + c.Apellido, 'Consumidor Final') AS Tercero,
    u.NombreUsuario AS Responsable,
    v.Total
FROM Venta v
LEFT JOIN Cliente c ON v.IdCliente = c.IdCliente
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
WHERE v.Estado = 'CONFIRMADA'

UNION

SELECT
    'COMPRA' AS TipoOperacion,
    co.IdCompra AS NroOperacion,
    co.Fecha,
    p.RazonSocial AS Tercero,
    u.NombreUsuario AS Responsable,
    co.Total
FROM Compra co
INNER JOIN Proveedor p ON co.IdProveedor = p.IdProveedor
INNER JOIN Usuario u ON co.IdUsuario = u.IdUsuario
WHERE co.Estado = 'RECIBIDA'
ORDER BY Fecha DESC;
GO

-- PARTE 2: AGRUPACIÓN Y AGREGACIÓN (GROUP BY + HAVING)

-- 2.1 Ranking de vendedores
-- Muestra las ventas y el promedio facturado por cada vendedor.

SELECT 
    u.NombreUsuario,
    u.Nombre + ' ' + u.Apellido AS NombreCompleto,
    COUNT(v.IdVenta) AS CantidadVentas,
    SUM(v.Total) AS TotalFacturado,
    AVG(v.Total) AS TicketPromedio
FROM Venta v
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
WHERE v.Estado = 'CONFIRMADA'
GROUP BY u.NombreUsuario, u.Nombre, u.Apellido
HAVING SUM(v.Total) > 0 -- Muestra vendedores que hayan realizado ventas.
ORDER BY TotalFacturado DESC;
GO


-- 2.2 Ventas por mes y medio de pago
-- Agrupa las ventas para conocer la recaudación de cada mes.

SELECT 
    YEAR(v.Fecha) AS Anio,
    MONTH(v.Fecha) AS Mes,
    v.MedioPago,
    COUNT(v.IdVenta) AS CantidadOperaciones,
    SUM(v.Total) AS TotalRecaudado
FROM Venta v
WHERE v.Estado = 'CONFIRMADA'
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha), v.MedioPago
ORDER BY Anio DESC, Mes DESC, TotalRecaudado DESC;
GO


-- PARTE 3: SUBCONSULTAS LÓGICAS (EXISTS, IN, ALL)

-- 3.1 Subconsulta con IN
-- Busca los productos que pertenecen a la categoría Buzos.

SELECT p.IdProducto, p.Nombre, p.PrecioBase
FROM Producto p
WHERE p.IdCategoria IN (
    SELECT IdCategoria 
    FROM Categoria 
    WHERE Nombre LIKE '%Buzo%' -- Busca categorías que contengan Buzo.
);

-- 3.2 Subconsulta con NOT EXISTS
-- Muestra los productos que nunca fueron vendidos.

SELECT p.IdProducto, p.Nombre 
FROM Producto p
WHERE NOT EXISTS (
    SELECT 1 
    FROM VarianteProducto vp
    INNER JOIN DetalleVenta dv ON vp.IdVariante = dv.IdVariante
    WHERE vp.IdProducto = p.IdProducto -- Relaciona las variantes con el producto.
);
-- 3.3 Subconsulta con ALL
-- Busca variantes más caras que todos los productos de la marca Nangallery.

SELECT vp.SKU, vp.PrecioVenta 
FROM VarianteProducto vp
WHERE vp.PrecioVenta > ALL (
    SELECT p.PrecioBase 
    FROM Producto p
    INNER JOIN Marca m ON p.IdMarca = m.IdMarca
    WHERE m.Nombre = 'Nangallery'
);
GO

-- PARTE 4: SUBCONSULTAS CORRELACIONADAS

-- 4.1 Variantes con precio superior al promedio de su categoría
-- Compara el precio de cada variante con el promedio de su categoría.

SELECT 
    p.Nombre AS Producto,
    vp.SKU,
    vp.PrecioVenta,
    c.Nombre AS Categoria
FROM VarianteProducto vp
INNER JOIN Producto p ON vp.IdProducto = p.IdProducto
INNER JOIN Categoria c ON p.IdCategoria = c.IdCategoria
WHERE vp.PrecioVenta > (
    SELECT AVG(vp2.PrecioVenta)
    FROM VarianteProducto vp2
    INNER JOIN Producto p2 ON vp2.IdProducto = p2.IdProducto
    WHERE p2.IdCategoria = p.IdCategoria -- Compara con la misma categoría.
);
GO