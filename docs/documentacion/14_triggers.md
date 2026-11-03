# 14. Triggers

Script: `sql/firme38_triggers.sql`

Los triggers implementan las reglas que deben cumplirse **siempre**, sin importar desde dónde se modifiquen los datos (un SP, una consulta manual o una aplicación). Si una regla dependiera solo de los SPs, un `INSERT` directo podría saltearla.

Todos los triggers están escritos para operaciones de varias filas (trabajan con las tablas `inserted` y `deleted` completas, nunca con una sola fila) y corren dentro de la transacción de la sentencia que los dispara. Cuando un trigger lanza `THROW`, se revierte la operación completa.

El script también crea dos tablas auxiliares que alimentan los triggers: `HistorialPrecio` y `AlertaStock`.

## Resumen

| # | Trigger | Tabla | Evento | Tipo |
|---|---|---|---|---|
| 1 | `TR_MovimientoStock_AplicarStock` | `MovimientoStock` | `INSERT` | `AFTER` |
| 2 | `TR_MovimientoStock_Inmutable` | `MovimientoStock` | `UPDATE`, `DELETE` | `AFTER` |
| 3 | `TR_Venta_UsuarioActivo` | `Venta` | `INSERT` | `AFTER` |
| 4 | `TR_Compra_UsuarioActivo` | `Compra` | `INSERT` | `AFTER` |
| 5 | `TR_DetalleVenta_Insert` | `DetalleVenta` | `INSERT` | `AFTER` |
| 6 | `TR_DetalleVenta_Inmutable` | `DetalleVenta` | `UPDATE`, `DELETE` | `AFTER` |
| 7 | `TR_Venta_CambioEstado` | `Venta` | `UPDATE` | `AFTER` |
| 8 | `TR_Compra_CambioEstado` | `Compra` | `UPDATE` | `AFTER` |
| 9 | `TR_DetalleCompra_Control` | `DetalleCompra` | `INSERT`, `UPDATE`, `DELETE` | `AFTER` |
| 10 | `TR_Variante_HistorialPrecio` | `VarianteProducto` | `UPDATE` | `AFTER` |
| 11 | `TR_Variante_AlertaStock` | `VarianteProducto` | `UPDATE` | `AFTER` |
| 12 | `TR_Venta_NoBorrar` | `Venta` | `DELETE` | `INSTEAD OF` |
| 13 | `TR_Compra_NoBorrar` | `Compra` | `DELETE` | `INSTEAD OF` |

## Flujo del stock

Los triggers se encadenan. Por ejemplo, al registrar una venta:

```
INSERT DetalleVenta
   └─► TR_DetalleVenta_Insert ── inserta SALIDA en MovimientoStock, recalcula Venta.Total
          └─► TR_MovimientoStock_AplicarStock ── valida y descuenta VarianteProducto.StockActual
                 └─► TR_Variante_AlertaStock ── si cruzó el mínimo, inserta en AlertaStock
```

La anulación de una venta (`DEVOLUCION`), la recepción de una compra (`ENTRADA`) y los ajustes (`AJUSTE`) siguen el mismo camino: siempre se inserta un movimiento y el stock lo actualiza un único trigger.

---

## 1. TR_MovimientoStock_AplicarStock

- **Evento:** `AFTER INSERT`
- **Tabla:** `MovimientoStock`
- **Condición:** siempre. Si el movimiento dejaría el stock negativo, lanza el error 51002.
- **Acción:** agrupa los movimientos insertados por variante y calcula el efecto neto: `SALIDA` resta, `ENTRADA` y `DEVOLUCION` suman, y `AJUSTE` suma su cantidad con signo. Después actualiza `VarianteProducto.StockActual`.
- **Regla de negocio:** el stock de una variante es siempre la suma de sus movimientos y nunca puede ser negativo. Es el único punto del sistema que modifica `StockActual`.

## 2. TR_MovimientoStock_Inmutable

- **Evento:** `AFTER UPDATE, DELETE`
- **Tabla:** `MovimientoStock`
- **Condición:** se intenta modificar o borrar cualquier movimiento.
- **Acción:** lanza el error 51003 y revierte la operación.
- **Regla de negocio:** los movimientos de stock son un registro histórico. Un error se corrige con un nuevo `AJUSTE`, nunca editando el pasado. También impide que las FK `ON DELETE SET NULL` alteren movimientos existentes.

## 3. TR_Venta_UsuarioActivo

- **Evento:** `AFTER INSERT`
- **Tabla:** `Venta`
- **Condición:** el usuario que registra la venta tiene `Activo = 0`.
- **Acción:** lanza el error 51004.
- **Regla de negocio:** un usuario dado de baja no puede operar.

## 4. TR_Compra_UsuarioActivo

- **Evento:** `AFTER INSERT`
- **Tabla:** `Compra`
- **Condición:** el usuario que registra la compra tiene `Activo = 0`.
- **Acción:** lanza el error 51005.
- **Regla de negocio:** igual que el anterior, para compras.

## 5. TR_DetalleVenta_Insert

- **Evento:** `AFTER INSERT`
- **Tabla:** `DetalleVenta`
- **Condición:**
  - Si la venta no está `CONFIRMADA`, lanza el error 51010.
  - Si alguna variante pertenece a un producto inactivo, lanza el error 51011.
- **Acción:** por cada línea inserta un movimiento `SALIDA` y luego recalcula `Venta.Total` a partir de todas sus líneas.
- **Regla de negocio:** toda venta descuenta stock, no se venden productos dados de baja y el total de la venta siempre coincide con su detalle.

## 6. TR_DetalleVenta_Inmutable

- **Evento:** `AFTER UPDATE, DELETE`
- **Tabla:** `DetalleVenta`
- **Condición:** se intenta modificar o borrar una línea de venta.
- **Acción:** lanza el error 51012.
- **Regla de negocio:** una venta confirmada no se edita línea por línea. Si está mal, se anula completa, lo que mantiene la coherencia con los movimientos de stock ya generados.

## 7. TR_Venta_CambioEstado

- **Evento:** `AFTER UPDATE` (solo si cambió la columna `Estado`)
- **Tabla:** `Venta`
- **Condición:**
  - De `ANULADA` a otro estado: lanza el error 51020.
  - De `CONFIRMADA` a `ANULADA`: genera la devolución.
- **Acción:** inserta un movimiento `DEVOLUCION` por cada línea de la venta. El usuario se toma de `SESSION_CONTEXT('IdUsuarioOperacion')`, que carga `SP_AnularVenta`. Si la anulación se hizo sin el SP, se usa el vendedor original.
- **Regla de negocio:** anular una venta devuelve el stock, y una anulación es definitiva.

## 8. TR_Compra_CambioEstado

- **Evento:** `AFTER UPDATE` (solo si cambió la columna `Estado`)
- **Tabla:** `Compra`
- **Condición:**
  - Si la compra no estaba `PENDIENTE`, lanza el error 51030.
  - Si pasa de `PENDIENTE` a `RECIBIDA` sin líneas, lanza el error 51031.
- **Acción:** al pasar de `PENDIENTE` a `RECIBIDA`, inserta un movimiento `ENTRADA` por cada línea de la compra.
- **Regla de negocio:** las únicas transiciones válidas son `PENDIENTE → RECIBIDA` y `PENDIENTE → ANULADA`. La mercadería entra al stock recién cuando se recibe, no cuando se pide.

## 9. TR_DetalleCompra_Control

- **Evento:** `AFTER INSERT, UPDATE, DELETE`
- **Tabla:** `DetalleCompra`
- **Condición:** la compra afectada no está `PENDIENTE`. En ese caso lanza el error 51040.
- **Acción:** recalcula `Compra.Total` como `SUM(Cantidad * CostoUnitario)` de sus líneas.
- **Regla de negocio:** una compra solo se arma mientras está pendiente. Una vez recibida o anulada queda cerrada, y su total siempre coincide con su detalle.

## 10. TR_Variante_HistorialPrecio

- **Evento:** `AFTER UPDATE` (solo si cambió `PrecioVenta`)
- **Tabla:** `VarianteProducto`
- **Condición:** el precio nuevo es distinto del anterior.
- **Acción:** inserta en `HistorialPrecio` el precio anterior, el nuevo, la fecha y el usuario de base de datos.
- **Regla de negocio:** todo cambio de precio queda auditado.

## 11. TR_Variante_AlertaStock

- **Evento:** `AFTER UPDATE` (solo si cambió `StockActual`)
- **Tabla:** `VarianteProducto`
- **Condición:** el stock **cruzó** el mínimo, es decir, antes era mayor al mínimo y ahora es menor o igual.
- **Acción:** inserta una alerta en `AlertaStock` (sin atender).
- **Regla de negocio:** avisar cuando hay que reponer. Se dispara solo al cruzar el umbral, no en cada venta posterior, para no llenar la tabla de alertas repetidas.

## 12. TR_Venta_NoBorrar

- **Evento:** `INSTEAD OF DELETE`
- **Tabla:** `Venta`
- **Condición:** cualquier intento de borrar una venta.
- **Acción:** lanza el error 51050 sin borrar nada.
- **Regla de negocio:** baja lógica: las ventas se anulan, no se borran. Se usa `INSTEAD OF` porque corta el `DELETE` antes de que se ejecuten los `ON DELETE CASCADE` hacia `DetalleVenta`.

## 13. TR_Compra_NoBorrar

- **Evento:** `INSTEAD OF DELETE`
- **Tabla:** `Compra`
- **Condición:** cualquier intento de borrar una compra.
- **Acción:** lanza el error 51051.
- **Regla de negocio:** igual que el anterior, para compras.
