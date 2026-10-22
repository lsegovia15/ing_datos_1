## Procedimiento Almacenado: SP_AjustarStock

**Descripción:** 
Permite corregir manualmente el stock de una variante (por ejemplo, por rotura, robo o recuento de inventario). Calcula la diferencia entre el stock actual y el nuevo, y registra un movimiento de tipo 'AJUSTE'.

**Parámetros:**
- `@IdVariante` (INT, obligatorio): ID de la variante a ajustar.
- `@NuevaCantidad` (INT, obligatorio): El stock real (físico) contado.
- `@IdUsuario` (INT, obligatorio): ID del usuario que autoriza el ajuste.
- `@Observacion` (VARCHAR(200), opcional): Motivo del ajuste.

**Flujo Lógico y Control de Errores:**
1. **Validaciones (`TRY`):**
   - Verifica que la nueva cantidad no sea negativa.
   - Verifica que el usuario y la variante existan.
   - Verifica que la cantidad actual sea distinta a la nueva (si es igual, aborta y avisa).
2. **Transacción (`BEGIN TRAN`):**
   - Calcula la diferencia (`Nueva - Actual`).
   - Inserta un registro en `MovimientoStock` con `TipoMovimiento = 'AJUSTE'` y la cantidad en valor absoluto (`ABS()`).
   - Hace `COMMIT`.
3. **Manejo de Errores (`CATCH`):** `ROLLBACK` y `RAISERROR` estándar.

**Pruebas realizadas:**
- Ajuste de stock de 10 a 7 (faltante de 3). Generó movimiento correcto.
- Intento de ajuste sin diferencia (mismo valor). No generó movimiento y avisó al usuario.
- Intento de ajuste a cantidad negativa. Arrojó error controlado.