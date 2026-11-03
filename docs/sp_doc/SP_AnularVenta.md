## Procedimiento Almacenado: SP_AnularVenta

**Descripción:** 
Anula una venta previamente registrada. Cambia el estado de la cabecera a 'ANULADA'; el trigger `TR_Venta_CambioEstado` genera los movimientos de stock de tipo 'DEVOLUCION' para que el inventario vuelva a su estado anterior.

**Regla de negocio:** solo un usuario activo con rol de aplicación `Administrador` puede anular ventas. Un `Vendedor` puede registrar ventas, pero no anularlas (error 50013). Además, el permiso de motor `EXECUTE` se concede únicamente a `rol_administrador`.

**Parámetros:**
- `@IdVenta` (INT, obligatorio): ID de la venta a anular.
- `@IdUsuario` (INT, obligatorio): ID del usuario que autoriza la anulación (para auditoría).

**Flujo Lógico y Control de Errores:**
1. **Validaciones (`TRY`):**
   - Verifica que el usuario que anula exista en el sistema.
   - Verifica que el usuario esté activo y que su `Rol.Nombre` sea `Administrador` (error 50013 si no).
   - Dentro de la transacción, lee la venta con `WITH (UPDLOCK, HOLDLOCK)`.
   - Verifica que la venta exista y que no esté ya 'ANULADA' (evita anulaciones duplicadas).
2. **Transacción (`BEGIN TRAN`):**
   - Guarda `@IdUsuario` en el session context (`IdUsuarioOperacion`) para que el trigger sepa quién anula.
   - Actualiza el campo `Estado` de la tabla `Venta` a 'ANULADA' solo si sigue en 'CONFIRMADA'; si otra sesión ganó la carrera, lanza error 50011.
   - El trigger `TR_Venta_CambioEstado` inserta en `MovimientoStock` un registro `DEVOLUCION` por cada línea de la venta, a nombre del usuario que anula, y eso devuelve el stock.
   - Limpia el session context y hace `COMMIT`.
3. **Manejo de Errores (`CATCH`):**
   - Si algo falla, ejecuta `ROLLBACK TRANSACTION`, limpia el session context y relanza el error con `THROW;`.

**Pruebas realizadas:**
- Anulación exitosa de la Venta #1. Se generaron los movimientos de devolución correspondientes (Variante 1: cant 2, Variante 2: cant 1).
- Intento de anulación duplicada: el SP aborta correctamente y no genera movimientos extra.