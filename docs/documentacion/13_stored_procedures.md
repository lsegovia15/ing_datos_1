# 13. Stored Procedures

Scripts: `sql/sp/SP_RegistrarVenta.sql`, `sql/sp/SP_AnularVenta.sql`, `sql/sp/SP_AjustarStock.sql`, `sql/cursores.sql`

Los stored procedures son la única vía para las operaciones que afectan el stock por venta o por ajuste. Todos siguen la misma estructura:

1. `SET NOCOUNT ON` y `SET XACT_ABORT ON`.
2. Validaciones de parámetros y de existencia de registros, que lanzan `THROW` con un código propio.
3. `BEGIN TRANSACTION` → modificaciones → `COMMIT`.
4. `BEGIN CATCH`: `ROLLBACK` si hay una transacción abierta y `THROW;` para relanzar el error original.
5. Un `SELECT` final con el resultado de la operación.

El detalle de los códigos de error está en [17_manejo_errores.md](17_manejo_errores.md).

---

## SP_RegistrarVenta

**Situación real:** el vendedor cobra una venta con uno o más productos.

**Parámetros de entrada:**

| Parámetro | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `@IdCliente` | `INT` | No (`NULL`) | Cliente; `NULL` = consumidor final |
| `@IdUsuario` | `INT` | Sí | Vendedor que registra la venta |
| `@MedioPago` | `VARCHAR(20)` | Sí | `EFECTIVO`, `DEBITO`, `CREDITO` o `TRANSFERENCIA` |
| `@Detalle` | `TipoDetalleVenta READONLY` | Sí | Líneas de la venta: `IdVariante`, `Cantidad`, `PrecioUnitario`, `Descuento` |

**Por qué un Table-Valued Parameter:** `@Detalle` recibe todo el "carrito" como una tabla tipada. Así la venta completa se registra en una sola llamada y dentro de una sola transacción, sin concatenar strings ni hacer una llamada por línea.

**Validaciones:**
- El detalle no está vacío (50001).
- El usuario existe (50002) y el cliente, si se informa, existe (50003).
- No se repite la misma variante en el carrito (50004).
- Todas las variantes existen (50005).
- Hay stock suficiente para cada línea (50006). El mensaje indica el SKU, la cantidad pedida y la disponible.

**Procesamiento y modificación de datos:**
1. Calcula el total: `SUM(Cantidad * PrecioUnitario - Descuento)`.
2. Genera `IdVenta` como `MAX + 1` con `WITH (UPDLOCK, HOLDLOCK)`, para que dos ventas simultáneas no obtengan el mismo número.
3. Inserta la cabecera en `Venta` con estado `CONFIRMADA`.
4. Inserta las líneas en `DetalleVenta`. El trigger `TR_DetalleVenta_Insert` genera los movimientos `SALIDA`, que a su vez descuentan el stock.

**Resultado:** `IdVentaGenerada`, `TotalVenta`, `Mensaje`.

**Ejemplo:**
```sql
DECLARE @Detalle TipoDetalleVenta;
INSERT INTO @Detalle (IdVariante, Cantidad, PrecioUnitario, Descuento)
VALUES (1, 2, 15000, 0),
       (4, 1, 22000, 2000);

EXEC SP_RegistrarVenta
     @IdCliente = NULL,
     @IdUsuario = 2,
     @MedioPago = 'DEBITO',
     @Detalle   = @Detalle;
```

---

## SP_AnularVenta

**Situación real:** un cliente devuelve la compra o la venta se cargó mal. La venta no se borra: se anula y se devuelve el stock.

**Parámetros de entrada:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@IdVenta` | `INT` | Venta a anular |
| `@IdUsuario` | `INT` | Usuario que autoriza la anulación (queda registrado para auditoría) |

**Validaciones:**
- La venta existe (50010).
- La venta no está ya anulada (50011).
- El usuario existe (50012).

**Procesamiento y modificación de datos:**
1. Guarda `@IdUsuario` en el contexto de sesión (`sp_set_session_context`, clave `IdUsuarioOperacion`).
2. Cambia `Venta.Estado` a `ANULADA`.
3. El trigger `TR_Venta_CambioEstado` inserta un movimiento `DEVOLUCION` por cada línea de la venta, a nombre del usuario leído del contexto de sesión.
4. Limpia el contexto de sesión, tanto en el camino exitoso como en el `CATCH`, porque el contexto de sesión no se revierte con el `ROLLBACK`.

**Por qué el contexto de sesión:** un trigger no recibe parámetros. Sin este mecanismo, la devolución quedaría registrada a nombre del vendedor original y no de quien anuló, y se perdería la trazabilidad.

**Resultado:** `IdVentaAnulada`, `Mensaje`.

**Ejemplo:**
```sql
EXEC SP_AnularVenta @IdVenta = 15, @IdUsuario = 1;
```

---

## SP_AjustarStock

**Situación real:** al hacer un recuento físico, el stock real no coincide con el del sistema (por rotura, robo o error de carga).

**Parámetros de entrada:**

| Parámetro | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `@IdVariante` | `INT` | Sí | Variante a ajustar |
| `@NuevaCantidad` | `INT` | Sí | Stock contado físicamente |
| `@IdUsuario` | `INT` | Sí | Usuario que realiza el ajuste |
| `@Observacion` | `VARCHAR(200)` | No | Motivo (por defecto `'Ajuste manual de inventario'`) |

**Validaciones:**
- La nueva cantidad no es negativa (50020).
- El usuario existe (50021).
- La variante existe (50022).

**Procesamiento y modificación de datos:**
1. Dentro de la transacción, genera `IdMovimiento` y lee `StockActual`, ambos con `WITH (UPDLOCK, HOLDLOCK)`. Leer el stock bloqueado evita que una venta concurrente lo modifique entre la lectura y el ajuste.
2. Calcula `Diferencia = NuevaCantidad - StockActual`.
3. Si la diferencia es 0, confirma sin registrar nada e informa que no hubo cambios.
4. Si no, inserta un movimiento `AJUSTE` con la **diferencia con signo** (negativa si faltaba mercadería). El trigger `TR_MovimientoStock_AplicarStock` la aplica sobre el stock.

**Resultado:** `IdVariante`, `StockAnterior`, `StockNuevo`, `Diferencia`, `Mensaje`.

**Ejemplo:**
```sql
-- El sistema dice 10, pero se contaron 7
EXEC SP_AjustarStock
     @IdVariante    = 3,
     @NuevaCantidad = 7,
     @IdUsuario     = 1,
     @Observacion   = 'Recuento mensual: faltante';
```

---

## SP_InformeReposicionStock

Es un procedimiento de consulta: no recibe parámetros ni modifica datos. Recorre con un cursor las variantes con stock bajo y calcula cuánto reponer de cada una. Está documentado en [15_cursores.md](15_cursores.md).

```sql
EXEC SP_InformeReposicionStock;
```
