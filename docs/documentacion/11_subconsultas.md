# 11. Subconsultas

Scripts: `sql/Subconsultas.sql` y `sql/sp/ConsultasAvanzadas.sql` (partes 3 y 4)

| # | Consulta | Tipo de subconsulta |
|---|---|---|
| 1 | Clientes que compraron buzos | `IN` |
| 2 | Productos de la categoría Buzos | `IN` |
| 3 | Productos que nunca se vendieron | `NOT EXISTS` (correlacionada) |
| 4 | Variantes más caras que toda una marca | `ALL` |
| 5 | Variantes más caras que el promedio de su categoría | Escalar correlacionada |
| 6 | Productos premium (vista) | Escalar no correlacionada |

---

## 1. Clientes que compraron buzos

```sql
SELECT Nombre, Apellido, DNI
FROM Cliente
WHERE IdCliente IN (
    SELECT v.IdCliente
    FROM Venta v
    INNER JOIN DetalleVenta dv      ON v.IdVenta = dv.IdVenta
    INNER JOIN VarianteProducto vp  ON dv.IdVariante = vp.IdVariante
    INNER JOIN Producto p           ON vp.IdProducto = p.IdProducto
    INNER JOIN Categoria c          ON p.IdCategoria = c.IdCategoria
    WHERE c.Nombre = 'Buzos'
);
```

- **Información que se desea obtener:** los datos de contacto de los clientes que alguna vez compraron un buzo, por ejemplo para avisarles de una nueva colección de invierno.
- **Función de la subconsulta:** recorre ventas → líneas → variantes → productos → categoría y devuelve la lista de `IdCliente` que compraron buzos.
- **Por qué es adecuada:** la consulta exterior solo necesita los datos del cliente. Si se hiciera un `JOIN` directo, un cliente que compró tres buzos aparecería tres veces y habría que agregar `DISTINCT`. Con `IN`, cada cliente aparece una sola vez, porque solo se pregunta si pertenece o no al conjunto. Las ventas a consumidor final devuelven `IdCliente = NULL`, que nunca coincide en un `IN`, así que quedan afuera sin un filtro extra.

---

## 2. Productos de la categoría Buzos

```sql
SELECT p.IdProducto, p.Nombre, p.PrecioBase
FROM Producto p
WHERE p.IdCategoria IN (
    SELECT IdCategoria
    FROM Categoria
    WHERE Nombre LIKE '%Buzo%'
);
```

- **Información que se desea obtener:** el catálogo de buzos.
- **Función de la subconsulta:** traduce el nombre de la categoría (lo que conoce el usuario) a su `IdCategoria` (lo que guarda `Producto`).
- **Por qué es adecuada:** permite filtrar por nombre sin conocer el ID. Con `LIKE '%Buzo%'` incluye variantes como "Buzos" o "Buzos con capucha". Como puede haber varias categorías que coincidan, se usa `IN` y no `=`, que fallaría si la subconsulta devolviera más de una fila.

---

## 3. Productos que nunca se vendieron

```sql
SELECT p.IdProducto, p.Nombre
FROM Producto p
WHERE NOT EXISTS (
    SELECT 1
    FROM VarianteProducto vp
    INNER JOIN DetalleVenta dv ON vp.IdVariante = dv.IdVariante
    WHERE vp.IdProducto = p.IdProducto
);
```

- **Información que se desea obtener:** los productos sin ninguna venta, candidatos a liquidar o a dar de baja.
- **Función de la subconsulta:** es **correlacionada**: para cada producto de la consulta exterior (`p.IdProducto`), busca si existe al menos una línea de venta de alguna de sus variantes.
- **Por qué es adecuada:** `NOT EXISTS` se detiene apenas encuentra una fila, sin contar ni traer datos (por eso `SELECT 1`). Además, a diferencia de `NOT IN`, no se ve afectado por valores `NULL` en la subconsulta, que harían que `NOT IN` devuelva un resultado vacío.

> Esta consulta aparece en los dos scripts (`Subconsultas.sql` y `ConsultasAvanzadas.sql` 3.2) con el mismo código.

---

## 4. Variantes más caras que todos los productos de una marca

```sql
SELECT vp.SKU, vp.PrecioVenta
FROM VarianteProducto vp
WHERE vp.PrecioVenta > ALL (
    SELECT p.PrecioBase
    FROM Producto p
    INNER JOIN Marca m ON p.IdMarca = m.IdMarca
    WHERE m.Nombre = 'Nangallery'
);
```

- **Información que se desea obtener:** las variantes cuyo precio supera al producto más caro de una marca de referencia, para posicionar precios frente a esa marca.
- **Función de la subconsulta:** devuelve la lista de precios base de la marca.
- **Por qué es adecuada:** `> ALL` compara contra **cada** valor de la lista, lo que equivale a "mayor que el máximo", sin calcularlo aparte.

> **Consideración importante:** si la marca no existe o no tiene productos, la subconsulta devuelve un conjunto vacío, y en SQL `> ALL (conjunto vacío)` es **verdadero**. En ese caso la consulta devuelve **todas** las variantes. Para evitarlo se puede usar `> (SELECT MAX(...))`, que con un conjunto vacío devuelve `NULL` y no trae filas.
>
> Hay que tener en cuenta además que la consulta compara el `PrecioVenta` de las variantes con el `PrecioBase` de los productos, que son precios de niveles distintos.

---

## 5. Variantes más caras que el promedio de su categoría

```sql
SELECT p.Nombre AS Producto, vp.SKU, vp.PrecioVenta, c.Nombre AS Categoria
FROM VarianteProducto vp
INNER JOIN Producto p  ON vp.IdProducto = p.IdProducto
INNER JOIN Categoria c ON p.IdCategoria = c.IdCategoria
WHERE vp.PrecioVenta > (
    SELECT AVG(vp2.PrecioVenta)
    FROM VarianteProducto vp2
    INNER JOIN Producto p2 ON vp2.IdProducto = p2.IdProducto
    WHERE p2.IdCategoria = p.IdCategoria
);
```

- **Información que se desea obtener:** las variantes caras **dentro de su propia categoría**. Una remera cara no se compara con una campera barata, sino con las otras remeras.
- **Función de la subconsulta:** es **escalar correlacionada**: para cada variante calcula el precio promedio de su categoría (`p2.IdCategoria = p.IdCategoria`) y devuelve un único valor.
- **Por qué es adecuada:** con un promedio general se mezclarían categorías con rangos de precio muy distintos. La correlación permite que cada fila se compare con su propio grupo en una sola consulta.

---

## 6. Productos premium (vista vw_ProductosPremium)

```sql
SELECT p.Nombre, p.PrecioBase, m.Nombre AS Marca
FROM Producto p
INNER JOIN Marca m ON p.IdMarca = m.IdMarca
WHERE p.Activo = 1 AND p.PrecioBase > (
    SELECT AVG(p2.PrecioBase)
    FROM Producto p2
    WHERE p2.Activo = 1
);
```

- **Información que se desea obtener:** los productos activos con precio superior al promedio del catálogo.
- **Función de la subconsulta:** es **escalar no correlacionada**: calcula el promedio una sola vez, sin depender de la fila exterior.
- **Por qué es adecuada:** el umbral se recalcula en cada consulta, así que si cambian los precios la lista se actualiza sola. La subconsulta también filtra `Activo = 1` para que los productos dados de baja no distorsionen el promedio.
