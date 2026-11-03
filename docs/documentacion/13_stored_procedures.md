# 13. Stored Procedures

Scripts: `sql/sp/SP_RegistrarVenta.sql`, `sql/sp/SP_AnularVenta.sql`, `sql/sp/SP_AjustarStock.sql`, `sql/sp/SP_RegistrarCompra.sql`, `sql/sp/SP_RecibirCompra.sql`, `sql/cursores.sql`

Los stored procedures son la vía para todas las operaciones que mueven stock: ventas, anulaciones, ajustes y compras. Todos siguen la misma estructura:

1. `SET NOCOUNT ON` y `SET XACT_ABORT ON`.
2. Validaciones de parámetros, de existencia de registros y del rol del usuario, que lanzan `THROW` con un código propio.
3. `BEGIN TRANSACTION` → modificaciones → `COMMIT`.
4. `BEGIN CATCH`: `ROLLBACK` si hay una transacción abierta y `THROW;` para relanzar el error original.
5. Un `SELECT` final con el resultado de la operación.

El detalle de los códigos de error está en [17_manejo_errores.md](17_manejo_errores.md).

### Validación del rol dentro del SP

Además de los permisos `EXECUTE` de la [sección 18](18_seguridad.md), cada SP verifica que el `@IdUsuario` recibido esté activo y tenga el rol de aplicación adecuado:

| SP | Rol requerido | Código |
|---|---|---|
| `SP_RegistrarVenta` | `Administrador` o `Vendedor` | 50007 |
| `SP_AnularVenta` | `Administrador` | 50013 |
| `SP_AjustarStock` | `Administrador` | 50023 |
| `SP_RegistrarCompra` | `Administrador` | 50107 |
| `SP_RecibirCompra` | `Administrador` | 50114 |

Es defensa en profundidad: aunque por error se le diera permiso de ejecución a otro rol del motor, la regla de negocio se sigue cumpliendo.

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
- El usuario existe y está activo (50002), y tiene rol `Administrador` o `Vendedor` (50007).
- El cliente, si se informa, existe (50003).
- No se repite la misma variante en el carrito (50004).
- Todas las variantes existen (50005).
- Hay stock suficiente para cada línea (50006). El mensaje indica el SKU, la cantidad pedida y la disponible.

**Procesamiento y modificación de datos:**
1. Calcula el total: `SUM(Cantidad * PrecioUnitario - Descuento)`.
2. Genera `IdVenta` como `MAX + 1` con `WITH (UPDLOCK, HOLDLOCK)`, para que dos ventas simultáneas no obtengan el mismo número.
3. Inserta la cabecera en `Venta` con estado `CONFIRMADA`.
4. Marca la sesión con `sp_set_session_context` (clave `PermitirDetalleVenta`) e inserta las líneas en `DetalleVenta`. El trigger `TR_DetalleVenta_Insert` solo acepta líneas que llegan con esa marca, así que no se pueden cargar ventas por fuera del SP. El trigger genera los movimientos `SALIDA`, que a su vez descuentan el stock.
5. Limpia la marca de la sesión, tanto al terminar como en el `CATCH`.

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
- El usuario existe (50012) y es un `Administrador` activo (50013).
- La venta existe (50010).
- La venta no está ya anulada (50011). La venta se lee con bloqueo y el `UPDATE` vuelve a exigir `Estado = 'CONFIRMADA'`, así que dos anulaciones simultáneas no devuelven el stock dos veces.

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
- El usuario existe y está activo (50021), y es `Administrador` (50023).
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

## SP_RegistrarCompra

**Situación real:** el administrador hace un pedido a un proveedor. La compra queda pendiente hasta que llega la mercadería.

**Parámetros de entrada:**

| Parámetro | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `@IdProveedor` | `INT` | Sí | Proveedor al que se compra |
| `@IdUsuario` | `INT` | Sí | Administrador que registra la compra |
| `@NroComprobante` | `VARCHAR(30)` | No (`NULL`) | Número de factura o remito del proveedor |
| `@Detalle` | `TipoDetalleCompra READONLY` | Sí | Líneas de la compra: `IdVariante`, `Cantidad`, `CostoUnitario` |

**Validaciones:**
- El detalle no está vacío (50100).
- El proveedor existe (50101).
- El usuario existe y está activo (50102), y es `Administrador` (50107).
- No se repite la misma variante (50103).
- Las cantidades son mayores a cero (50104) y los costos no son negativos (50105).
- Todas las variantes existen (50106).

**Procesamiento y modificación de datos:**
1. Calcula el total: `SUM(Cantidad * CostoUnitario)`.
2. Genera `IdCompra` como `MAX + 1` con `WITH (UPDLOCK, HOLDLOCK)`.
3. Inserta la cabecera en `Compra` con estado `PENDIENTE`.
4. Inserta las líneas en `DetalleCompra`, numeradas con `ROW_NUMBER()`. El trigger `TR_DetalleCompra_Control` recalcula el total.

El stock **no** cambia en este paso: la mercadería todavía no llegó.

**Resultado:** `IdCompraGenerada`, `TotalCompra`, `Mensaje`.

**Ejemplo:**
```sql
DECLARE @Detalle TipoDetalleCompra;
INSERT INTO @Detalle (IdVariante, Cantidad, CostoUnitario)
VALUES (1, 10, 8000),
       (2, 5, 8000);

EXEC SP_RegistrarCompra
     @IdProveedor    = 1,
     @IdUsuario      = 1,
     @NroComprobante = 'A-0001-00001234',
     @Detalle        = @Detalle;
```

---

## SP_RecibirCompra

**Situación real:** llega la mercadería de una compra pendiente y se ingresa al stock.

**Parámetros de entrada:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@IdCompra` | `INT` | Compra que se recibe |
| `@IdUsuario` | `INT` | Usuario que recibe físicamente la mercadería |

**Validaciones:**
- El usuario existe y está activo (50113), y es `Administrador` (50114).
- La compra existe (50110).
- La compra está `PENDIENTE` (50112).
- La compra tiene líneas (50111).

**Procesamiento y modificación de datos:**
1. Lee el estado de la compra con `WITH (UPDLOCK, HOLDLOCK)`, para que dos recepciones simultáneas no ingresen el stock dos veces.
2. Guarda `@IdUsuario` en el contexto de sesión (clave `IdUsuarioOperacion`).
3. Cambia `Compra.Estado` a `RECIBIDA`. El `UPDATE` vuelve a exigir `Estado = 'PENDIENTE'`; si no afectó filas, lanza 50112.
4. El trigger `TR_Compra_CambioEstado` inserta un movimiento `ENTRADA` por cada línea, a nombre de quien recibe.
5. Limpia el contexto de sesión, también en el `CATCH`.

**Resultado:** `IdCompraRecibida`, `Mensaje`.

**Ejemplo:**
```sql
EXEC SP_RecibirCompra @IdCompra = 3, @IdUsuario = 1;
```

---

## SP_InformeReposicionStock

Es un procedimiento de consulta: no recibe parámetros ni modifica datos. Recorre con un cursor las variantes con stock bajo y calcula cuánto reponer de cada una. Está documentado en [15_cursores.md](15_cursores.md).

```sql
EXEC SP_InformeReposicionStock;
```
