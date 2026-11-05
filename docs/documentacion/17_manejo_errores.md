# 17. Manejo de errores

El manejo de errores se reparte en tres niveles. Cada nivel atrapa lo que el anterior no puede ver:

| Nivel | Mecanismo | Qué controla |
|---|---|---|
| 1. Estructura | Restricciones `PK`, `FK`, `UNIQUE`, `CHECK`, `NOT NULL` | Datos inválidos en cualquier `INSERT`/`UPDATE`, venga de donde venga |
| 2. Reglas de negocio | Triggers | Mantener stock y totales sincronizados; `TR_DescontarStockVenta` corta la venta si no hay stock |
| 3. Operaciones | Stored procedures con `TRY...CATCH` y transacciones | Parámetros incorrectos, registros inexistentes y mensajes claros para el usuario |

## Patrón usado en los stored procedures

```sql
BEGIN TRY
    SET XACT_ABORT ON;

    -- Validaciones: errores de negocio con código propio
    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario)
        THROW 50002, 'El usuario que registra la venta no existe.', 1;

    BEGIN TRANSACTION;
        -- modificaciones
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;   -- relanza el error original
END CATCH
```

- **`THROW` en las validaciones:** corta la ejecución con un número y un mensaje propios.
- **`SET XACT_ABORT ON`:** ante cualquier error en tiempo de ejecución, SQL Server marca la transacción para revertirla completa. Así no queda una venta con cabecera pero sin detalle.
- **`IF @@TRANCOUNT > 0 ROLLBACK`:** revierte solo si hay una transacción abierta (un error de validación ocurre antes de abrirla).
- **`THROW;` sin parámetros en el `CATCH`:** relanza el error **original** conservando número, mensaje y línea. Se eligió en lugar de `RAISERROR` porque `RAISERROR` genera un error nuevo y pierde el número original.
- **Limpieza de estado:** `SP_RegistrarVenta`, `SP_AnularVenta` y `SP_RecibirCompra` limpian el contexto de sesión en el `CATCH`, porque no se revierte con el `ROLLBACK`. `SP_InformeReposicionStock` cierra y libera el cursor en el `CATCH`.

## Errores dentro de transacciones

Los triggers corren dentro de la transacción de la sentencia que los dispara. Si un trigger lanza `THROW` (hoy solo `TR_DescontarStockVenta`), se revierte **todo**: la cabecera de la venta y sus líneas. Ejemplo: si al registrar una venta la segunda línea no tiene stock, no queda registrada ni la cabecera ni la primera línea.

## Concurrencia

Dos usuarios operando al mismo tiempo pueden generar errores aunque cada operación sea válida por separado. Se previenen así:

| Riesgo | Prevención |
|---|---|
| Dos ventas obtienen el mismo `IdVenta` | `MAX(IdVenta) + 1` leído con `WITH (UPDLOCK, HOLDLOCK)` dentro de la transacción |
| Dos movimientos obtienen el mismo `IdMovimiento` | Igual, en `SP_AjustarStock` |
| Vender la última unidad dos veces | `TR_DescontarStockVenta` valida dentro de la transacción, y el `CHECK (StockActual >= 0)` es la última barrera |
| Un ajuste calculado sobre un stock que cambió | `SP_AjustarStock` lee el stock bloqueado dentro de la transacción |
| Dos compras obtienen el mismo `IdCompra` | `SP_RegistrarCompra` usa `MAX + 1` con `WITH (UPDLOCK, HOLDLOCK)` |
| Anular una venta o recibir una compra dos veces a la vez | El SP lee el estado con bloqueo y el `UPDATE` vuelve a exigir el estado anterior (`CONFIRMADA` o `PENDIENTE`); si no afecta filas, lanza 50011 o 50112 |


## Situaciones de error contempladas

| Tipo de error (enunciado) | Ejemplo en el sistema | Mecanismo | Código |
|---|---|---|---|
| Datos inválidos | Precio negativo, medio de pago inexistente, cantidad 0 | `CHECK` | 547 (motor) |
| Datos inválidos | Ajustar stock a una cantidad negativa | SP | 50020 |
| Violaciones de restricciones | SKU, DNI, CUIT o email duplicado | `UNIQUE` | 2627 (motor) |
| Violaciones de restricciones | Venta con un cliente o variante inexistente (sin pasar por el SP) | `FK` | 547 (motor) |
| Registros inexistentes | Venta, compra, usuario, cliente, proveedor o variante que no existe | SP | 50002, 50003, 50005, 50010, 50012, 50021, 50022, 50101, 50102, 50106, 50110, 50113 |
| Parámetros incorrectos | Venta o compra vacía, variante repetida, cantidad o costo inválido | SP | 50001, 50004, 50100, 50103, 50104, 50105 |
| Permisos insuficientes | Un vendedor intenta anular, ajustar stock o registrar o recibir compras | SP | 50007, 50013, 50023, 50107, 50114 |
| Permisos insuficientes | Acceso directo a tablas o SPs no permitidos para el rol del motor | `DENY` | 229, 230 (motor) |
| Operaciones no permitidas | Anular una venta ya anulada | SP | 50011 |
| Operaciones no permitidas | Vender sin stock | SP / trigger | 50006, 50001 (trigger) |
| Operaciones no permitidas | Recibir una compra vacía o que no está pendiente | SP | 50111, 50112 |
| Operaciones no permitidas | Borrar una venta | Trigger `INSTEAD OF` (sin error, no borra) y `DENY DELETE` (229) | — |
| Errores durante transacciones | Falla a mitad de una venta | `XACT_ABORT` + `ROLLBACK` | — |

## Catálogo de códigos propios

Los rangos están separados para identificar de inmediato el origen del error:

| Rango | Origen |
|---|---|
| 50001 – 50099 | Stored procedures de ventas y stock |
| 50100 – 50199 | Stored procedures de compras |

| Código | Origen | Mensaje |
|---|---|---|
| 50001 | `SP_RegistrarVenta` | El detalle de la venta está vacío. |
| 50002 | `SP_RegistrarVenta` | El usuario que registra la venta no existe o está inactivo. |
| 50003 | `SP_RegistrarVenta` | El cliente especificado no existe. |
| 50004 | `SP_RegistrarVenta` | No se puede repetir la misma variante en la misma venta. |
| 50005 | `SP_RegistrarVenta` | Una o más variantes especificadas no existen. |
| 50006 | `SP_RegistrarVenta` | Stock insuficiente para la variante: *SKU*. Solicitado: *n*. Disponible: *m* |
| 50007 | `SP_RegistrarVenta` | El usuario debe estar activo y tener rol Administrador o Vendedor para registrar ventas. |
| 50010 | `SP_AnularVenta` | La venta especificada no existe. |
| 50011 | `SP_AnularVenta` | La venta ya se encuentra anulada (o no está en un estado que permita anularla). |
| 50012 | `SP_AnularVenta` | El usuario que anula la venta no existe. |
| 50013 | `SP_AnularVenta` | Solo un usuario Administrador activo puede anular ventas. |
| 50020 | `SP_AjustarStock` | La nueva cantidad de stock no puede ser negativa. |
| 50021 | `SP_AjustarStock` | El usuario que realiza el ajuste no existe o está inactivo. |
| 50022 | `SP_AjustarStock` | La variante especificada no existe. |
| 50023 | `SP_AjustarStock` | Solo un usuario Administrador activo puede ajustar stock. |
| 50100 | `SP_RegistrarCompra` | El detalle de la compra está vacío. |
| 50101 | `SP_RegistrarCompra` | El proveedor especificado no existe. |
| 50102 | `SP_RegistrarCompra` | El usuario que registra la compra no existe o está inactivo. |
| 50103 | `SP_RegistrarCompra` | No se puede repetir la misma variante en la misma compra. |
| 50104 | `SP_RegistrarCompra` | Todas las cantidades deben ser mayores a cero. |
| 50105 | `SP_RegistrarCompra` | El costo unitario no puede ser negativo. |
| 50106 | `SP_RegistrarCompra` | Una o más variantes especificadas no existen. |
| 50107 | `SP_RegistrarCompra` | Solo un usuario Administrador activo puede registrar compras. |
| 50110 | `SP_RecibirCompra` | La compra especificada no existe. |
| 50111 | `SP_RecibirCompra` | No se puede recibir una compra sin líneas de detalle. |
| 50112 | `SP_RecibirCompra` | Solo una compra en estado PENDIENTE puede recibirse. |
| 50113 | `SP_RecibirCompra` | El usuario que recibe la compra no existe o está inactivo. |
| 50114 | `SP_RecibirCompra` | Solo un usuario Administrador activo puede recibir compras. |

El único trigger que lanza un error propio es `TR_DescontarStockVenta`: usa el 50001 con el mensaje "No hay stock suficiente para realizar la venta.". El mismo número lo usa `SP_RegistrarVenta` para "El detalle de la venta está vacío.", así que conviene mirar el mensaje para distinguirlos.

## Ejemplo: capturar un error desde quien llama

```sql
BEGIN TRY
    EXEC SP_AnularVenta @IdVenta = 15, @IdUsuario = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS Codigo,   -- ej. 50011
           ERROR_MESSAGE() AS Mensaje;  -- ej. 'La venta ya se encuentra anulada.'
END CATCH;
```
