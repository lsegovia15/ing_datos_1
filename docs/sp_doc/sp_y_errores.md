# Implementación de Procedimientos Almacenados y Control de Errores

Para garantizar la integridad de los datos y evitar condiciones de carrera (como vender un producto que ya no tiene stock), se implementaron Procedimientos Almacenados (SPs) con las siguientes características técnicas:

### 1. Uso de Table-Valued Parameters (TVP)
Para el registro de ventas, en lugar de enviar los datos uno por uno o usar strings concatenados, se creó el tipo de dato `TipoDetalleVenta`. Esto permite enviar todo el "carrito de compras" como una tabla en memoria al SP, lo que mejora el rendimiento y mantiene la integridad de los tipos de datos (evitando inyección SQL).

### 2. Reparto de responsabilidades entre SPs y triggers
Los SPs validan los datos de entrada y escriben la operación principal (`Venta`, `DetalleVenta`, cambio de `Estado`, `MovimientoStock` de tipo `AJUSTE`). Los movimientos de stock derivados y la actualización de `VarianteProducto.StockActual` los hacen los triggers de `firme38_triggers.sql`:

| Operación | Lo hace el SP | Lo hace el trigger |
|---|---|---|
| Registrar venta | Inserta `Venta` y `DetalleVenta` | `TR_DetalleVenta_Insert` genera la `SALIDA` y recalcula `Total` |
| Anular venta | Pasa `Estado` a `ANULADA` | `TR_Venta_CambioEstado` genera la `DEVOLUCION` |
| Ajustar stock | Inserta el `AJUSTE` con la diferencia firmada | `TR_MovimientoStock_AplicarStock` suma o resta el stock |

Para que la devolución quede registrada a nombre de quien anula (y no del vendedor original), `SP_AnularVenta` le pasa `@IdUsuario` al trigger con `sp_set_session_context` (clave `IdUsuarioOperacion`).

### 3. Transacciones (ACID)
Todos los SPs que modifican datos están envueltos en bloques de transacción (`BEGIN TRANSACTION` ... `COMMIT TRANSACTION`), y los triggers corren dentro de esa misma transacción. 
Esto asegura que, si falla la inserción del detalle o un trigger rechaza la operación (por ejemplo, por falta de stock), la cabecera de la venta no quede "huérfana" en la base de datos. Además, `SET XACT_ABORT ON` garantiza que cualquier error revierta la transacción completa.

### 4. Manejo de Errores con TRY / CATCH
Se utilizan bloques `BEGIN TRY ... END CATCH` en todos los SPs. 
- Las validaciones de negocio (ej: "no hay stock suficiente" o "la venta ya está anulada") se lanzan intencionalmente usando `THROW`. 
- El bloque `CATCH` hace el `ROLLBACK` si hay una transacción abierta y relanza el error original con `THROW;`, conservando su número y mensaje.

### 5. Concurrencia y Bloqueos
- **Stock negativo:** la validación previa del SP da un mensaje claro (con el SKU), pero la garantía real está dentro de la transacción: el trigger `TR_MovimientoStock_AplicarStock` rechaza el movimiento si deja stock negativo, y el `CHECK (StockActual >= 0)` actúa como última barrera.
- **IDs con `MAX + 1`:** se leen con `WITH (UPDLOCK, HOLDLOCK)` dentro de la transacción (`IdVenta` en `SP_RegistrarVenta`, `IdMovimiento` en `SP_AjustarStock` y en los triggers), así dos operaciones simultáneas no obtienen el mismo ID.
- **Ajuste de stock:** `SP_AjustarStock` lee `StockActual` bloqueado dentro de la transacción, para que una venta concurrente no altere la diferencia calculada.
- **Orden de bloqueo:** todos los caminos bloquean en el mismo orden (`Venta` → `MovimientoStock` → `VarianteProducto`) para evitar deadlocks.

### 6. Códigos de error
Los rangos están separados para poder identificar el origen de cada error:

| Rango | Origen |
|---|---|
| 50001 – 50006 | `SP_RegistrarVenta` |
| 50010 – 50012 | `SP_AnularVenta` |
| 50020 – 50022 | `SP_AjustarStock` |
| 51000 – 51099 | Triggers (`firme38_triggers.sql`) |
