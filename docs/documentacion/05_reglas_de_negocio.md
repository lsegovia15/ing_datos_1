# 5. Reglas de negocio

Cada regla indica con qué mecanismo de la base de datos se implementa. El detalle de cada mecanismo está en las secciones 13 (Stored Procedures), 14 (Triggers) y 17 (Manejo de errores).

## Catálogo

| Código | Regla | Implementación |
|---|---|---|
| RN-01 | Cada producto pertenece a una categoría y a una marca. | FK `NOT NULL` en `Producto` |
| RN-02 | El stock se controla por variante: la combinación de producto, segmento, talle y color. No pueden existir dos variantes con la misma combinación. | `UQ_Variante_Combinacion` |
| RN-03 | Cada variante tiene un código SKU único. | `UQ_Variante_SKU` |
| RN-04 | Los precios (base y de venta) no pueden ser negativos. | `CK_Producto_Precio`, `CK_Variante_Precio` |
| RN-05 | Los productos no se eliminan: se dan de baja (`Activo = 0`). | `CK_Producto_Activo` |
| RN-06 | Todo cambio de precio de venta queda registrado con el precio anterior, el nuevo y la fecha. | `TR_HistorialPrecio` |
| RN-07 | No se repiten nombres de categoría, marca, segmento, talle ni color. | `UNIQUE` en cada tabla |

## Stock

| Código | Regla | Implementación |
|---|---|---|
| RN-08 | El stock de una variante nunca puede ser negativo. | `CK_Variante_Stock`, `TR_DescontarStockVenta` |
| RN-09 | El stock cambia por cuatro operaciones: venta (resta), anulación de venta (suma), compra recibida (suma) y ajuste (suma o resta la diferencia). | `TR_DescontarStockVenta`, `TR_DevolverStockAnulacion`, `TR_SumarStockCompra`, `TR_AplicarAjusteStock` |
| RN-10 | Cada ajuste de stock queda registrado en `MovimientoStock` con usuario, fecha y observación. | `SP_AjustarStock`, `MovimientoStock` |
| RN-11 | Un ajuste registra la diferencia entre el stock contado y el del sistema, con signo, junto con el usuario y el motivo. | `SP_AjustarStock`, `CK_Mov_Cantidad` |
| RN-12 | Un movimiento se origina en una compra, en una venta o en ninguna (ajuste), pero nunca en ambas. | `CK_Mov_Origen` |
| RN-13 | Cuando el stock de una variante baja hasta su mínimo, se genera una alerta de reposición. | `TR_AvisoStockMinimo` |

## Ventas

| Código | Regla | Implementación |
|---|---|---|
| RN-14 | Una venta puede tener un cliente registrado o ser a consumidor final. | `Venta.IdCliente` admite `NULL` |
| RN-15 | Los medios de pago válidos son efectivo, débito, crédito y transferencia. | `CK_Venta_MedioPago` |
| RN-16 | Una venta tiene al menos una línea. Cada variante aparece una sola vez por venta y con cantidad mayor a cero. | `SP_RegistrarVenta`, `UQ_DetalleVenta`, `CK_DetalleVenta_Cantidad` |
| RN-17 | El descuento de una línea no puede ser negativo ni mayor que el importe de la línea. | `CK_DetalleVenta_Descuento` |
| RN-18 | El total de la venta es la suma de `Cantidad × PrecioUnitario − Descuento` de sus líneas. | `SP_RegistrarVenta`, `TR_CalcularTotalVenta` |
| RN-19 | No se puede vender más que el stock disponible. Si una línea no tiene stock, no se registra ninguna parte de la venta. | `SP_RegistrarVenta`, `TR_DescontarStockVenta`, transacción |
| RN-20 | Registrar una venta descuenta el stock de cada línea. | `TR_DescontarStockVenta` |
| RN-21 | Las ventas no se borran: se anulan. Al anular se devuelve el stock y solo un `Administrador` activo puede hacerlo. | `SP_AnularVenta`, `TR_DevolverStockAnulacion`, `TR_NoBorrarVenta`, `DENY DELETE` |

## Compras

| Código | Regla | Implementación |
|---|---|---|
| RN-22 | Una compra se hace a un proveedor y se registra `PENDIENTE`. Solo una compra `PENDIENTE` puede recibirse. | `CK_Compra_Estado`, `SP_RegistrarCompra`, `SP_RecibirCompra` |
| RN-23 | Las líneas de una compra se cargan junto con la cabecera, en una sola transacción. | `SP_RegistrarCompra` |
| RN-24 | El total de la compra es la suma de `Cantidad × CostoUnitario` de sus líneas. | `SP_RegistrarCompra` |
| RN-25 | La mercadería ingresa al stock recién cuando la compra se recibe. No se puede recibir una compra sin líneas. | `SP_RecibirCompra`, `TR_SumarStockCompra` |
| RN-26 | Las compras no se borran. | `DENY DELETE` sobre `Compra` y `DetalleCompra` |

## Personas

| Código | Regla | Implementación |
|---|---|---|
| RN-27 | Cada usuario tiene un rol. El nombre de usuario y el email son únicos. | FK `IdRol`, `UQ_Usuario_NombreUsuario`, `UQ_Usuario_Email` |
| RN-28 | Un usuario dado de baja no puede registrar ventas ni compras. | Validación `Activo = 1` en los SPs |
| RN-29 | Un cliente se identifica por su DNI y un proveedor por su CUIT, ambos únicos. | `UQ_Cliente_DNI`, `UQ_Proveedor_CUIT` |
