## Procedimiento Almacenado: SP_AjustarStock

**Descripción:**
Permite corregir manualmente el stock de una variante (por ejemplo, por rotura, robo o recuento de inventario). Calcula la diferencia entre el stock actual y el nuevo, y registra un movimiento de tipo `AJUSTE`.

**Parámetros:**
- `@IdVariante` (INT, obligatorio): ID de la variante a ajustar.
- `@NuevaCantidad` (INT, obligatorio): el stock real (físico) contado.
- `@IdUsuario` (INT, obligatorio): ID del usuario que autoriza el ajuste.
- `@Observacion` (VARCHAR(200), opcional): motivo del ajuste (por defecto `'Ajuste manual de inventario'`).

**Roles:** solo el `Administrador` puede ejecutarlo. El permiso de motor `EXECUTE` se concede a `rol_administrador`. Además, el SP valida internamente que el usuario esté activo y tenga rol `Administrador`.

**Flujo lógico y control de errores:**
1. **Validaciones (`TRY`):**
   - Verifica que la nueva cantidad no sea negativa. Si lo es, `PRINT` + `RETURN`.
   - Verifica que el usuario exista y esté activo. Si no, `PRINT` + `RETURN`.
   - Verifica que el usuario tenga rol `Administrador` activo. Si no, `PRINT` + `RETURN`.
   - Verifica que la variante exista y captura `StockActual`. Si no existe, `PRINT` + `RETURN`.
2. **Cálculo:** `Diferencia = NuevaCantidad - StockActual`.
   - Si la diferencia es 0, devuelve un mensaje sin abrir transacción y sin registrar nada.
3. **Transacción (`BEGIN TRANSACTION`):**
   - Genera `IdMovimiento` con `ISNULL(MAX(IdMovimiento), 0) + 1`, sin `UPDLOCK` ni `HOLDLOCK`.
   - Inserta un registro en `MovimientoStock` con `TipoMovimiento = 'AJUSTE'` y la **diferencia con signo** (negativa si faltaba stock).
   - El trigger `TR_AplicarAjusteStock` aplica la diferencia sobre `StockActual`.
   - Hace `COMMIT`.
4. **Manejo de errores (`CATCH`):** `ROLLBACK` y `THROW;` para relanzar el error original.

No hay bloqueo explícito entre la lectura de `StockActual` y la inserción del movimiento: una venta concurrente puede modificar el stock en ese intervalo.

**Resultado:** `IdVariante`, `StockAnterior`, `StockNuevo`, `Diferencia`, `Mensaje`.

```sql
-- El sistema dice 10, pero se contaron 7
EXEC SP_AjustarStock
     @IdVariante    = 3,
     @NuevaCantidad = 7,
     @IdUsuario     = 1,
     @Observacion   = 'Recuento mensual: faltante';
```
