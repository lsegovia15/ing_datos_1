# Implementación de Procedimientos Almacenados y Control de Errores

Para garantizar la integridad de los datos y evitar condiciones de carrera (como vender un producto que ya no tiene stock), se implementaron Procedimientos Almacenados (SPs) con las siguientes características técnicas:

### 1. Uso de Table-Valued Parameters (TVP)
Para el registro de ventas se creó el tipo `TipoDetalleVenta` y para las compras el tipo `TipoDetalleCompra`. Esto permite enviar todo el "carrito" como una tabla en memoria al SP, lo que mejora el rendimiento y mantiene la integridad de los tipos de datos (evitando concatenación de strings e inyección SQL).

### 2. Reparto de responsabilidades entre SPs y triggers
Los SPs validan los datos de entrada y escriben la operación principal (`Venta`, `DetalleVenta`, cambio de `Estado`, `MovimientoStock` de tipo `AJUSTE`). La actualización de `VarianteProducto.StockActual` y de los totales la hacen los triggers de `siam_triggers.sql`:

| Operación | Lo hace el SP | Lo hace el trigger |
|---|---|---|
| Registrar venta | Inserta `Venta` y `DetalleVenta` | `TR_DescontarStockVenta` resta el stock; `TR_CalcularTotalVenta` recalcula el `Total` |
| Anular venta | Valida rol `Administrador` y pasa `Estado` a `ANULADA` | `TR_DevolverStockAnulacion` suma el stock |
| Registrar compra | Inserta `Compra` y `DetalleCompra` en `PENDIENTE` y calcula el `Total` | — |
| Recibir compra | Cambia `PENDIENTE` a `RECIBIDA` | `TR_SumarStockCompra` suma el stock |
| Ajustar stock | Inserta el `AJUSTE` con la diferencia firmada | `TR_AplicarAjusteStock` suma o resta el stock |

`SP_AnularVenta` y `SP_RecibirCompra` guardan `@IdUsuario` con `sp_set_session_context` (clave `IdUsuarioOperacion`) y `SP_RegistrarVenta` usa la clave `PermitirDetalleVenta`. Los triggers actuales no leen ninguna de las dos.

`TR_AvisoStockMinimo` se dispara en cada `UPDATE` de `VarianteProducto`: solo genera la alerta cuando el stock cruza el mínimo, para no repetirla en cada venta.

### 3. Transacciones (ACID)
Todos los SPs que modifican datos están envueltos en bloques de transacción (`BEGIN TRANSACTION` ... `COMMIT TRANSACTION`), y los triggers corren dentro de esa misma transacción. 
Esto asegura que, si falla la inserción del detalle o un trigger rechaza la operación (por ejemplo, `TR_DescontarStockVenta` por falta de stock), la cabecera de la venta no quede "huérfana" en la base de datos. Además, `SET XACT_ABORT ON` garantiza que cualquier error revierta la transacción completa.

### 4. Manejo de Errores con TRY / CATCH
Se utilizan bloques `BEGIN TRY ... END CATCH` en todos los SPs. 
- Las validaciones de negocio (ej: "no hay stock suficiente" o "la venta ya está anulada") se lanzan intencionalmente usando `THROW`. 
- El bloque `CATCH` hace el `ROLLBACK` si hay una transacción abierta y relanza el error original con `THROW;`, conservando su número y mensaje.

### 5. Concurrencia y Bloqueos
- **Stock negativo:** la validación previa del SP da un mensaje claro (con el SKU). Dentro de la transacción, `TR_DescontarStockVenta` rechaza la línea si no alcanza el stock, y el `CHECK (StockActual >= 0)` actúa como última barrera.
- **IDs con `MAX + 1`:** se leen con `WITH (UPDLOCK, HOLDLOCK)` dentro de la transacción (`IdVenta` en `SP_RegistrarVenta`, `IdCompra` en `SP_RegistrarCompra`, `IdMovimiento` en `SP_AjustarStock`), así dos operaciones simultáneas no obtienen el mismo ID.
- **Ajuste de stock:** `SP_AjustarStock` lee `StockActual` bloqueado dentro de la transacción, para que una venta concurrente no altere la diferencia calculada.
- **Anulación y recepción:** `SP_AnularVenta` y `SP_RecibirCompra` leen la cabecera con `UPDLOCK, HOLDLOCK` y actualizan condicionando por estado (`CONFIRMADA` / `PENDIENTE`), para que dos operaciones concurrentes no dupliquen devoluciones o entradas.

### 6. Códigos de error
Los rangos están separados para poder identificar el origen de cada error:

| Código / rango | Origen |
|---|---|
| 50001 – 50007 | `SP_RegistrarVenta` (50002: usuario inactivo; 50007: rol no permitido). El 50001 también lo lanza `TR_DescontarStockVenta` cuando no hay stock |
| 50010 – 50013 | `SP_AnularVenta` (incluye 50013: rol no administrador) |
| 50020 – 50023 | `SP_AjustarStock` (50021: usuario inactivo; 50023: rol no administrador) |
| 50100 – 50107 | `SP_RegistrarCompra` (detalle, proveedor, usuario, rol, duplicados, cantidades, costos, variantes) |
| 50110 – 50114 | `SP_RecibirCompra` (compra inexistente, sin líneas, estado incorrecto, usuario, rol) |

**Defensa en profundidad:** además de los permisos `GRANT`/`DENY` de `seguridad.sql`, los SPs administrativos vuelven a validar que el usuario de aplicación esté activo y tenga el rol correspondiente. Así, aunque en el futuro se concediera `EXECUTE` a otro rol de motor, la regla de negocio seguiría vigente.

**Casos borde cubiertos en `seed_data.sql`:** venta sin stock (50006), compra sin detalle (50100), recepción sin líneas (50111), ajuste sin diferencia (sin movimiento) y anulación duplicada (50011). También se prueba que un vendedor no puede anular (50013), ajustar stock (50023), registrar compras (50107) ni recibir compras (50114), y que un usuario inactivo no puede vender (50002).

### 7. Documentación por procedimiento

- [SP_RegistrarVenta](SP_RegistrarVenta.md)
- [SP_AnularVenta](SP_AnularVenta.md)
- [SP_AjustarStock](SP_AjustarStock.md)
- [SP_RegistrarCompra](SP_RegistrarCompra.md)
- [SP_RecibirCompra](SP_RecibirCompra.md)
