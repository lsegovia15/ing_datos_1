## Procedimiento Almacenado: SP_RecibirCompra

**Descripción:**
Cambia una compra de `PENDIENTE` a `RECIBIDA`. El trigger `TR_SumarStockCompra` suma al stock la cantidad de cada línea.

**Parámetros:**
- `@IdCompra` (INT, obligatorio): compra a recibir.
- `@IdUsuario` (INT, obligatorio): usuario activo que recibe físicamente la mercadería.

**Flujo lógico y validaciones:**
1. Verifica que el usuario exista y esté activo; si no, `PRINT` + `RETURN`.
2. Verifica que el usuario activo tenga rol de aplicación `Administrador`; si no, `PRINT` + `RETURN`.
3. Lee la compra y obtiene `Estado`. Si la compra no existe, `PRINT` + `RETURN`.
4. Si la compra no está `PENDIENTE`, `PRINT` + `RETURN`.
5. Si la compra no tiene líneas de detalle, `PRINT` + `RETURN`.
6. Inicia transacción y actualiza `Compra.Estado = 'RECIBIDA'`.
7. El trigger `TR_SumarStockCompra` suma el stock cuando la fila pasa de `PENDIENTE` a `RECIBIDA`. No se generan movimientos en `MovimientoStock`.
8. Hace `COMMIT` y devuelve `IdCompraRecibida` con un mensaje.

No hay bloqueo explícito (`UPDLOCK`/`HOLDLOCK`) ni una segunda comprobación de estado dentro del `UPDATE`. Dos recepciones simultáneas pueden pasar las validaciones, pero el trigger solo suma stock en la transición `PENDIENTE` → `RECIBIDA`.

**Roles:** solo un usuario activo con rol de aplicación `Administrador` puede ejecutarlo. El SP valida esta regla internamente; además, el permiso de motor se concede a `rol_administrador`.

**Trigger asociado:** `TR_SumarStockCompra` ingresa el stock cuando la compra pasa de `PENDIENTE` a `RECIBIDA`. Las validaciones (estado y líneas de detalle) las hace el SP.

```sql
EXEC SP_RecibirCompra @IdCompra = 3, @IdUsuario = 1;
```
