## Procedimiento Almacenado: SP_RegistrarCompra

**Descripción:**
Registra la compra de un producto (una variante) a un proveedor: cabecera en `Compra` con estado `PENDIENTE` y una línea en `DetalleCompra`. No modifica el stock; la mercadería entra al recibir la compra con `SP_RecibirCompra`.

**Parámetros:**
- `@IdProveedor` (INT): proveedor.
- `@IdUsuario` (INT): usuario que registra.
- `@IdVariante` (INT): variante comprada.
- `@Cantidad` (INT): unidades.
- `@CostoUnitario` (DECIMAL(12,2)): costo por unidad.
- `@NroComprobante` (VARCHAR(30), opcional): factura del proveedor.

**Roles:** solo `Administrador` activo.

**Control de errores y validaciones:**
1. Proveedor existente (50101).
2. Usuario existente y activo (50102) con rol `Administrador` (50107).
3. Cantidad mayor a cero (50104) y costo no negativo (50105).
4. Variante existente (50106).
5. `Total = Cantidad * CostoUnitario`. `BEGIN TRANSACTION` / `COMMIT`: `IdCompra` con `MAX + 1`, cabecera y detalle juntos.
6. `TRY...CATCH` con `ROLLBACK` y `THROW;`.
