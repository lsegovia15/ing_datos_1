## Procedimiento Almacenado: SP_AnularVenta

**Descripción:**
Anula una venta previamente registrada. Cambia el estado de la cabecera a `ANULADA`; el trigger `TR_DevolverStockAnulacion` suma al stock la cantidad de cada línea para que el inventario vuelva a su estado anterior.

**Regla de negocio:** solo un usuario activo con rol de aplicación `Administrador` puede anular ventas. Un `Vendedor` puede registrar ventas, pero no anularlas. Además, el permiso de motor `EXECUTE` se concede únicamente a `rol_administrador`.

**Parámetros:**
- `@IdVenta` (INT, obligatorio): ID de la venta a anular.
- `@IdUsuario` (INT, obligatorio): ID del usuario que autoriza la anulación.

**Flujo lógico y control de errores:**
1. **Validaciones (`TRY`):**
   - Verifica que el usuario que anula exista. Si no, `PRINT` + `RETURN`.
   - Verifica que el usuario esté activo y que su `Rol.Nombre` sea `Administrador`. Si no, `PRINT` + `RETURN`.
   - Lee la venta y obtiene `Estado`. Si la venta no existe, `PRINT` + `RETURN`.
   - Si la venta ya está `ANULADA`, `PRINT` + `RETURN`.
   - Si la venta no está `CONFIRMADA`, `PRINT` + `RETURN`.
2. **Transacción (`BEGIN TRANSACTION`):**
   - Actualiza `Venta.Estado` a `ANULADA`.
   - El trigger `TR_DevolverStockAnulacion` suma al stock la cantidad de cada línea cuando la fila pasa de `CONFIRMADA` a `ANULADA`. No se generan movimientos en `MovimientoStock`.
   - Hace `COMMIT`.
3. **Manejo de errores (`CATCH`):** si algo falla, `ROLLBACK` y `THROW;`.

No hay bloqueo explícito (`UPDLOCK`/`HOLDLOCK`) ni una segunda comprobación de estado dentro del `UPDATE`. Dos anulaciones simultáneas pueden pasar las validaciones, pero el trigger solo devuelve stock en la transición `CONFIRMADA` → `ANULADA`.

**Resultado:** `IdVentaAnulada`, `Mensaje`.

```sql
EXEC SP_AnularVenta @IdVenta = 15, @IdUsuario = 1;
```
