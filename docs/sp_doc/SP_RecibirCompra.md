## Procedimiento Almacenado: SP_RecibirCompra

**Descripción:**
Marca una compra `PENDIENTE` como `RECIBIDA`. `TR_SumarStockCompra` suma las unidades al stock.

**Parámetros:**
- `@IdCompra` (INT): compra a recibir.
- `@IdUsuario` (INT): usuario que recibe.

**Roles:** solo `Administrador` activo.

**Control de errores y validaciones:**
1. Usuario existente y activo (50113) con rol `Administrador` (50114).
2. Compra existente (50110), en estado `PENDIENTE` (50112) y con al menos una línea (50111).
3. `BEGIN TRANSACTION` / `COMMIT` con `UPDATE ... WHERE Estado = 'PENDIENTE'`.
4. `TRY...CATCH` con `ROLLBACK` y `THROW;`.
