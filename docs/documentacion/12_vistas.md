# 12. Vistas

Script: `sql/vistas.sql`

Las vistas encapsulan consultas con varios `JOIN` que se usan seguido en la operación del local.

---

## vw_StockVariante

**Objetivo:** consultar el stock de cada variante con toda su descripción legible, sin tener que unir siete tablas cada vez.

**Información presentada:** producto, marca, categoría, segmento, talle, color, SKU, precio de venta, stock actual, stock mínimo y un estado calculado:

| EstadoStock | Condición |
|---|---|
| `SIN STOCK` | `StockActual = 0` |
| `BAJO STOCK` | `StockActual <= StockMinimo` |
| `STOCK SUFICIENTE` | en otro caso |

Solo incluye productos activos (`Producto.Activo = 1`).

**Tablas involucradas:** `VarianteProducto`, `Producto`, `Marca`, `Categoria`, `Segmento`, `Talle`, `Color`.

**Motivo de utilización:** es la consulta que hace el vendedor cuando un cliente pregunta por un talle o color, y la que usa el administrador para detectar faltantes. Centralizar el criterio de "bajo stock" en la vista evita que cada consulta lo calcule distinto.

```sql
-- Variantes con problemas de stock
SELECT Producto, Talle, Color, StockActual, EstadoStock
FROM vw_StockVariante
WHERE EstadoStock <> 'STOCK SUFICIENTE';
```

---

## vw_VentasDetalladas

**Objetivo:** listar las ventas con datos legibles de cliente y vendedor.

**Información presentada:** número de venta, fecha, cliente (o `Consumidor Final` si la venta no tiene cliente), vendedor, medio de pago, estado y total.

**Tablas involucradas:** `Venta`, `Cliente`, `Usuario`.

**Motivo de utilización:** las ventas a consumidor final tienen `IdCliente` en `NULL`. La vista resuelve ese caso con `LEFT JOIN` y un `CASE`, así quien consulta no tiene que acordarse de hacerlo. Incluye ventas confirmadas y anuladas, para poder buscar una venta antes de anularla.

```sql
SELECT IdVenta, Fecha, Cliente, Vendedor, Total
FROM vw_VentasDetalladas
WHERE Estado = 'CONFIRMADA'
ORDER BY Fecha DESC;
```

---

## vw_ProductosPremium

**Objetivo:** identificar los productos de mayor precio del catálogo.

**Información presentada:** nombre, precio base y marca de los productos activos cuyo precio base supera el promedio de los productos activos.

**Tablas involucradas:** `Producto`, `Marca`.

**Motivo de utilización:** sirve para armar exhibiciones o promociones de la línea más cara. Usa una subconsulta escalar (`AVG`) que se recalcula en cada consulta, por lo que el resultado se adapta solo cuando cambian los precios.

```sql
SELECT Nombre, PrecioBase, Marca
FROM vw_ProductosPremium
ORDER BY PrecioBase DESC;
```

---

## vw_CategoriasMasVendidasPorSegmento

**Objetivo:** saber cuál es la categoría más vendida dentro de cada segmento (hombre, mujer, niño, niña o unisex).

**Información presentada:** segmento, categoría, unidades vendidas, total vendido y posición en el ranking. Solo muestra la categoría que queda primera en cada segmento.

**Tablas involucradas:** `DetalleVenta`, `Venta`, `VarianteProducto`, `Producto`, `Categoria`, `Segmento`.

**Motivo de utilización:** sirve para decidir qué reponer y qué exhibir según el público. También muestra por qué el segmento se modeló en la variante y no en el producto: el mismo producto puede venderse en distintos segmentos, y esta vista los separa.

**Cómo funciona:**
- Una primera expresión de tabla común (`VentasPorCategoria`) suma unidades y total de las ventas `CONFIRMADA`, agrupando por segmento y categoría.
- Una segunda (`Ranking`) numera las categorías dentro de cada segmento con `RANK() OVER (PARTITION BY IdSegmento ORDER BY UnidadesVendidas DESC, TotalVendido DESC)`.
- El `SELECT` final se queda con `Posicion = 1`. Si dos categorías empatan en unidades y total, `RANK` les da la misma posición y aparecen las dos.

```sql
SELECT Segmento, Categoria, UnidadesVendidas, TotalVendido
FROM vw_CategoriasMasVendidasPorSegmento
ORDER BY Segmento;
```
