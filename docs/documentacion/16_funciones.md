# 16. Funciones

Script: `sql/funciones.sql`

---

## fn_EstadoStock (función escalar)

**Objetivo:** devolver en una palabra el estado de stock de una variante, para usar el mismo criterio en cualquier consulta.

**Parámetros:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@IdVariante` | `INT` | Variante a evaluar |

**Tipo de retorno:** `VARCHAR(20)`

**Lógica implementada:** une la variante con su producto y evalúa las condiciones en este orden (gana la primera que se cumple):

| Resultado | Condición |
|---|---|
| `INACTIVO` | El producto está dado de baja (`Activo = 0`) |
| `SIN STOCK` | `StockActual = 0` |
| `BAJO STOCK` | `StockActual <= StockMinimo` |
| `STOCK SUFICIENTE` | En otro caso |

Si la variante no existe, devuelve `NULL`.

El orden importa: si el producto está dado de baja, el estado es `INACTIVO` aunque tenga stock.

**Ejemplo de utilización:**
```sql
-- Estado de una variante puntual
SELECT dbo.fn_EstadoStock(5) AS Estado;

-- Estado de todas las variantes
SELECT SKU, StockActual, dbo.fn_EstadoStock(IdVariante) AS Estado
FROM VarianteProducto;
```

---

## fn_ResumenVentasPorUsuario (función con valor de tabla en línea)

**Objetivo:** obtener cuánto vendió cada vendedor en un período, para evaluar su desempeño o calcular comisiones.

**Parámetros:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@FechaDesde` | `DATE` | Primer día del período (inclusive) |
| `@FechaHasta` | `DATE` | Último día del período (inclusive) |

**Tipo de retorno:** tabla con las columnas `IdUsuario`, `NombreUsuario`, `CantidadVentas` y `TotalVendido` (`DECIMAL(18,2)`).

**Lógica implementada:**
- Considera solo ventas `CONFIRMADA`, así que las anuladas no suman.
- El filtro de fechas es `Fecha >= @FechaDesde AND Fecha < @FechaHasta + 1 día`. Como `Venta.Fecha` es `DATETIME`, esto incluye el último día completo hasta las 23:59:59. Con un `BETWEEN` simple, quedarían afuera las ventas de ese día posteriores a la medianoche.
- Agrupa por usuario y devuelve la cantidad de ventas y el total vendido.

**Por qué una función de tabla en línea y no un SP:** el resultado se puede usar como una tabla dentro de otra consulta (filtrar, ordenar, unir), cosa que con un SP no se puede. Además, al ser "en línea", el motor la expande como si fuera una vista parametrizada y la optimiza junto con la consulta que la usa.

**Ejemplo de utilización:**
```sql
-- Ranking de vendedores de octubre
SELECT NombreUsuario, CantidadVentas, TotalVendido
FROM dbo.fn_ResumenVentasPorUsuario('2026-10-01', '2026-10-31')
ORDER BY TotalVendido DESC;
```
