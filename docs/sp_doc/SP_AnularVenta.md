## Procedimiento Almacenado: SP_AnularVenta

**Descripción:**
Anula una venta `CONFIRMADA`. La venta no se borra: pasa a `ANULADA`, y `TR_DevolverStockAnulacion` devuelve el stock.

**Parámetros:**
- `@IdVenta` (INT): venta a anular.
- `@IdUsuario` (INT): usuario que anula.

**Roles:** solo `Administrador` activo. El permiso de motor `EXECUTE` se otorga solo a `rol_administrador`.

**Control de errores y validaciones:**
1. Usuario existente y activo (50012) y con rol `Administrador` (50013).
2. Venta existente (50010) y en estado `CONFIRMADA` (50011).
3. `BEGIN TRANSACTION` / `COMMIT` con `UPDATE ... WHERE Estado = 'CONFIRMADA'`.
4. `TRY...CATCH` con `ROLLBACK` y `THROW;`.
