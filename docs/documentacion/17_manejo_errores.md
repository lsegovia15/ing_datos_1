# 17. Manejo de errores

El manejo de errores se reparte en tres niveles. Cada nivel atrapa lo que el anterior no puede ver:

| Nivel | Mecanismo | Qué controla |
|---|---|---|
| 1. Estructura | Restricciones `PK`, `FK`, `UNIQUE`, `CHECK`, `NOT NULL` | Datos inválidos en cualquier `INSERT`/`UPDATE`, venga de donde venga |
| 2. Reglas de negocio | Triggers con `THROW` | Reglas que involucran varias tablas o el estado anterior de un registro |
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
- **Limpieza de estado:** `SP_AnularVenta` limpia el contexto de sesión en el `CATCH`, porque no se revierte con el `ROLLBACK`. `SP_InformeReposicionStock` cierra y libera el cursor en el `CATCH`.

## Errores dentro de transacciones

Los triggers corren dentro de la transacción de la sentencia que los dispara. Si un trigger lanza `THROW`, se revierte **todo**: la venta, su detalle y los movimientos ya generados. Ejemplo: si al registrar una venta la segunda línea no tiene stock, no queda registrada ni la cabecera ni la primera línea.

## Concurrencia

Dos usuarios operando al mismo tiempo pueden generar errores aunque cada operación sea válida por separado. Se previenen así:

| Riesgo | Prevención |
|---|---|
| Dos ventas obtienen el mismo `IdVenta` | `MAX(IdVenta) + 1` leído con `WITH (UPDLOCK, HOLDLOCK)` dentro de la transacción |
| Dos movimientos obtienen el mismo `IdMovimiento` | Igual, en `SP_AjustarStock` y en los triggers que insertan movimientos |
| Vender la última unidad dos veces | El trigger `TR_MovimientoStock_AplicarStock` valida dentro de la transacción, y el `CHECK (StockActual >= 0)` es la última barrera |
| Un ajuste calculado sobre un stock que cambió | `SP_AjustarStock` lee el stock bloqueado dentro de la transacción |
| Deadlocks | Todos los caminos bloquean en el mismo orden: `Venta` → `MovimientoStock` → `VarianteProducto` |

Se verificó con cuatro sesiones simultáneas registrando ventas, anulaciones y ajustes sobre las mismas variantes: no hubo errores ni deadlocks, y el stock final coincidió con la suma de los movimientos.

## Situaciones de error contempladas

| Tipo de error (enunciado) | Ejemplo en el sistema | Mecanismo | Código |
|---|---|---|---|
| Datos inválidos | Precio negativo, medio de pago inexistente, cantidad 0 | `CHECK` | 547 (motor) |
| Datos inválidos | Ajustar stock a una cantidad negativa | SP | 50020 |
| Violaciones de restricciones | SKU, DNI, CUIT o email duplicado | `UNIQUE` | 2627 (motor) |
| Violaciones de restricciones | Venta con un cliente o variante inexistente (sin pasar por el SP) | `FK` | 547 (motor) |
| Registros inexistentes | Venta, usuario, cliente o variante que no existe | SP | 50002, 50003, 50005, 50010, 50012, 50021, 50022 |
| Parámetros incorrectos | Carrito vacío o con una variante repetida | SP | 50001, 50004 |
| Operaciones no permitidas | Anular una venta ya anulada, reactivar una anulada | SP / trigger | 50011, 51020 |
| Operaciones no permitidas | Editar o borrar movimientos, ventas, líneas de venta o compras | Trigger | 51003, 51012, 51050, 51051 |
| Operaciones no permitidas | Vender sin stock, vender un producto inactivo | SP / trigger | 50006, 51002, 51011 |
| Operaciones no permitidas | Operar con un usuario inactivo | Trigger | 51004, 51005 |
| Operaciones no permitidas | Modificar una compra ya recibida o recibirla vacía | Trigger | 51030, 51031, 51040 |
| Errores durante transacciones | Falla a mitad de una venta | `XACT_ABORT` + `ROLLBACK` | — |

## Catálogo de códigos propios

Los rangos están separados para identificar de inmediato el origen del error:

| Rango | Origen |
|---|---|
| 50001 – 50099 | Stored procedures |
| 51001 – 51099 | Triggers |

| Código | Origen | Mensaje |
|---|---|---|
| 50001 | `SP_RegistrarVenta` | El detalle de la venta está vacío. |
| 50002 | `SP_RegistrarVenta` | El usuario que registra la venta no existe. |
| 50003 | `SP_RegistrarVenta` | El cliente especificado no existe. |
| 50004 | `SP_RegistrarVenta` | No se puede repetir la misma variante en la misma venta. |
| 50005 | `SP_RegistrarVenta` | Una o más variantes especificadas no existen. |
| 50006 | `SP_RegistrarVenta` | Stock insuficiente para la variante: *SKU*. Solicitado: *n*. Disponible: *m* |
| 50010 | `SP_AnularVenta` | La venta especificada no existe. |
| 50011 | `SP_AnularVenta` | La venta ya se encuentra anulada. |
| 50012 | `SP_AnularVenta` | El usuario que anula la venta no existe. |
| 50020 | `SP_AjustarStock` | La nueva cantidad de stock no puede ser negativa. |
| 50021 | `SP_AjustarStock` | El usuario que realiza el ajuste no existe. |
| 50022 | `SP_AjustarStock` | La variante especificada no existe. |
| 51002 | `TR_MovimientoStock_AplicarStock` | Stock insuficiente para registrar el movimiento. |
| 51003 | `TR_MovimientoStock_Inmutable` | Los movimientos de stock no se modifican: registre un AJUSTE. |
| 51004 | `TR_Venta_UsuarioActivo` | Un usuario inactivo no puede registrar ventas. |
| 51005 | `TR_Compra_UsuarioActivo` | Un usuario inactivo no puede registrar compras. |
| 51010 | `TR_DetalleVenta_Insert` | Solo se agregan lineas a una venta CONFIRMADA. |
| 51011 | `TR_DetalleVenta_Insert` | No se puede vender una variante de un producto inactivo. |
| 51012 | `TR_DetalleVenta_Inmutable` | Las lineas de venta no se modifican ni borran: anule la venta. |
| 51020 | `TR_Venta_CambioEstado` | Una venta anulada no puede volver a confirmarse. |
| 51030 | `TR_Compra_CambioEstado` | Solo una compra PENDIENTE puede cambiar de estado. |
| 51031 | `TR_Compra_CambioEstado` | No se puede recibir una compra sin lineas. |
| 51040 | `TR_DetalleCompra_Control` | Solo se modifican lineas de una compra PENDIENTE. |
| 51050 | `TR_Venta_NoBorrar` | Las ventas no se borran: cambie Estado a ANULADA. |
| 51051 | `TR_Compra_NoBorrar` | Las compras no se borran: cambie Estado a ANULADA. |

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
