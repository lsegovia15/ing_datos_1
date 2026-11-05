## Procedimiento Almacenado: SP_AjustarStock

**Descripción:**
Corrige el stock de una variante después de un recuento físico. Calcula la diferencia entre lo contado y el stock del sistema y la registra como movimiento `AJUSTE` en `MovimientoStock`. `TR_AplicarAjusteStock` aplica la diferencia a `StockActual`.

**Parámetros:**
- `@IdVariante` (INT): variante a ajustar.
- `@NuevaCantidad` (INT): cantidad contada.
- `@IdUsuario` (INT): usuario que ajusta.
- `@Observacion` (VARCHAR(200), opcional): motivo.

**Roles:** solo `Administrador` activo.

**Control de errores y validaciones:**
1. Cantidad nueva no negativa (50020).
2. Usuario existente y activo (50021) con rol `Administrador` (50023).
3. Variante existente (50022).
4. Si la diferencia es 0, informa que no hubo cambios y no registra movimiento.
5. `BEGIN TRANSACTION` / `COMMIT`: `IdMovimiento` con `MAX + 1`.
6. `TRY...CATCH` con `ROLLBACK` y `THROW;`.
