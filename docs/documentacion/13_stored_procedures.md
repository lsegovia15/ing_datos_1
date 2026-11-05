# 13. Stored Procedures

Scripts: `sql/sp/SP_RegistrarVenta.sql`, `sql/sp/SP_AnularVenta.sql`, `sql/sp/SP_AjustarStock.sql`, `sql/sp/SP_RegistrarCompra.sql`, `sql/sp/SP_RecibirCompra.sql`, `sql/cursores.sql`

Los stored procedures encapsulan las operaciones que modifican stock, ventas, compras y estados. Todos siguen la misma estructura:

1. `BEGIN TRY` y validaciones de parámetros, existencia de registros y rol del usuario.
2. Si una validación falla, se ejecuta `PRINT` con el mensaje y `RETURN`.
3. `BEGIN TRANSACTION` → inserciones o actualizaciones → `COMMIT`.
4. Un `SELECT` final con el resultado de la operación.
5. `BEGIN CATCH`: `ROLLBACK` si hay una transacción abierta y `THROW;` para relanzar el error original.

Los SPs no usan `SET NOCOUNT ON` ni `SET XACT_ABORT ON`. Las validaciones tampoco lanzan excepciones: un rechazo de negocio termina con un mensaje impreso, sin resultset y sin código de error. Por eso, quien llama debe comprobar el estado de los datos o los conteos después de ejecutar el SP.

Cada SP que registra una venta o una compra inserta **una sola línea** de detalle, siempre con `NroLinea = 1`. Para una operación de varias líneas se registra la primera con el SP y las restantes se insertan directamente sobre la misma cabecera; en ventas, los triggers descuentan el stock y recalculan el total, y en compras hay que recalcular `Compra.Total` a partir del detalle.

### Validación del rol dentro del SP

Además de los permisos `EXECUTE` de la [sección 18](18_seguridad.md), cada SP verifica que el `@IdUsuario` recibido esté activo y tenga el rol de aplicación adecuado:

| SP | Rol requerido |
|---|---|
| `SP_RegistrarVenta` | `Administrador` o `Vendedor` |
| `SP_AnularVenta` | `Administrador` |
| `SP_AjustarStock` | `Administrador` |
| `SP_RegistrarCompra` | `Administrador` |
| `SP_RecibirCompra` | `Administrador` |

Es una segunda barrera: aunque se concediera `EXECUTE` a otro rol del motor, la regla de negocio se sigue evaluando con la tabla `Usuario`.

---

## SP_RegistrarVenta

**Situación real:** el vendedor cobra una línea de una venta.

**Parámetros de entrada:**

| Parámetro | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `@IdCliente` | `INT` | No (`NULL`) | Cliente; `NULL` = consumidor final |
| `@IdUsuario` | `INT` | Sí | Vendedor que registra la venta |
| `@MedioPago` | `VARCHAR(20)` | Sí | `EFECTIVO`, `DEBITO`, `CREDITO` o `TRANSFERENCIA` |
| `@IdVariante` | `INT` | Sí | Variante vendida |
| `@Cantidad` | `INT` | Sí | Unidades vendidas |
| `@PrecioUnitario` | `DECIMAL(12,2)` | Sí | Precio de la unidad |
| `@Descuento` | `DECIMAL(12,2)` | No (`0`) | Descuento total de la línea, en pesos |

**Validaciones:**
- El usuario existe y está activo.
- El usuario tiene rol `Administrador` o `Vendedor` y está activo.
- El cliente, si se informa, existe.
- La variante existe.
- `StockActual` de la variante alcanza para la cantidad pedida.

No valida explícitamente que `@Cantidad` sea mayor a cero, que `@PrecioUnitario` no sea negativo, que el descuento no supere el importe de la línea ni que `@MedioPago` sea uno de los valores permitidos. Esas condiciones quedan a cargo de los `CHECK` de `DetalleVenta` y `Venta`.

**Procesamiento y modificación de datos:**
1. Calcula `Total = Cantidad * PrecioUnitario - Descuento`.
2. Genera `IdVenta` con `ISNULL(MAX(IdVenta), 0) + 1`, sin bloqueo.
3. Inserta la cabecera en `Venta` con estado `CONFIRMADA`.
4. Inserta la línea en `DetalleVenta` con `NroLinea = 1`. El trigger `TR_DescontarStockVenta` resta el stock y `TR_CalcularTotalVenta` recalcula el total de la venta.
5. Confirma la transacción y devuelve el resultado.

**Resultado:** `IdVentaGenerada`, `TotalVenta`, `Mensaje`.

**Ejemplo:**
```sql
EXEC SP_RegistrarVenta
     @IdCliente      = NULL,
     @IdUsuario      = 2,
     @MedioPago      = 'DEBITO',
     @IdVariante     = 1,
     @Cantidad       = 2,
     @PrecioUnitario = 15000,
     @Descuento      = 0;
```

Para registrar una segunda línea de la misma venta, se inserta directamente en `DetalleVenta` con `NroLinea = 2` (o el siguiente número) y el `IdVenta` devuelto. Los triggers de `DetalleVenta` vuelven a descontar stock y a recalcular el total.

---

## SP_AnularVenta

**Situación real:** un cliente devuelve la compra o la venta se cargó mal. La venta no se borra: se anula y se devuelve el stock.

**Parámetros de entrada:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@IdVenta` | `INT` | Venta a anular |
| `@IdUsuario` | `INT` | Usuario que autoriza la anulación |

**Validaciones:**
- El usuario existe.
- El usuario está activo y tiene rol `Administrador`.
- La venta existe.
- La venta no está ya `ANULADA`.
- La venta está en estado `CONFIRMADA`.

**Procesamiento y modificación de datos:**
1. Cambia `Venta.Estado` a `ANULADA`.
2. El trigger `TR_DevolverStockAnulacion` suma al stock la cantidad de cada línea de la venta.
3. Confirma la transacción y devuelve el resultado.

La anulación no genera movimientos en `MovimientoStock`. No hay bloqueo explícito ni una segunda comprobación de estado en el `UPDATE`; dos anulaciones simultáneas pueden ejecutarse, aunque el trigger solo devuelve stock cuando la fila pasa de `CONFIRMADA` a `ANULADA`.

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
- La nueva cantidad no es negativa.
- El usuario existe y está activo.
- El usuario tiene rol `Administrador` y está activo.
- La variante existe.

**Procesamiento y modificación de datos:**
1. Lee `StockActual` y calcula `Diferencia = NuevaCantidad - StockActual`.
2. Si la diferencia es 0, devuelve un mensaje sin abrir transacción y sin registrar nada.
3. Si no, genera `IdMovimiento` con `ISNULL(MAX(IdMovimiento), 0) + 1`, sin bloqueo.
4. Inserta un movimiento `AJUSTE` con la **diferencia con signo** (negativa si faltaba mercadería).
5. El trigger `TR_AplicarAjusteStock` aplica la diferencia sobre `StockActual`.
6. Confirma la transacción y devuelve el resultado.

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
| `@IdVariante` | `INT` | Sí | Variante comprada |
| `@Cantidad` | `INT` | Sí | Unidades compradas |
| `@CostoUnitario` | `DECIMAL(12,2)` | Sí | Costo por unidad |
| `@NroComprobante` | `VARCHAR(30)` | No (`NULL`) | Número de factura o remito del proveedor |

**Validaciones:**
- La cantidad es mayor a cero.
- El costo unitario no es negativo.
- El proveedor existe.
- El usuario existe y está activo.
- El usuario tiene rol `Administrador` y está activo.
- La variante existe.

**Procesamiento y modificación de datos:**
1. Calcula `Total = Cantidad * CostoUnitario`.
2. Genera `IdCompra` con `ISNULL(MAX(IdCompra), 0) + 1`, sin bloqueo.
3. Inserta la cabecera en `Compra` con estado `PENDIENTE`.
4. Inserta la línea en `DetalleCompra` con `NroLinea = 1`.
5. Confirma la transacción y devuelve el resultado.

El stock **no** cambia en este paso: la mercadería todavía no llegó.

**Resultado:** `IdCompraGenerada`, `TotalCompra`, `Mensaje`.

**Ejemplo:**
```sql
EXEC SP_RegistrarCompra
     @IdProveedor    = 1,
     @IdUsuario      = 1,
     @NroComprobante = 'A-0001-00001234',
     @IdVariante     = 1,
     @Cantidad       = 10,
     @CostoUnitario  = 8000;
```

Para agregar más líneas a la misma compra, se insertan directamente en `DetalleCompra` con `NroLinea` 2 en adelante y luego se recalcula `Compra.Total` con la suma de todas las líneas.

---

## SP_RecibirCompra

**Situación real:** llega la mercadería de una compra pendiente y se ingresa al stock.

**Parámetros de entrada:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@IdCompra` | `INT` | Compra que se recibe |
| `@IdUsuario` | `INT` | Usuario que recibe físicamente la mercadería |

**Validaciones:**
- El usuario existe y está activo.
- El usuario tiene rol `Administrador` y está activo.
- La compra existe.
- La compra está `PENDIENTE`.
- La compra tiene al menos una línea de detalle.

**Procesamiento y modificación de datos:**
1. Cambia `Compra.Estado` a `RECIBIDA`.
2. El trigger `TR_SumarStockCompra` suma al stock la cantidad de cada línea de la compra.
3. Confirma la transacción y devuelve el resultado.

La recepción no genera movimientos en `MovimientoStock` y no usa bloqueo explícito ni una segunda comprobación de estado en el `UPDATE`.

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

---

## Limitaciones de la implementación

- Los identificadores de `Venta`, `Compra` y `MovimientoStock` se generan con `MAX + 1` sin `UPDLOCK` ni `HOLDLOCK`. Dos operaciones concurrentes pueden obtener el mismo número y una de ellas fallará por la clave primaria.
- Las validaciones de negocio usan `PRINT` + `RETURN`, no `THROW`. El llamador no recibe un código de error y debe verificar si la operación se aplicó.
- Los SPs no relacionan `@IdUsuario` con el login de SQL Server que ejecuta la operación.
- Las ventas y compras de varias líneas se completan con inserciones directas sobre el detalle; el SP solo cubre la primera línea.
