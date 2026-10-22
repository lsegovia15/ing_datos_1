## Procedimiento Almacenado: SP_AnularVenta

**Descripción:** 
Anula una venta previamente registrada. Cambia el estado de la cabecera a 'ANULADA' y genera los movimientos de stock de tipo 'DEVOLUCION' para que el inventario vuelva a su estado anterior.

**Parámetros:**
- `@IdVenta` (INT, obligatorio): ID de la venta a anular.
- `@IdUsuario` (INT, obligatorio): ID del usuario que autoriza la anulación (para auditoría).

**Flujo Lógico y Control de Errores:**
1. **Validaciones (`TRY`):**
   - Verifica que la venta exista consultando su estado actual.
   - Verifica que la venta no esté ya 'ANULADA' (evita anulaciones duplicadas).
   - Verifica que el usuario que anula exista en el sistema.
2. **Transacción (`BEGIN TRAN`):**
   - Actualiza el campo `Estado` de la tabla `Venta` a 'ANULADA'.
   - Inserta en `MovimientoStock` un registro por cada línea de la venta original (`INSERT INTO ... SELECT FROM DetalleVenta`), pero con `TipoMovimiento = 'DEVOLUCION'`, copiando la `Cantidad` vendida.
   - Si todo está OK, hace `COMMIT`.
3. **Manejo de Errores (`CATCH`):**
   - Si algo falla, ejecuta `ROLLBACK TRANSACTION` y muestra el error con `RAISERROR`.

**Pruebas realizadas:**
- Anulación exitosa de la Venta #1. Se generaron los movimientos de devolución correspondientes (Variante 1: cant 2, Variante 2: cant 1).
- Intento de anulación duplicada: el SP aborta correctamente y no genera movimientos extra.