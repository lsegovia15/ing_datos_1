# 14. Triggers

Script: `sql/siam_triggers.sql`

Los triggers mantienen el stock y los totales sincronizados con las operaciones, y registran alertas y auditoría. Todos trabajan con las tablas `inserted` y `deleted` completas (varias filas por sentencia) y corren dentro de la transacción de la sentencia que los dispara: si uno lanza `THROW`, se revierte toda la operación.

El script también crea dos tablas auxiliares: `AlertaStock` y `HistorialPrecio`.

## Resumen

| # | Trigger | Tabla | Evento | Tipo |
|---|---|---|---|---|
| 1 | `TR_DescontarStockVenta` | `DetalleVenta` | `INSERT` | `AFTER` |
| 2 | `TR_CalcularTotalVenta` | `DetalleVenta` | `INSERT` | `AFTER` |
| 3 | `TR_DevolverStockAnulacion` | `Venta` | `UPDATE` | `AFTER` |
| 4 | `TR_SumarStockCompra` | `Compra` | `UPDATE` | `AFTER` |
| 5 | `TR_AvisoStockMinimo` | `VarianteProducto` | `UPDATE` | `AFTER` |
| 6 | `TR_HistorialPrecio` | `VarianteProducto` | `UPDATE` | `AFTER` |
| 7 | `TR_NoBorrarVenta` | `Venta` | `DELETE` | `INSTEAD OF` |
| 8 | `TR_AplicarAjusteStock` | `MovimientoStock` | `INSERT` | `AFTER` |

## Flujo del stock

| Operación | Quién la dispara | Trigger que actualiza `StockActual` |
|---|---|---|
| Venta | `SP_RegistrarVenta` inserta en `DetalleVenta` | `TR_DescontarStockVenta` resta |
| Anulación | `SP_AnularVenta` pasa la venta a `ANULADA` | `TR_DevolverStockAnulacion` suma |
| Recepción de compra | `SP_RecibirCompra` pasa la compra a `RECIBIDA` | `TR_SumarStockCompra` suma |
| Ajuste | `SP_AjustarStock` inserta un `AJUSTE` en `MovimientoStock` | `TR_AplicarAjusteStock` suma la diferencia con signo |

Cada vez que `StockActual` se actualiza, se disparan además `TR_AvisoStockMinimo` (alerta) y, si cambió el precio, `TR_HistorialPrecio`.

`MovimientoStock` solo registra los ajustes manuales. Las ventas, anulaciones y recepciones modifican el stock directamente y no generan movimientos. El `CHECK` de la tabla admite también `ENTRADA`, `SALIDA` y `DEVOLUCION`, pero hoy ningún objeto los inserta.

---

## 1. TR_DescontarStockVenta

- **Evento:** `AFTER INSERT` en `DetalleVenta`.
- **Condición:** la cantidad pedida de una variante (sumando todas las filas insertadas) supera su `StockActual`. En ese caso lanza el error 50200 ("No hay stock suficiente para realizar la venta.") y se revierte la venta completa.
- **Acción:** resta al `StockActual` la cantidad insertada de cada variante, agrupada con `SUM(...) GROUP BY IdVariante`. Así funciona aunque un mismo `INSERT` traiga la misma variante en varias filas (por ejemplo, de dos ventas distintas): el trigger no asume que se ejecuta fila por fila.
- **Regla:** no se vende más de lo que hay. Funciona también para inserciones que no pasan por el SP.

## 2. TR_CalcularTotalVenta

- **Evento:** `AFTER INSERT` en `DetalleVenta`.
- **Acción:** recalcula `Venta.Total` como `SUM(Cantidad * PrecioUnitario - Descuento)` de todas las líneas de las ventas afectadas.
- **Regla:** el total de la venta coincide con su detalle.

## 3. TR_DevolverStockAnulacion

- **Evento:** `AFTER UPDATE` en `Venta`.
- **Condición:** la venta pasó de `CONFIRMADA` a `ANULADA`. Cualquier otro cambio de estado (por ejemplo, `ANULADA` → `CONFIRMADA`) se rechaza con el error 50201, porque el stock no se volvería a descontar.
- **Acción:** suma al `StockActual` la `Cantidad` de las líneas de las ventas anuladas, agrupada por variante (un mismo `UPDATE` puede anular varias ventas con la misma variante).
- **Regla:** anular una venta devuelve el stock, y una venta anulada no se reactiva.

## 4. TR_SumarStockCompra

- **Evento:** `AFTER UPDATE` en `Compra`.
- **Condición:** la compra pasó de `PENDIENTE` a `RECIBIDA`. Solo se aceptan los cambios `PENDIENTE` → `RECIBIDA` y `PENDIENTE` → `ANULADA`; cualquier otro (por ejemplo, `RECIBIDA` → `PENDIENTE`, que permitiría recibirla dos veces) se rechaza con el error 50202.
- **Acción:** suma al `StockActual` la `Cantidad` de las líneas de las compras recibidas, agrupada por variante.
- **Regla:** la mercadería entra al stock cuando se recibe, no cuando se pide, y una sola vez.

## 5. TR_AvisoStockMinimo

- **Evento:** `AFTER UPDATE` en `VarianteProducto`.
- **Condición:** el stock cruzó el mínimo: antes `StockActual > StockMinimo` y ahora `StockActual <= StockMinimo`.
- **Acción:** inserta una fila en `AlertaStock` (`Atendida = 0`) e imprime un aviso.
- **Regla:** avisar cuando hay que reponer. Se dispara solo al cruzar el umbral, no en cada venta posterior.

## 6. TR_HistorialPrecio

- **Evento:** `AFTER UPDATE` en `VarianteProducto`.
- **Condición:** `PrecioVenta` cambió.
- **Acción:** inserta en `HistorialPrecio` el precio anterior, el nuevo y la fecha.
- **Regla:** todo cambio de precio queda registrado.

## 7. TR_NoBorrarVenta

- **Evento:** `INSTEAD OF DELETE` en `Venta`.
- **Acción:** no borra nada y lanza el error 50203 ("Las ventas no se pueden borrar. Use SP_AnularVenta para anularla."). Se usa `THROW` y no `PRINT` para que quien ejecutó el `DELETE` se entere de que la operación no se realizó.
- **Regla:** las ventas se anulan, no se borran. Al ser `INSTEAD OF`, corta el borrado antes de los `ON DELETE CASCADE` hacia `DetalleVenta`. Además, `seguridad.sql` deniega `DELETE` sobre `Venta`, `DetalleVenta`, `Compra` y `DetalleCompra`.

## 8. TR_AplicarAjusteStock

- **Evento:** `AFTER INSERT` en `MovimientoStock`.
- **Condición:** solo actúa sobre movimientos de tipo `AJUSTE`.
- **Acción:** suma `Cantidad` (con signo) al `StockActual` de la variante, agrupada por variante.
- **Regla:** `SP_AjustarStock` inserta la diferencia entre el stock contado y el del sistema, y este trigger la aplica.

---

## Qué no controlan los triggers

Estas reglas se validan solo en los stored procedures:

- Que el usuario esté activo y tenga el rol adecuado.
- Que una compra tenga líneas antes de recibirse y que solo se reciba una `PENDIENTE`.
- Que `Compra.Total` coincida con su detalle (lo calcula `SP_RegistrarCompra`).

Un `UPDATE` o `INSERT` directo sobre las tablas saltea esas validaciones, por eso `seguridad.sql` restringe el acceso directo del vendedor.

Estas no se validan en ningún objeto (ni SP ni trigger): vender una variante de un producto inactivo, o modificar y borrar líneas de venta y movimientos de stock por fuera de los permisos.
