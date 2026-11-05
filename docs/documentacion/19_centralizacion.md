# 19. Centralización de la lógica en la capa de datos

Las reglas de negocio del local viven en la base de datos y no en la aplicación que la use. Así se cumplen siempre, sin importar si los datos se modifican desde una aplicación, desde SQL Server Management Studio o desde un script, y no hace falta reimplementarlas en cada cliente.

## Dónde se implementa cada regla

| Regla de negocio | Mecanismo | Objeto |
|---|---|---|
| Los precios, costos y totales no son negativos | `CHECK` | `CK_Producto_Precio`, `CK_Variante_Precio`, `CK_Venta_Total`, `CK_Compra_Total`... |
| El descuento de una línea no supera su importe | `CHECK` | `CK_DetalleVenta_Descuento` |
| Solo se aceptan medios de pago y estados válidos | `CHECK` | `CK_Venta_MedioPago`, `CK_Venta_Estado`, `CK_Compra_Estado` |
| No hay SKU, DNI, CUIT ni email repetidos | `UNIQUE` | `UQ_Variante_SKU`, `UQ_Cliente_DNI`, `UQ_Proveedor_CUIT`, `UQ_Usuario_Email` |
| No existen dos variantes con el mismo producto, segmento, talle y color | `UNIQUE` | `UQ_Variante_Combinacion` |
| Un movimiento proviene de una compra o de una venta, no de ambas | `CHECK` | `CK_Mov_Origen` |
| El stock nunca es negativo | `CHECK` + trigger | `CK_Variante_Stock`, `TR_DescontarStockVenta` |
| Toda venta descuenta stock | Trigger | `TR_DescontarStockVenta` |
| Anular una venta devuelve el stock | Trigger | `TR_DevolverStockAnulacion` |
| La mercadería entra al stock recién al recibir la compra | Trigger | `TR_SumarStockCompra` |
| Un ajuste de stock se aplica sobre el stock | Trigger | `TR_AplicarAjusteStock` |
| El total de la venta coincide con el detalle | Trigger | `TR_CalcularTotalVenta` |
| Las ventas no se borran | Trigger + permisos | `TR_NoBorrarVenta`, `DENY DELETE` |
| Todo cambio de precio queda registrado | Trigger | `TR_HistorialPrecio` |
| Se avisa cuando una variante llega al mínimo | Trigger | `TR_AvisoStockMinimo` |
| Una venta se registra completa o no se registra | SP + transacción | `SP_RegistrarVenta` |
| Un ajuste de stock queda registrado con su motivo y su autor | SP | `SP_AjustarStock` |
| Una compra se registra completa y entra al stock recién al recibirla | SP + trigger | `SP_RegistrarCompra`, `SP_RecibirCompra`, `TR_SumarStockCompra` |
| Solo el administrador anula, ajusta y compra | SP + permisos | Validación de rol en los SPs y `DENY EXECUTE` (sección 18) |
| El criterio de "stock bajo" es uno solo | Vista / función | `vw_StockVariante`, `fn_EstadoStock` |
| Cuánto reponer de cada variante | Cursor | `SP_InformeReposicionStock` |

## Criterio para elegir el mecanismo

- **Restricción (`CHECK`, `UNIQUE`, `FK`)** cuando la regla se puede evaluar mirando una sola fila o la existencia de otra. Es el mecanismo más simple y el más rápido, y el motor no permite saltearlo.
- **Trigger** cuando la regla depende de otras tablas o del valor anterior de un registro (por ejemplo, de qué estado a qué estado pasa una venta), o cuando una modificación tiene que provocar otra automáticamente (por ejemplo, una venta que descuenta stock).
- **Stored procedure** cuando la operación tiene varios pasos que deben ejecutarse juntos, recibe parámetros que hay que validar o necesita devolver un resultado y mensajes claros a quien llama.
- **Vista o función** cuando un cálculo o una consulta se repite y conviene que tenga una sola definición.

## Beneficios

- **Consistencia:** el stock y el total de cada venta se actualizan en la misma transacción que la operación, sin depender de la aplicación cliente.
- **Un solo lugar para cambiar una regla:** por ejemplo, si cambia el criterio de stock bajo, se modifica la vista y la función, no cada pantalla.
- **Auditoría:** el historial de precios y las alertas de stock bajo se generan automáticamente; los ajustes de stock quedan en `MovimientoStock`.
