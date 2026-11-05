## Procedimiento Almacenado: SP_RegistrarCompra

**Descripción:**
Registra una compra de **una línea** (cabecera y detalle) en estado `PENDIENTE`, de forma transaccional. No mueve stock: el ingreso físico se produce al ejecutar `SP_RecibirCompra`.

**Parámetros:**
- `@IdProveedor` (INT, obligatorio): proveedor de la compra.
- `@IdUsuario` (INT, obligatorio): usuario activo que registra la compra.
- `@IdVariante` (INT, obligatorio): variante comprada.
- `@Cantidad` (INT, obligatorio): unidades compradas.
- `@CostoUnitario` (DECIMAL(12,2), obligatorio): costo por unidad.
- `@NroComprobante` (VARCHAR(30), opcional): número de factura o remito.

**Validaciones y errores:**
1. Cantidad menor o igual a cero: `PRINT` + `RETURN`.
2. Costo unitario negativo: `PRINT` + `RETURN`.
3. Proveedor inexistente: `PRINT` + `RETURN`.
4. Usuario inexistente o inactivo: `PRINT` + `RETURN`.
5. Usuario activo sin rol `Administrador`: `PRINT` + `RETURN`.
6. Variante inexistente: `PRINT` + `RETURN`.
7. Total calculado como `Cantidad * CostoUnitario`.
8. `IdCompra` se genera con `ISNULL(MAX(IdCompra), 0) + 1`, sin `UPDLOCK` ni `HOLDLOCK`. Dos compras concurrentes pueden obtener el mismo número y una fallará por la clave primaria.
9. `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` dentro de `TRY...CATCH`. No se usa `SET XACT_ABORT ON`.

Las validaciones no lanzan excepciones: imprimen el mensaje y terminan la ejecución sin resultset. Solo un error del motor (por ejemplo, una clave duplicada) llega al `CATCH` y se relanza con `THROW;`.

**Roles:** solo un usuario activo con rol de aplicación `Administrador` puede ejecutarlo. El SP valida esta regla internamente; además, el permiso de motor se concede a `rol_administrador`.

**Resultado:** devuelve `IdCompraGenerada`, `TotalCompra` y un mensaje de éxito.

**Compras de varias líneas:** el SP solo registra la primera línea con `NroLinea = 1`. Las líneas restantes se insertan directamente en `DetalleCompra` con `NroLinea` 2 en adelante y luego se recalcula `Compra.Total` con la suma de todas las líneas.

```sql
EXEC SP_RegistrarCompra
     @IdProveedor    = 1,
     @IdUsuario      = 1,
     @NroComprobante = 'A-0001-00001234',
     @IdVariante     = 1,
     @Cantidad       = 10,
     @CostoUnitario  = 8000;
```
