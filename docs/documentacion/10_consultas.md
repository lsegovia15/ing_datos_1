# 10. Consultas SQL

Script: `sql/sp/ConsultasAvanzadas.sql` (partes 1 y 2)

## Cobertura de los elementos pedidos

| Elemento | Dónde se usa |
|---|---|
| `SELECT` | Todas |
| `WHERE` | Todas (filtro por estado) |
| `ORDER BY` | 1.1, 2.1, 2.2 |
| `JOIN` | 1.1, 2.1 (y las vistas de la sección 12) |
| `GROUP BY` | 2.1, 2.2 |
| `HAVING` | 2.1 |
| Funciones de agregación | 2.1 (`COUNT`, `SUM`, `AVG`), 2.2 (`COUNT`, `SUM`) |
| Consultas sobre múltiples tablas | 1.1 (cinco tablas), 2.1 |
| Condiciones sobre los resultados | 2.1 (`HAVING` sobre el total agregado) |
| Operaciones de conjuntos | 1.1 (`UNION`) |
| Funciones de fecha | 2.2 (`YEAR`, `MONTH`) |

---

## 1.1 Reporte unificado de compras y ventas (caja diaria)

**Necesidad:** ver en un solo listado todo el dinero que entró (ventas) y salió (compras), ordenado por fecha.

```sql
SELECT 'VENTA' AS TipoOperacion, v.IdVenta AS NroOperacion, v.Fecha,
       ISNULL(c.Nombre + ' ' + c.Apellido, 'Consumidor Final') AS Tercero,
       u.NombreUsuario AS Responsable, v.Total
FROM Venta v
LEFT JOIN Cliente c ON v.IdCliente = c.IdCliente
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
WHERE v.Estado = 'CONFIRMADA'

UNION

SELECT 'COMPRA', co.IdCompra, co.Fecha, p.RazonSocial, u.NombreUsuario, co.Total
FROM Compra co
INNER JOIN Proveedor p ON co.IdProveedor = p.IdProveedor
INNER JOIN Usuario u ON co.IdUsuario = u.IdUsuario
WHERE co.Estado = 'RECIBIDA'
ORDER BY Fecha DESC;
```

**Cómo funciona:**
- Cada parte une la cabecera con el tercero (cliente o proveedor) y con el usuario responsable.
- Se usa `LEFT JOIN` con `Cliente` porque las ventas a consumidor final no tienen cliente. Con `INNER JOIN` quedarían afuera.
- Solo se incluyen operaciones que movieron dinero: ventas confirmadas y compras recibidas.
- `UNION` combina ambos resultados. Las dos partes deben tener la misma cantidad de columnas, con tipos compatibles.
- El `ORDER BY` final ordena el resultado combinado.

> **Nota:** como la columna `TipoOperacion` distingue ventas de compras, nunca hay filas duplicadas entre las dos partes. `UNION ALL` daría el mismo resultado sin el paso extra de eliminar duplicados, que `UNION` siempre realiza.

---

## 2.1 Ranking de vendedores

**Necesidad:** saber cuánto vendió cada vendedor, cuántas operaciones hizo y cuál es su ticket promedio.

```sql
SELECT u.NombreUsuario,
       u.Nombre + ' ' + u.Apellido AS NombreCompleto,
       COUNT(v.IdVenta) AS CantidadVentas,
       SUM(v.Total)     AS TotalFacturado,
       AVG(v.Total)     AS TicketPromedio
FROM Venta v
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
WHERE v.Estado = 'CONFIRMADA'
GROUP BY u.NombreUsuario, u.Nombre, u.Apellido
HAVING SUM(v.Total) > 0
ORDER BY TotalFacturado DESC;
```

**Cómo funciona:**
- `WHERE` descarta las ventas anuladas **antes** de agrupar.
- `GROUP BY` arma un grupo por vendedor, y las funciones de agregación calculan cantidad, suma y promedio de cada grupo.
- `HAVING` filtra **después** de agrupar, sobre el resultado agregado: muestra solo a los vendedores que facturaron algo. Es la diferencia clave con `WHERE`, que no puede usar funciones de agregación.

---

## 2.2 Ventas por mes y medio de pago

**Necesidad:** ver la evolución mensual de las ventas y qué medios de pago se usan más, por ejemplo para negociar comisiones con los procesadores de tarjetas.

```sql
SELECT YEAR(v.Fecha)  AS Anio,
       MONTH(v.Fecha) AS Mes,
       v.MedioPago,
       COUNT(v.IdVenta) AS CantidadOperaciones,
       SUM(v.Total)     AS TotalRecaudado
FROM Venta v
WHERE v.Estado = 'CONFIRMADA'
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha), v.MedioPago
ORDER BY Anio DESC, Mes DESC, TotalRecaudado DESC;
```

**Cómo funciona:**
- Agrupa por año, mes y medio de pago. Las expresiones del `GROUP BY` deben repetirse tal cual en el `SELECT`.
- Ordena con lo más reciente primero y, dentro de cada mes, con el medio de pago que más recaudó arriba.

---

## Otras consultas del sistema

Además de estas consultas, hay lógica de consulta encapsulada en otros objetos:

- **Vistas** (`vw_StockVariante`, `vw_VentasDetalladas`, `vw_ProductosPremium`, `vw_CategoriasMasVendidasPorSegmento`): ver la [sección 12](12_vistas.md).
- **Función** `fn_ResumenVentasPorUsuario`: un resumen de ventas parametrizado por fechas. Ver la [sección 16](16_funciones.md).
- **Subconsultas**: ver la [sección 11](11_subconsultas.md).
