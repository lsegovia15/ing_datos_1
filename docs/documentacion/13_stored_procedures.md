# 13. Stored Procedures

Scripts: `sql/sp/SP_RegistrarVenta.sql`, `sql/sp/SP_AnularVenta.sql`, `sql/sp/SP_AjustarStock.sql`, `sql/sp/SP_RegistrarCompra.sql`, `sql/sp/SP_RecibirCompra.sql`, `sql/cursores.sql`

Los stored procedures son la vía para las operaciones que mueven stock: ventas, anulaciones, ajustes y compras. Cada venta y cada compra corresponde a **un producto** (una variante). Todos siguen la misma estructura, la vista en la Clase X:

1. `SET NOCOUNT ON`.
2. `BEGIN TRY`.
3. Validaciones de parámetros, de existencia de registros y del rol del usuario. Si alguna falla, `THROW` con un código propio.
4. `BEGIN TRANSACTION` → modificaciones → `COMMIT TRANSACTION`.
5. Un `SELECT` final con el resultado de la operación.
6. `BEGIN CATCH`: `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION` y `THROW;` para devolver el error a quien llamó al SP.

Los números de venta, compra y movimiento se generan con `ISNULL(MAX(Id), 0) + 1` dentro de la transacción.

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

Aunque por error se le diera permiso de ejecución a otro rol del motor, la regla de negocio se sigue cumpliendo.

---

## SP_RegistrarVenta

**Situación real:** el vendedor cobra la venta de un producto.

**Parámetros de entrada:**

| Parámetro | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `@IdCliente` | `INT` | No (`NULL`) | Cliente; `NULL` = consumidor final |
| `@IdUsuario` | `INT` | Sí | Usuario que registra la venta |
| `@MedioPago` | `VARCHAR(20)` | Sí | `EFECTIVO`, `DEBITO`, `CREDITO` o `TRANSFERENCIA` |
| `@IdVariante` | `INT` | Sí | Variante que se vende |
| `@Cantidad` | `INT` | Sí | Unidades vendidas |
| `@Descuento` | `DECIMAL(12,2)` | No (0) | Descuento en pesos sobre el importe |

**Validaciones:**
- La cantidad es mayor a cero (50001).
- El usuario existe y está activo (50002), y tiene rol `Administrador` o `Vendedor` (50007).
- El cliente, si se informa, existe (50003).
- El medio de pago es uno de los permitidos (50004).
- La variante existe (50005).
- Hay stock suficiente (50006).
- El descuento no es negativo ni mayor al importe (50008).

**Procesamiento y modificación de datos:**
1. Toma el precio unitario de `VarianteProducto.PrecioVenta`. El vendedor no puede cargar otro precio.
2. Abre la transacción y genera `IdVenta` como `MAX + 1`.
3. Inserta la cabecera en `Venta` con estado `CONFIRMADA` y total 0.
4. Inserta la línea en `DetalleVenta`. Ese `INSERT` dispara `TR_DescontarStockVenta` (resta el stock) y `TR_CalcularTotalVenta` (calcula el total).
5. Confirma y devuelve `IdVentaGenerada`, `TotalVenta` y `Mensaje`.

**Ejemplo:**

```sql
EXEC dbo.SP_RegistrarVenta
     @IdCliente  = 1,
     @IdUsuario  = 2,
     @MedioPago  = 'EFECTIVO',
     @IdVariante = 1,
     @Cantidad   = 2;
```

---

## SP_AnularVenta

**Situación real:** el administrador anula una venta mal cargada o devuelta.

**Parámetros:** `@IdVenta INT`, `@IdUsuario INT`.

**Validaciones:**
- El usuario existe y está activo (50012), y es `Administrador` (50013).
- La venta existe (50010) y está `CONFIRMADA` (50011).

**Procesamiento:** en una transacción pasa la venta a `ANULADA` (`UPDATE ... WHERE Estado = 'CONFIRMADA'`). `TR_DevolverStockAnulacion` devuelve el stock de la venta. La venta no se borra: queda registrada como anulada.

```sql
EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 1;
```

---

## SP_AjustarStock

**Situación real:** después de un recuento físico, el stock del sistema no coincide con el real.

**Parámetros:** `@IdVariante INT`, `@NuevaCantidad INT` (lo contado), `@IdUsuario INT`, `@Observacion VARCHAR(200)` (opcional).

**Validaciones:**
- La cantidad nueva no es negativa (50020).
- El usuario existe y está activo (50021), y es `Administrador` (50023).
- La variante existe (50022).

**Procesamiento:**
1. Calcula `Diferencia = NuevaCantidad - StockActual`.
2. Si la diferencia es 0, informa que no hubo cambios y no registra nada.
3. Si no, inserta en `MovimientoStock` un movimiento `AJUSTE` con la diferencia (positiva o negativa). `TR_AplicarAjusteStock` la suma a `StockActual`.

Así cada corrección de stock queda registrada con fecha, usuario y motivo.

```sql
EXEC dbo.SP_AjustarStock @IdVariante = 1, @NuevaCantidad = 22,
     @IdUsuario = 1, @Observacion = 'Ajuste por recuento físico';
```

---

## SP_RegistrarCompra

**Situación real:** el administrador pide mercadería a un proveedor.

**Parámetros:**

| Parámetro | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `@IdProveedor` | `INT` | Sí | Proveedor |
| `@IdUsuario` | `INT` | Sí | Usuario que registra la compra |
| `@IdVariante` | `INT` | Sí | Variante comprada |
| `@Cantidad` | `INT` | Sí | Unidades |
| `@CostoUnitario` | `DECIMAL(12,2)` | Sí | Costo por unidad |
| `@NroComprobante` | `VARCHAR(30)` | No | Número de factura del proveedor |

**Validaciones:**
- El proveedor existe (50101).
- El usuario existe y está activo (50102), y es `Administrador` (50107).
- La cantidad es mayor a cero (50104) y el costo no es negativo (50105).
- La variante existe (50106).

**Procesamiento:** calcula `Total = Cantidad * CostoUnitario` y, en una transacción, inserta la cabecera en `Compra` con estado `PENDIENTE` y la línea en `DetalleCompra`. **No modifica el stock**: la mercadería entra cuando se recibe.

```sql
EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1,
     @IdVariante = 1, @Cantidad = 5, @CostoUnitario = 9000,
     @NroComprobante = 'FC-A-0001-00000001';
```

---

## SP_RecibirCompra

**Situación real:** llega la mercadería del proveedor.

**Parámetros:** `@IdCompra INT`, `@IdUsuario INT`.

**Validaciones:**
- El usuario existe y está activo (50113), y es `Administrador` (50114).
- La compra existe (50110), está `PENDIENTE` (50112) y tiene al menos una línea (50111).

**Procesamiento:** en una transacción pasa la compra a `RECIBIDA`. `TR_SumarStockCompra` suma las unidades al stock.

```sql
EXEC dbo.SP_RecibirCompra @IdCompra = 1, @IdUsuario = 1;
```

---

## SP_InformeReposicionStock

Usa un cursor. Está documentado en la [sección 15](15_cursores.md).
