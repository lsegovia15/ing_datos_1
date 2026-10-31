## Procedimiento Almacenado: SP_RecibirCompra

**Descripción:**
Cambia una compra de `PENDIENTE` a `RECIBIDA`. El trigger `TR_Compra_CambioEstado` inserta los movimientos de `ENTRADA` y actualiza el stock de cada variante.

**Parámetros:**
- `@IdCompra` (INT, obligatorio): compra a recibir.
- `@IdUsuario` (INT, obligatorio): usuario activo que recibe físicamente la mercadería.

**Flujo lógico y validaciones:**
1. Verifica que el usuario exista y esté activo; si no, error `50113`.
2. Inicia transacción y lee la compra con `WITH (UPDLOCK, HOLDLOCK)` para evitar recepciones concurrentes.
3. Compra inexistente: error `50110`.
4. Compra que no está `PENDIENTE`: error `50112`.
5. Compra sin líneas de detalle: error `50111`.
6. Guarda `@IdUsuario` en `SESSION_CONTEXT(N'IdUsuarioOperacion')` para que el trigger registre la `ENTRADA` a nombre de quien recibe.
7. Actualiza `Compra.Estado = 'RECIBIDA'` solo si sigue `PENDIENTE`; si otra sesión ganó la carrera, error `50112`.
8. Limpia el session context, hace `COMMIT` y devuelve `IdCompraRecibida` con un mensaje.

**Roles:** solo el `Administrador` puede ejecutarlo. El permiso de motor se concede a `rol_administrador` y se deniega a `rol_vendedor`.

**Trigger asociado:** `TR_Compra_CambioEstado` valida la transición, exige líneas de detalle e ingresa el stock.
