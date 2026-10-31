# Implementación de Procedimientos Almacenados y Control de Errores

Para garantizar la integridad de los datos y evitar condiciones de carrera (como vender un producto que ya no tiene stock), se implementaron Procedimientos Almacenados (SPs) con las siguientes características técnicas:

### 1. Uso de Table-Valued Parameters (TVP)
Para el registro de ventas se creó el tipo `TipoDetalleVenta` y para las compras el tipo `TipoDetalleCompra`. Esto permite enviar todo el "carrito" como una tabla en memoria al SP, lo que mejora el rendimiento y mantiene la integridad de los tipos de datos (evitando concatenación de strings e inyección SQL).

### 2. Reparto de responsabilidades entre SPs y triggers
Los SPs validan los datos de entrada y escriben la operación principal (`Venta`, `DetalleVenta`, cambio de `Estado`, `MovimientoStock` de tipo `AJUSTE`). Los movimientos de stock derivados y la actualización de `VarianteProducto.StockActual` los hacen los triggers de `siam_triggers.sql`:

| Operación | Lo hace el SP | Lo hace el trigger |
|---|---|---|
| Registrar venta | Inserta `Venta` y `DetalleVenta`; marca `PermitirDetalleVenta` | `TR_DetalleVenta_Insert` genera la `SALIDA` y recalcula `Total` |
| Anular venta | Valida rol `Administrador` y pasa `Estado` a `ANULADA` | `TR_Venta_CambioEstado` genera la `DEVOLUCION` |
| Registrar compra | Inserta `Compra` y `DetalleCompra` en `PENDIENTE` | `TR_DetalleCompra_Control` recalcula `Total` |
| Recibir compra | Cambia `PENDIENTE` a `RECIBIDA` | `TR_Compra_CambioEstado` genera la `ENTRADA` y actualiza stock |
| Ajustar stock | Inserta el `AJUSTE` con la diferencia firmada | `TR_MovimientoStock_AplicarStock` suma o resta el stock |

Para que la devolución quede registrada a nombre de quien anula (y no del vendedor original), `SP_AnularVenta` le pasa `@IdUsuario` al trigger con `sp_set_session_context` (clave `IdUsuarioOperacion`). Del mismo modo, `SP_RecibirCompra` usa esa clave para que la `ENTRADA` quede a nombre de quien recibe.

`SP_RegistrarVenta` usa la clave `PermitirDetalleVenta` para que `TR_DetalleVenta_Insert` distinga la inserción legítima del SP de una inserción directa. Además, el trigger rechaza agregar líneas sueltas a una venta que ya tiene detalle (error 51014).

`TR_Variante_AlertaStock` se dispara tanto en `INSERT` como en `UPDATE`: si una variante se crea directamente con stock menor o igual al mínimo, genera la alerta; en `UPDATE` solo la genera cuando el stock cruza el mínimo, evitando alertas repetidas en cada venta.

### 3. Transacciones (ACID)
Todos los SPs que modifican datos están envueltos en bloques de transacción (`BEGIN TRANSACTION` ... `COMMIT TRANSACTION`), y los triggers corren dentro de esa misma transacción. 
Esto asegura que, si falla la inserción del detalle o un trigger rechaza la operación (por ejemplo, por falta de stock), la cabecera de la venta no quede "huérfana" en la base de datos. Además, `SET XACT_ABORT ON` garantiza que cualquier error revierta la transacción completa.

### 4. Manejo de Errores con TRY / CATCH
Se utilizan bloques `BEGIN TRY ... END CATCH` en todos los SPs. 
- Las validaciones de negocio (ej: "no hay stock suficiente" o "la venta ya está anulada") se lanzan intencionalmente usando `THROW`. 
- El bloque `CATCH` hace el `ROLLBACK` si hay una transacción abierta y relanza el error original con `THROW;`, conservando su número y mensaje.

### 5. Concurrencia y Bloqueos
- **Stock negativo:** la validación previa del SP da un mensaje claro (con el SKU), pero la garantía real está dentro de la transacción: el trigger `TR_MovimientoStock_AplicarStock` rechaza el movimiento si deja stock negativo, y el `CHECK (StockActual >= 0)` actúa como última barrera.
- **IDs con `MAX + 1`:** se leen con `WITH (UPDLOCK, HOLDLOCK)` dentro de la transacción (`IdVenta` en `SP_RegistrarVenta`, `IdCompra` en `SP_RegistrarCompra`, `IdMovimiento` en `SP_AjustarStock` y en los triggers), así dos operaciones simultáneas no obtienen el mismo ID.
- **Ajuste de stock:** `SP_AjustarStock` lee `StockActual` bloqueado dentro de la transacción, para que una venta concurrente no altere la diferencia calculada.
- **Anulación y recepción:** `SP_AnularVenta` y `SP_RecibirCompra` leen la cabecera con `UPDLOCK, HOLDLOCK` y actualizan condicionando por estado (`CONFIRMADA` / `PENDIENTE`), para que dos operaciones concurrentes no dupliquen devoluciones o entradas.
- **Detalle de venta:** `TR_DetalleVenta_Insert` exige la marca de sesión del SP y que todas las líneas de la venta se inserten en una sola sentencia; una inserción directa se rechaza con 51013 y un agregado posterior con 51014.
- **Orden de bloqueo:** todos los caminos bloquean en el mismo orden (`Venta`/`Compra` → `MovimientoStock` → `VarianteProducto`) para evitar deadlocks.

### 6. Códigos de error
Los rangos están separados para poder identificar el origen de cada error:

| Código / rango | Origen |
|---|---|
| 50001 – 50006 | `SP_RegistrarVenta` |
| 50010 – 50013 | `SP_AnularVenta` (incluye 50013: rol no administrador) |
| 50020 – 50022 | `SP_AjustarStock` |
| 50100 – 50106 | `SP_RegistrarCompra` (detalle, proveedor, usuario, duplicados, cantidades, costos, variantes) |
| 50110 – 50113 | `SP_RecibirCompra` (compra inexistente, sin líneas, estado incorrecto, usuario) |
| 51000 – 51099 | Triggers (`siam_triggers.sql`) |

**Casos borde cubiertos en `seed_data.sql`:** venta sin stock (50006), compra sin detalle (50100), recepción sin líneas (50111), ajuste sin diferencia (sin movimiento) y anulación duplicada (50011). También se prueba que un vendedor no puede anular (50013).

### 7. Documentación por procedimiento

- [SP_RegistrarVenta](SP_RegistrarVenta.md)
- [SP_AnularVenta](SP_AnularVenta.md)
- [SP_AjustarStock](SP_AjustarStock.md)
- [SP_RegistrarCompra](SP_RegistrarCompra.md)
- [SP_RecibirCompra](SP_RecibirCompra.md)
