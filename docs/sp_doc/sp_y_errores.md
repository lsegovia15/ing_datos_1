# Procedimientos almacenados y control de errores

Los SPs encapsulan las operaciones que mueven stock. Cada venta y cada compra corresponde a un producto (una variante).

## Reparto de responsabilidades entre SPs y triggers

| Operación | Lo hace el SP | Lo hace el trigger |
|---|---|---|
| Registrar venta | Valida e inserta `Venta` y `DetalleVenta` | `TR_DescontarStockVenta` resta el stock; `TR_CalcularTotalVenta` calcula el `Total` |
| Anular venta | Valida rol `Administrador` y pasa `Estado` a `ANULADA` | `TR_DevolverStockAnulacion` suma el stock |
| Registrar compra | Inserta `Compra` y `DetalleCompra` en `PENDIENTE` y calcula el `Total` | — |
| Recibir compra | Cambia `PENDIENTE` a `RECIBIDA` | `TR_SumarStockCompra` suma el stock |
| Ajustar stock | Inserta el `AJUSTE` con la diferencia | `TR_AplicarAjusteStock` suma o resta el stock |

## Transacciones y errores

Todos los SPs siguen el patrón de la Clase X:

- Validaciones dentro de `BEGIN TRY` que lanzan `THROW` con un código propio.
- `BEGIN TRANSACTION` ... `COMMIT TRANSACTION` para grabar cabecera y detalle juntos.
- En el `CATCH`: `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION` y `THROW;` para devolver el error original a quien llamó.

Los triggers corren dentro de la misma transacción: si `TR_DescontarStockVenta` rechaza la venta por falta de stock, el `ROLLBACK` del SP también revierte la cabecera.

## Documentación detallada

- Cada SP: [SP_RegistrarVenta](SP_RegistrarVenta.md), [SP_AnularVenta](SP_AnularVenta.md), [SP_AjustarStock](SP_AjustarStock.md), [SP_RegistrarCompra](SP_RegistrarCompra.md), [SP_RecibirCompra](SP_RecibirCompra.md).
- Catálogo completo de códigos de error: [documentacion/17_manejo_errores.md](../documentacion/17_manejo_errores.md).
