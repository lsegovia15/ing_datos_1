## Procedimiento Almacenado: SP_RegistrarCompra

**Descripción:**
Registra una compra completa (cabecera y detalle) en estado `PENDIENTE`, de forma transaccional. No mueve stock: el ingreso físico se produce al ejecutar `SP_RecibirCompra`.

**Tecnología utilizada:**
Usa un **Table-Valued Parameter (TVP)** (`TipoDetalleCompra`) para enviar todas las líneas de la compra en una sola llamada, manteniendo tipos de datos y evitando concatenación de strings.

**Parámetros:**
- `@IdProveedor` (INT, obligatorio): proveedor de la compra.
- `@IdUsuario` (INT, obligatorio): usuario activo que registra la compra.
- `@NroComprobante` (VARCHAR(30), opcional): número de factura o remito.
- `@Detalle` (TipoDetalleCompra READONLY, obligatorio): columnas `IdVariante`, `Cantidad`, `CostoUnitario`.

**Validaciones y errores:**
1. Detalle vacío: error `50100`.
2. Proveedor inexistente: error `50101`.
3. Usuario inexistente o inactivo: error `50102`.
4. Variante repetida: error `50103`.
5. Cantidad menor o igual a cero: error `50104`.
6. Costo negativo: error `50105`.
7. Variante inexistente: error `50106`.
8. Total calculado como `SUM(Cantidad * CostoUnitario)`; el trigger `TR_DetalleCompra_Control` vuelve a recalcularlo.
9. `IdCompra` se genera con `MAX + 1` y `WITH (UPDLOCK, HOLDLOCK)` para evitar duplicados concurrentes.
10. `BEGIN TRAN` / `COMMIT` / `ROLLBACK` y `SET XACT_ABORT ON`.

**Roles:** solo el `Administrador` puede ejecutarlo. El permiso de motor se concede a `rol_administrador` y se deniega a `rol_vendedor`.

**Resultado:** devuelve `IdCompraGenerada`, `TotalCompra` y un mensaje de éxito.
