# 17. Manejo de errores

El manejo de errores se reparte en tres niveles. Cada nivel atrapa lo que el anterior no puede ver:

| Nivel | Mecanismo | Qué controla |
|---|---|---|
| 1. Estructura | Restricciones `PK`, `FK`, `UNIQUE`, `CHECK`, `NOT NULL` | Datos inválidos en cualquier `INSERT`/`UPDATE`, venga de donde venga |
| 2. Reglas de negocio | Triggers | Mantener stock y totales sincronizados; cortar la venta si no hay stock; impedir borrados y cambios de estado inválidos |
| 3. Operaciones | Stored procedures con `TRY...CATCH` y transacciones | Parámetros incorrectos, registros inexistentes, permisos de rol y mensajes claros para el usuario |

## Patrón usado en los stored procedures

Es el patrón de la Clase X (transferencia entre cuentas):

```sql
BEGIN TRY
    -- Validaciones: errores de negocio con código propio
    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
    BEGIN
        THROW 50002, 'El usuario que registra la venta no existe o está inactivo.', 1;
    END

    BEGIN TRANSACTION;
        -- modificaciones
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;   -- devuelve el error original a quien llamó al SP
END CATCH
```

- **`THROW` en las validaciones:** corta la ejecución con un número y un mensaje propios. El error llega a quien ejecutó el SP, que puede capturarlo con su propio `TRY...CATCH`.
- **`BEGIN TRANSACTION` / `COMMIT`:** la cabecera y la línea de una venta o compra se graban juntas o no se graba ninguna.
- **`IF @@TRANCOUNT > 0 ROLLBACK`:** revierte solo si hay una transacción abierta (un error de validación ocurre antes de abrirla).
- **`THROW;` sin parámetros en el `CATCH`:** relanza el error **original** conservando número y mensaje.

## Errores dentro de transacciones

Los triggers corren dentro de la transacción de la sentencia que los dispara. Si un trigger lanza `THROW` (`TR_DescontarStockVenta`, `TR_DevolverStockAnulacion`, `TR_SumarStockCompra` o `TR_NoBorrarVenta`), se revierte la operación completa. Ejemplo: si al insertar la línea de una venta no alcanza el stock, el `CATCH` del SP hace `ROLLBACK` y tampoco queda grabada la cabecera.

## Situaciones de error contempladas

| Tipo de error | Ejemplo en el sistema | Mecanismo | Código |
|---|---|---|---|
| Datos inválidos | Precio negativo, cantidad 0 en una tabla | `CHECK` | 547 (motor) |
| Datos inválidos | Cantidad, costo, descuento o medio de pago inválidos en un SP | SP | 50001, 50004, 50008, 50020, 50104, 50105 |
| Violaciones de restricciones | SKU, DNI, CUIT o email duplicado | `UNIQUE` | 2627 (motor) |
| Violaciones de restricciones | Venta con un cliente o variante inexistente (sin pasar por el SP) | `FK` | 547 (motor) |
| Registros inexistentes | Venta, compra, usuario, cliente, proveedor o variante que no existe | SP | 50002, 50003, 50005, 50010, 50012, 50021, 50022, 50101, 50102, 50106, 50110, 50113 |
| Permisos insuficientes | Un vendedor intenta anular, ajustar stock o registrar o recibir compras | SP | 50007, 50013, 50023, 50107, 50114 |
| Permisos insuficientes | Acceso a tablas o SPs sin `GRANT` para el rol del motor | Permisos | 229 (motor) |
| Operaciones no permitidas | Anular una venta ya anulada | SP | 50011 |
| Operaciones no permitidas | Vender sin stock | SP / trigger | 50006, 50200 |
| Operaciones no permitidas | Recibir una compra vacía o que no está pendiente | SP | 50111, 50112 |
| Operaciones no permitidas | Reactivar una venta anulada o volver a recibir una compra | Trigger | 50201, 50202 |
| Operaciones no permitidas | Borrar una venta | Trigger `INSTEAD OF` | 50203 |

## Catálogo de códigos propios

Los rangos están separados para identificar de inmediato el origen del error:

| Rango | Origen |
|---|---|
| 50001 – 50099 | Stored procedures de ventas y stock |
| 50100 – 50199 | Stored procedures de compras |
| 50200 – 50299 | Triggers |

| Código | Origen | Mensaje |
|---|---|---|
| 50001 | `SP_RegistrarVenta` | La cantidad a vender debe ser mayor a cero. |
| 50002 | `SP_RegistrarVenta` | El usuario que registra la venta no existe o está inactivo. |
| 50003 | `SP_RegistrarVenta` | El cliente especificado no existe. |
| 50004 | `SP_RegistrarVenta` | Medio de pago no válido. |
| 50005 | `SP_RegistrarVenta` | La variante especificada no existe. |
| 50006 | `SP_RegistrarVenta` | Stock insuficiente para realizar la venta. |
| 50007 | `SP_RegistrarVenta` | El usuario debe tener rol Administrador o Vendedor para registrar ventas. |
| 50008 | `SP_RegistrarVenta` | El descuento no puede ser negativo ni mayor al importe de la venta. |
| 50010 | `SP_AnularVenta` | La venta especificada no existe. |
| 50011 | `SP_AnularVenta` | La venta ya se encuentra anulada. |
| 50012 | `SP_AnularVenta` | El usuario que anula la venta no existe o está inactivo. |
| 50013 | `SP_AnularVenta` | Solo un usuario Administrador puede anular ventas. |
| 50020 | `SP_AjustarStock` | La nueva cantidad de stock no puede ser negativa. |
| 50021 | `SP_AjustarStock` | El usuario que realiza el ajuste no existe o está inactivo. |
| 50022 | `SP_AjustarStock` | La variante especificada no existe. |
| 50023 | `SP_AjustarStock` | Solo un usuario Administrador puede ajustar stock. |
| 50101 | `SP_RegistrarCompra` | El proveedor especificado no existe. |
| 50102 | `SP_RegistrarCompra` | El usuario que registra la compra no existe o está inactivo. |
| 50104 | `SP_RegistrarCompra` | La cantidad comprada debe ser mayor a cero. |
| 50105 | `SP_RegistrarCompra` | El costo unitario no puede ser negativo. |
| 50106 | `SP_RegistrarCompra` | La variante especificada no existe. |
| 50107 | `SP_RegistrarCompra` | Solo un usuario Administrador puede registrar compras. |
| 50110 | `SP_RecibirCompra` | La compra especificada no existe. |
| 50111 | `SP_RecibirCompra` | No se puede recibir una compra sin líneas de detalle. |
| 50112 | `SP_RecibirCompra` | Solo una compra en estado PENDIENTE puede recibirse. |
| 50113 | `SP_RecibirCompra` | El usuario que recibe la compra no existe o está inactivo. |
| 50114 | `SP_RecibirCompra` | Solo un usuario Administrador puede recibir compras. |
| 50200 | `TR_DescontarStockVenta` | No hay stock suficiente para realizar la venta. |
| 50201 | `TR_DevolverStockAnulacion` | Cambio de estado de venta no permitido. Solo se puede pasar de CONFIRMADA a ANULADA. |
| 50202 | `TR_SumarStockCompra` | Cambio de estado de compra no permitido. Solo se puede pasar de PENDIENTE a RECIBIDA o ANULADA. |
| 50203 | `TR_NoBorrarVenta` | Las ventas no se pueden borrar. Use SP_AnularVenta para anularla. |

## Ejemplo: capturar un error desde quien llama

```sql
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS Codigo,   -- 50011
           ERROR_MESSAGE() AS Mensaje;  -- 'La venta ya se encuentra anulada.'
END CATCH;
```

La sección 8 de `sql/seed_data.sql` y el script `sql/99_test_siam.sql` ejecutan cada uno de estos casos.
