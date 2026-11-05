# 17. Manejo de errores

El manejo de errores se reparte en tres niveles. Cada nivel cubre lo que el anterior no puede controlar:

| Nivel | Mecanismo | Qué controla |
|---|---|---|
| 1. Estructura | Restricciones `PK`, `FK`, `UNIQUE`, `CHECK`, `NOT NULL` | Datos inválidos en cualquier `INSERT` o `UPDATE`, venga de donde venga |
| 2. Reglas automáticas | Triggers | Mantener stock y totales sincronizados; `TR_DescontarStockVenta` cancela la venta si no hay stock |
| 3. Operaciones | Stored procedures con `TRY...CATCH` y transacciones | Existencia de registros, rol del usuario y atomicidad de las operaciones |

## Patrón usado en los stored procedures

```sql
BEGIN TRY
    -- Validaciones de negocio: mensaje y salida, sin excepción
    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
    BEGIN
        PRINT 'Error: El usuario que registra la venta no existe o está inactivo.';
        RETURN;
    END

    BEGIN TRANSACTION;
        -- inserciones o actualizaciones
    COMMIT TRANSACTION;

    SELECT 'Operación registrada' AS Mensaje;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;   -- relanza el error original
END CATCH
```

- **Validaciones con `PRINT` + `RETURN`:** no generan una excepción ni un número de error. El SP termina correctamente, no devuelve el resultset de éxito y deja los datos sin modificar.
- **`BEGIN TRANSACTION` después de las validaciones:** un rechazo de negocio ocurre antes de abrir la transacción, así que no hay nada que revertir.
- **`IF @@TRANCOUNT > 0 ROLLBACK`:** revierte solo si el error ocurrió dentro de la transacción.
- **`THROW;` sin parámetros en el `CATCH`:** relanza el error original conservando número, mensaje y línea. Se usa para errores del motor y para el `THROW 50001` del trigger de stock.
- **`SET XACT_ABORT`:** no se usa. La reversión depende del `ROLLBACK` del `CATCH`.

Como las validaciones no lanzan error, el llamador no puede confiar en `TRY...CATCH` para detectar un rechazo de negocio. Debe comprobar el estado de los datos o los conteos antes y después de la llamada.

## Errores del motor y del trigger

Las restricciones y el trigger sí generan errores que se pueden capturar:

| Situación | Error |
|---|---|
| `UNIQUE` duplicado (SKU, DNI, CUIT, email, nombre de usuario) | 2627 |
| `CHECK` o `FK` violado | 547 |
| `NOT NULL` violado | 515 |
| Venta sin stock suficiente (`TR_DescontarStockVenta`) | 50001, mensaje `No hay stock suficiente para realizar la venta.` |
| Permiso insuficiente sobre una tabla, vista o SP | 229 |
| Permiso insuficiente sobre una columna | 230 |

`TR_DescontarStockVenta` es el único objeto que lanza un error propio. Corre dentro de la transacción del `INSERT` en `DetalleVenta`: si una línea no tiene stock, el `THROW` revierte el detalle y la cabecera de la venta que se estaba registrando.

## Concurrencia

La implementación no usa bloqueos explícitos ni contexto de sesión. Las consecuencias son:

| Situación | Comportamiento |
|---|---|
| Dos ventas o compras generan el mismo `IdVenta` o `IdCompra` | Ambos leen `MAX(Id) + 1` sin bloqueo; una de las dos inserciones falla por la clave primaria |
| Dos ajustes generan el mismo `IdMovimiento` | Igual que el caso anterior |
| Dos ventas compiten por la última unidad | La validación previa del SP puede dejar pasar ambas; el trigger y el `CHECK (StockActual >= 0)` impiden que el stock quede negativo, y una de las operaciones falla |
| Un ajuste se calcula sobre un stock que cambió | El SP lee el stock antes de la transacción y no lo bloquea; la diferencia puede quedar desactualizada |
| Anular una venta o recibir una compra dos veces a la vez | El SP lee el estado antes de la transacción y el `UPDATE` no vuelve a condicionar por estado; el trigger solo actúa si la fila pasa de `CONFIRMADA` a `ANULADA` o de `PENDIENTE` a `RECIBIDA` |
| Atribuir la operación a un usuario | Los SPs reciben `@IdUsuario` como parámetro y no lo relacionan con el login conectado |

Los identificadores con `MAX + 1` funcionan en el uso secuencial y en el volumen de un local, pero no están preparados para alta concurrencia. Con más volumen convendría usar `IDENTITY` o `SEQUENCE`.

## Situaciones contempladas

| Tipo de error | Ejemplo en el sistema | Mecanismo |
|---|---|---|
| Dato inválido | Precio negativo, cantidad 0, medio de pago inexistente | `CHECK` (error 547) |
| Dato duplicado | SKU, DNI, CUIT, email o nombre de usuario repetido | `UNIQUE` (error 2627) |
| Referencia inexistente | Venta con un cliente o una variante que no existe | `FK` (error 547) |
| Registro inexistente | Venta, compra, usuario, cliente, proveedor o variante que no existe | `PRINT` + `RETURN` del SP |
| Parámetro incorrecto | Cantidad de compra menor o igual a cero, costo negativo | `PRINT` + `RETURN` del SP |
| Rol no habilitado | Un vendedor intenta anular, ajustar stock, registrar o recibir compras | `PRINT` + `RETURN` del SP |
| Operación no permitida | Anular una venta ya anulada, recibir una compra que no está pendiente | `PRINT` + `RETURN` del SP |
| Venta sin stock | La variante no tiene unidades suficientes | `THROW 50001` del trigger |
| Borrado de una venta | `DELETE FROM Venta` | `TR_NoBorrarVenta` imprime un aviso y no borra; el administrador además no tiene permiso `DELETE` sobre `Venta` |

## Casos borde de `seed_data.sql`

El seed ejecuta cada caso y muestra el resultado de la llamada. Como los rechazos no lanzan excepción, se reconocen por el mensaje impreso y por el estado de los datos:

| Caso | Verificación |
|---|---|
| Venta sin stock | La cantidad de ventas no cambia |
| Compra sin líneas de detalle | La cantidad de compras no cambia |
| Recepción de una compra sin líneas | La compra sigue `PENDIENTE` |
| Anulación duplicada | La venta sigue `ANULADA` y el stock no cambia |
| Anulación por un vendedor | La venta sigue `CONFIRMADA` y el stock no cambia |
| Ajuste por un vendedor | El stock y la cantidad de movimientos no cambian |
| Compra registrada por un vendedor | La cantidad de compras no cambia |
| Recepción por un vendedor | La compra sigue `PENDIENTE` |
| Venta con un usuario inactivo | La cantidad de ventas no cambia |
| Ajuste sin diferencia | La cantidad de movimientos no cambia |

## Ejemplo: capturar un error del motor

Solo los errores de restricciones o del trigger llegan al `CATCH`. En este ejemplo, la variante no tiene stock y `TR_DescontarStockVenta` lanza el error 50001:

```sql
BEGIN TRY
    INSERT INTO dbo.DetalleVenta
        (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
    VALUES
        (1, 99, 3, 1, 1000, 0);
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS Codigo,   -- 50001
           ERROR_MESSAGE() AS Mensaje;  -- 'No hay stock suficiente...'
END CATCH;
```

Un rechazo de validación de un SP, en cambio, no entra al `CATCH`: imprime el mensaje y vuelve sin modificar los datos.
