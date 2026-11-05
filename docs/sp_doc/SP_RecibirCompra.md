## Procedimiento Almacenado: SP_RecibirCompra

**Descripción:**
Cambia una compra de `PENDIENTE` a `RECIBIDA`. El trigger `TR_SumarStockCompra` suma al stock la cantidad de cada línea.

**Parámetros:**
- `@IdCompra` (INT, obligatorio): compra a recibir.
- `@IdUsuario` (INT, obligatorio): usuario activo que recibe físicamente la mercadería.

**Flujo lógico y validaciones:**
1. Verifica que el usuario exista y esté activo; si no, error `50113`.
2. Verifica que el usuario activo tenga rol de aplicación `Administrador`; si no, error `50114`.
3. Inicia transacción y lee la compra con `WITH (UPDLOCK, HOLDLOCK)` para evitar recepciones concurrentes.
4. Compra inexistente: error `50110`.
5. Compra que no está `PENDIENTE`: error `50112`.
6. Compra sin líneas de detalle: error `50111`.
7. Guarda `@IdUsuario` en `SESSION_CONTEXT(N'IdUsuarioOperacion')` (ningún trigger lo lee actualmente).
8. Actualiza `Compra.Estado = 'RECIBIDA'` solo si sigue `PENDIENTE`; si otra sesión ganó la carrera, error `50112`.
9. Limpia el session context, hace `COMMIT` y devuelve `IdCompraRecibida` con un mensaje.

**Roles:** solo un usuario activo con rol de aplicación `Administrador` puede ejecutarlo. El SP valida esta regla internamente (error `50114`); además, el permiso de motor se concede a `rol_administrador` y se deniega a `rol_vendedor`.

**Trigger asociado:** `TR_SumarStockCompra` ingresa el stock cuando la compra pasa de `PENDIENTE` a `RECIBIDA`. Las validaciones (estado y líneas de detalle) las hace el SP.
