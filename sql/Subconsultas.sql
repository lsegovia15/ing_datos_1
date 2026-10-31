USE SIAM;
GO

-- Subconsulta: Clientes que han comprado ropa de la categoria 'Buzos'
-- (Asumiendo que existe la categoría, filtramos por IdCategoria)

SELECT Nombre, Apellido, DNI
FROM Cliente
WHERE IdCliente IN(
    SELECT v.IdCliente
    FROM Venta v
    INNER JOIN DetalleVenta dv ON v.idVenta = dv.IdVenta
    INNER JOIN VarianteProducto vp ON dv.IdVariante = vp.IdVariante
    INNER JOIN Producto P on vp.IdProducto = p.IdProducto
    INNER JOIN Categoria c ON p.IdCategoria = c.IdCategoria
    WHERE c.Nombre = 'Buzos'
);

-- Subconsultas con NOT EXISTS: Productos que nunca han tenido ventas registradas
SELECT p.IdProducto, p.Nombre
FROM Producto p 
WHERE NOT EXISTS(
    SELECT 1
    FROM VarianteProducto vp
    INNER JOIN DetalleVenta dv ON vp.IdVariante = dv.IdVariante
    WHERE vp.IdProducto = p.IdProducto
);
-- 2.3 Subconsulta con ALL (o > ANY): Variantes cuyo precio es mayor a TODOS los precios de la marca 'Nangallery'
SELECT vp.SKU, vp.PrecioVenta 
FROM VarianteProducto vp
WHERE vp.PrecioVenta > ALL (
    SELECT p.PrecioBase 
    FROM Producto p
    INNER JOIN Marca m ON p.IdMarca = m.IdMarca
    WHERE m.Nombre = 'Nangallery'
);