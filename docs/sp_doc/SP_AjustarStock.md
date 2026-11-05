## Procedimiento Almacenado: SP_AjustarStock

**Descripción:** 
Permite corregir manualmente el stock de una variante (por ejemplo, por rotura, robo o recuento de inventario). Calcula la diferencia entre el stock actual y el nuevo, y registra un movimiento de tipo 'AJUSTE'.

**Parámetros:**
- `@IdVariante` (INT, obligatorio): ID de la variante a ajustar.
- `@NuevaCantidad` (INT, obligatorio): El stock real (físico) contado.
- `@IdUsuario` (INT, obligatorio): ID del usuario que autoriza el ajuste.
- `@Observacion` (VARCHAR(200), opcional): Motivo del ajuste.

**Roles:** solo el `Administrador` puede ejecutarlo. El permiso de motor `EXECUTE` se concede a `rol_administrador` y se deniega explícitamente a `rol_vendedor`. Además, el SP valida internamente que el usuario esté activo y tenga rol `Administrador` (error `50023`).

**Flujo Lógico y Control de Errores:**
1. **Validaciones (`TRY`):**
   - Verifica que la nueva cantidad no sea negativa (error `50020`).
   - Verifica que el usuario exista y esté activo (error `50021`).
   - Verifica que el usuario tenga rol `Administrador` activo (error `50023`).
2. **Transacción (`BEGIN TRAN`):**
   - Genera el `IdMovimiento` y lee el `StockActual` de la variante con `WITH (UPDLOCK, HOLDLOCK)`, para que una venta concurrente no cambie el stock entre la lectura y el ajuste.
   - Verifica que la variante exista.
   - Calcula la diferencia (`Nueva - Actual`). Si es 0, hace `COMMIT` sin registrar nada y avisa.
   - Inserta un registro en `MovimientoStock` con `TipoMovimiento = 'AJUSTE'` y la **diferencia con signo** (negativa si faltaba stock).
   - El trigger `TR_AplicarAjusteStock` aplica la diferencia sobre `StockActual`.
   - Hace `COMMIT`.
3. **Manejo de Errores (`CATCH`):** `ROLLBACK` y `THROW;` para relanzar el error original.

**Pruebas realizadas:**
- Ajuste de stock de 10 a 7 (faltante de 3). Generó movimiento correcto.
- Intento de ajuste sin diferencia (mismo valor). No generó movimiento y avisó al usuario.
- Intento de ajuste a cantidad negativa. Arrojó error controlado.
- Intento de ajuste por un Vendedor. Arrojó el error `50023` sin registrar movimiento.