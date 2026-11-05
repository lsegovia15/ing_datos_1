# 8. Modelo de tablas

Scripts: `sql/init_db.sql` (tablas, restricciones e índices) y `sql/siam_triggers.sql` (tablas de auditoría `HistorialPrecio` y `AlertaStock`).

## Tablas por módulo

| Módulo | Tablas |
|---|---|
| Catálogo | `Producto`, `VarianteProducto`, `Categoria`, `Marca`, `Segmento`, `Talle`, `Color` |
| Compras | `Proveedor`, `Compra`, `DetalleCompra` |
| Ventas | `Cliente`, `Venta`, `DetalleVenta` |
| Stock | `MovimientoStock`, `AlertaStock` |
| Auditoría | `HistorialPrecio` |
| Usuarios | `Usuario`, `Rol` |

**Total:** 18 tablas.

## Claves primarias

| Tabla | Clave primaria | Generación |
|---|---|---|
| Rol, Usuario, Categoria, Marca, Segmento, Talle, Color, Producto, VarianteProducto, Proveedor, Cliente | `Id<Tabla>` | Manual, al cargar el dato |
| Compra, Venta, MovimientoStock | `Id<Tabla>` | `MAX + 1` dentro de la transacción de los SPs |
| DetalleVenta | `(IdVenta, NroLinea)` | `SP_RegistrarVenta` graba la línea 1 (una venta = un producto) |
| DetalleCompra | `(IdCompra, NroLinea)` | `SP_RegistrarCompra` graba la línea 1 (una compra = un producto) |
| HistorialPrecio, AlertaStock | `IdHistorial`, `IdAlerta` | `IDENTITY(1,1)` |

## Claves foráneas y relaciones

| FK | Desde | Hacia | Al borrar el padre |
|---|---|---|---|
| `FK_Usuario_Rol` | Usuario.IdRol | Rol | `NO ACTION` |
| `FK_Producto_Categoria` | Producto.IdCategoria | Categoria | `NO ACTION` |
| `FK_Producto_Marca` | Producto.IdMarca | Marca | `NO ACTION` |
| `FK_Variante_Producto` | VarianteProducto.IdProducto | Producto | `NO ACTION` |
| `FK_Variante_Segmento` | VarianteProducto.IdSegmento | Segmento | `NO ACTION` |
| `FK_Variante_Talle` | VarianteProducto.IdTalle | Talle | `NO ACTION` |
| `FK_Variante_Color` | VarianteProducto.IdColor | Color | `NO ACTION` |
| `FK_Compra_Proveedor` | Compra.IdProveedor | Proveedor | `NO ACTION` |
| `FK_Compra_Usuario` | Compra.IdUsuario | Usuario | `NO ACTION` |
| `FK_DetalleCompra_Compra` | DetalleCompra.IdCompra | Compra | `NO ACTION` |
| `FK_DetalleCompra_Variante` | DetalleCompra.IdVariante | VarianteProducto | `NO ACTION` |
| `FK_Venta_Cliente` | Venta.IdCliente | Cliente | `NO ACTION` |
| `FK_Venta_Usuario` | Venta.IdUsuario | Usuario | `NO ACTION` |
| `FK_DetalleVenta_Venta` | DetalleVenta.IdVenta | Venta | `NO ACTION` |
| `FK_DetalleVenta_Variante` | DetalleVenta.IdVariante | VarianteProducto | `NO ACTION` |
| `FK_Mov_Variante` | MovimientoStock.IdVariante | VarianteProducto | `NO ACTION` |
| `FK_Mov_Usuario` | MovimientoStock.IdUsuario | Usuario | `NO ACTION` |
| `FK_Mov_Compra` | MovimientoStock.IdCompra | Compra | `NO ACTION` |
| `FK_Mov_Venta` | MovimientoStock.IdVenta | Venta | `NO ACTION` |
| `FK_Historial_Variante` | HistorialPrecio.IdVariante | VarianteProducto | `NO ACTION` |
| `FK_Alerta_Variante` | AlertaStock.IdVariante | VarianteProducto | `NO ACTION` |

**Criterio:** todas las FK usan el comportamiento por defecto (`NO ACTION`): no se puede borrar un dato que está en uso. Por ejemplo, no se puede borrar una categoría que tiene productos, ni un cliente que tiene ventas.

Además, ventas y compras nunca se borran: el trigger `TR_NoBorrarVenta` (`INSTEAD OF DELETE`) impide borrar ventas, y ningún rol tiene permiso de `DELETE` sobre ventas y compras.

## Restricciones de integridad (unicidad)

| Restricción | Tabla | Columnas |
|---|---|---|
| `UQ_Rol_Nombre` | Rol | Nombre |
| `UQ_Usuario_NombreUsuario` | Usuario | NombreUsuario |
| `UQ_Usuario_Email` | Usuario | Email |
| `UQ_Categoria_Nombre` | Categoria | Nombre |
| `UQ_Segmento_Nombre` | Segmento | Nombre |
| `UQ_Marca_Nombre` | Marca | Nombre |
| `UQ_Talle_Descripcion` | Talle | Descripcion |
| `UQ_Color_Nombre` | Color | Nombre |
| `UQ_Variante_SKU` | VarianteProducto | SKU |
| `UQ_Variante_Combinacion` | VarianteProducto | IdProducto, IdSegmento, IdTalle, IdColor |
| `UQ_Proveedor_CUIT` | Proveedor | CUIT |
| `UQ_Cliente_DNI` | Cliente | DNI |
| `UQ_DetalleCompra` | DetalleCompra | IdCompra, IdVariante |
| `UQ_DetalleVenta` | DetalleVenta | IdVenta, IdVariante |

## Restricciones de dominio

| Restricción | Tabla | Condición |
|---|---|---|
| `CK_Usuario_Activo` | Usuario | `Activo IN (0, 1)` |
| `CK_Producto_Precio` | Producto | `PrecioBase >= 0` |
| `CK_Producto_Activo` | Producto | `Activo IN (0, 1)` |
| `CK_Variante_Precio` | VarianteProducto | `PrecioVenta >= 0` |
| `CK_Variante_Stock` | VarianteProducto | `StockActual >= 0 AND StockMinimo >= 0` |
| `CK_Compra_Total` | Compra | `Total >= 0` |
| `CK_Compra_Estado` | Compra | `Estado IN ('PENDIENTE', 'RECIBIDA', 'ANULADA')` |
| `CK_DetalleCompra_Cantidad` | DetalleCompra | `Cantidad > 0` |
| `CK_DetalleCompra_Costo` | DetalleCompra | `CostoUnitario >= 0` |
| `CK_Venta_MedioPago` | Venta | `MedioPago IN ('EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA')` |
| `CK_Venta_Total` | Venta | `Total >= 0` |
| `CK_Venta_Estado` | Venta | `Estado IN ('CONFIRMADA', 'ANULADA')` |
| `CK_DetalleVenta_Cantidad` | DetalleVenta | `Cantidad > 0` |
| `CK_DetalleVenta_Precio` | DetalleVenta | `PrecioUnitario >= 0` |
| `CK_DetalleVenta_Descuento` | DetalleVenta | `Descuento >= 0 AND Descuento <= Cantidad * PrecioUnitario` |
| `CK_Mov_Tipo` | MovimientoStock | `TipoMovimiento IN ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION')` |
| `CK_Mov_Cantidad` | MovimientoStock | `AJUSTE` con `Cantidad <> 0`; el resto con `Cantidad > 0` |
| `CK_Mov_Origen` | MovimientoStock | No puede tener `IdCompra` e `IdVenta` a la vez |
| `CK_AlertaStock_Atendida` | AlertaStock | `Atendida IN (0, 1)` |

## Valores por defecto

| Tabla.Columna | Default |
|---|---|
| Usuario.Activo, Producto.Activo | `1` |
| Usuario.FechaAlta, Compra.Fecha, Venta.Fecha, MovimientoStock.Fecha, HistorialPrecio.Fecha, AlertaStock.Fecha | `GETDATE()` |
| VarianteProducto.StockActual, VarianteProducto.StockMinimo | `0` |
| Compra.Total, Venta.Total, DetalleVenta.Descuento, AlertaStock.Atendida | `0` |
| Compra.Estado | `'PENDIENTE'` |
| Venta.Estado | `'CONFIRMADA'` |

## Índices

SQL Server crea índices automáticamente para las claves primarias y las restricciones `UNIQUE`, pero no para las claves foráneas. Por eso se crearon índices explícitos:

| Índice | Tabla | Columnas | Motivo |
|---|---|---|---|
| `IX_Usuario_IdRol` | Usuario | IdRol | FK |
| `IX_Producto_IdCategoria` | Producto | IdCategoria | FK |
| `IX_Producto_IdMarca` | Producto | IdMarca | FK |
| `IX_Variante_IdSegmento` | VarianteProducto | IdSegmento | FK |
| `IX_Variante_IdTalle` | VarianteProducto | IdTalle | FK |
| `IX_Variante_IdColor` | VarianteProducto | IdColor | FK |
| `IX_Compra_IdProveedor` | Compra | IdProveedor | FK |
| `IX_Compra_IdUsuario` | Compra | IdUsuario | FK |
| `IX_DetalleCompra_IdVariante` | DetalleCompra | IdVariante | FK |
| `IX_Venta_IdCliente` | Venta | IdCliente | FK |
| `IX_Venta_IdUsuario` | Venta | IdUsuario | FK |
| `IX_DetalleVenta_IdVariante` | DetalleVenta | IdVariante | FK |
| `IX_Mov_IdVariante` | MovimientoStock | IdVariante | FK |
| `IX_Mov_IdUsuario` | MovimientoStock | IdUsuario | FK |
| `IX_Mov_IdCompra` | MovimientoStock | IdCompra | FK |
| `IX_Mov_IdVenta` | MovimientoStock | IdVenta | FK |
| `IX_Producto_Nombre` | Producto | Nombre | Búsqueda de productos por nombre |
| `IX_Cliente_Apellido_Nombre` | Cliente | Apellido, Nombre | Búsqueda de clientes |
| `IX_Compra_Fecha` | Compra | Fecha | Informes por período |
| `IX_Venta_Fecha` | Venta | Fecha | Informes por período |
| `IX_Mov_Fecha` | MovimientoStock | Fecha | Historial de stock por período |

La FK de `VarianteProducto.IdProducto` no necesita un índice propio, porque es la primera columna de `UQ_Variante_Combinacion`, que ya tiene uno.
