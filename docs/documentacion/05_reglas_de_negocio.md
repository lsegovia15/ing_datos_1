# 5. Reglas de negocio

Cada regla indica con qué mecanismo de la base de datos se implementa. El detalle de cada mecanismo está en las secciones 13 (Stored Procedures), 14 (Triggers) y 17 (Manejo de errores).

## Catálogo

| Código | Regla | Implementación |
|---|---|---|
| RN-01 | Cada producto pertenece a una categoría y a una marca. | FK `NOT NULL` en `Producto` |
| RN-02 | El stock se controla por variante: la combinación de producto, segmento, talle y color. No pueden existir dos variantes con la misma combinación. | `UQ_Variante_Combinacion` |
| RN-03 | Cada variante tiene un código SKU único. | `UQ_Variante_SKU` |
| RN-04 | Los precios (base y de venta) no pueden ser negativos. | `CK_Producto_Precio`, `CK_Variante_Precio` |
| RN-05 | Los productos no se eliminan: se dan de baja (`Activo = 0`). Un producto inactivo no se puede vender. | `CK_Producto_Activo`, `TR_DetalleVenta_Insert` |
| RN-06 | Todo cambio de precio de venta queda registrado con el precio anterior, el nuevo, la fecha y el usuario. | `TR_Variante_HistorialPrecio` |
| RN-07 | No se repiten nombres de categoría, marca, segmento, talle ni color. | `UNIQUE` en cada tabla |

## Stock

| Código | Regla | Implementación |
|---|---|---|
| RN-08 | El stock de una variante nunca puede ser negativo. | `CK_Variante_Stock`, `TR_MovimientoStock_AplicarStock` |
| RN-09 | El stock solo cambia por movimientos: `ENTRADA` (compra recibida), `SALIDA` (venta), `DEVOLUCION` (venta anulada) y `AJUSTE` (corrección). El stock actual es siempre la suma de los movimientos. | `TR_MovimientoStock_AplicarStock` |
| RN-10 | Los movimientos de stock no se modifican ni se borran. Un error se corrige con un nuevo ajuste. | `TR_MovimientoStock_Inmutable` |
| RN-11 | Un ajuste registra la diferencia entre el stock contado y el del sistema, con signo, junto con el usuario y el motivo. | `SP_AjustarStock`, `CK_Mov_Cantidad` |
| RN-12 | Un movimiento se origina en una compra, en una venta o en ninguna (ajuste), pero nunca en ambas. | `CK_Mov_Origen` |
| RN-13 | Cuando el stock de una variante llega a su mínimo, se genera una alerta de reposición. | `TR_Variante_AlertaStock` |

## Ventas

| Código | Regla | Implementación |
|---|---|---|
| RN-14 | Una venta puede tener un cliente registrado o ser a consumidor final. | `Venta.IdCliente` admite `NULL` |
| RN-15 | Los medios de pago válidos son efectivo, débito, crédito y transferencia. | `CK_Venta_MedioPago` |
| RN-16 | Una venta tiene al menos una línea. Cada variante aparece una sola vez por venta y con cantidad mayor a cero. | `SP_RegistrarVenta`, `UQ_DetalleVenta`, `CK_DetalleVenta_Cantidad` |
| RN-17 | El descuento de una línea no puede ser negativo ni mayor que el importe de la línea. | `CK_DetalleVenta_Descuento` |
| RN-18 | El total de la venta es la suma de `Cantidad × PrecioUnitario − Descuento` de sus líneas. | `TR_DetalleVenta_Insert` |
| RN-19 | No se puede vender más que el stock disponible. Si una línea no tiene stock, no se registra ninguna parte de la venta. | `SP_RegistrarVenta`, `TR_MovimientoStock_AplicarStock`, transacción |
| RN-20 | Registrar una venta descuenta el stock de cada línea. | `TR_DetalleVenta_Insert` |
| RN-21 | Las ventas no se borran ni se editan: se anulan. Al anular se devuelve el stock y se registra quién lo autorizó. La anulación es definitiva. | `SP_AnularVenta`, `TR_Venta_CambioEstado`, `TR_Venta_NoBorrar`, `TR_DetalleVenta_Inmutable` |

## Compras

| Código | Regla | Implementación |
|---|---|---|
| RN-22 | Una compra se hace a un proveedor y pasa por los estados `PENDIENTE → RECIBIDA` o `PENDIENTE → ANULADA`. No hay otras transiciones. | `CK_Compra_Estado`, `TR_Compra_CambioEstado` |
| RN-23 | Las líneas de una compra solo se pueden cargar, modificar o borrar mientras la compra está pendiente. | `TR_DetalleCompra_Control` |
| RN-24 | El total de la compra es la suma de `Cantidad × CostoUnitario` de sus líneas. | `TR_DetalleCompra_Control` |
| RN-25 | La mercadería ingresa al stock recién cuando la compra se recibe. No se puede recibir una compra sin líneas. | `TR_Compra_CambioEstado` |
| RN-26 | Las compras no se borran: se anulan. | `TR_Compra_NoBorrar` |

## Personas

| Código | Regla | Implementación |
|---|---|---|
| RN-27 | Cada usuario tiene un rol. El nombre de usuario y el email son únicos. | FK `IdRol`, `UQ_Usuario_NombreUsuario`, `UQ_Usuario_Email` |
| RN-28 | Un usuario dado de baja no puede registrar ventas ni compras. | `TR_Venta_UsuarioActivo`, `TR_Compra_UsuarioActivo` |
| RN-29 | Un cliente se identifica por su DNI y un proveedor por su CUIT, ambos únicos. | `UQ_Cliente_DNI`, `UQ_Proveedor_CUIT` |
