# 9. Diccionario de datos

Convenciones: **PK** = clave primaria · **FK** = clave foránea · **UQ** = único · **Nulo** = admite `NULL`.

---

## Rol

Tipos de usuario del sistema.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdRol | INT | No | | PK | Identificador del rol |
| Nombre | VARCHAR(50) | No | | UQ | Nombre del rol (Administrador, Vendedor) |
| Descripcion | VARCHAR(200) | Sí | | | Descripción de las responsabilidades del rol |

## Usuario

Personas del local que operan el sistema.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdUsuario | INT | No | | PK | Identificador del usuario |
| IdRol | INT | No | | FK → Rol | Rol asignado |
| NombreUsuario | VARCHAR(50) | No | | UQ | Nombre de acceso |
| Email | VARCHAR(100) | No | | UQ | Correo electrónico |
| Contrasena | VARCHAR(255) | No | | | Contraseña de acceso (dato sensible) |
| Nombre | VARCHAR(50) | No | | | Nombre de la persona |
| Apellido | VARCHAR(50) | No | | | Apellido de la persona |
| Activo | INT | No | 1 | `IN (0, 1)` | 1 = activo, 0 = dado de baja |
| FechaAlta | DATETIME | No | `GETDATE()` | | Fecha de alta en el sistema |

## Categoria

Tipo de prenda.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdCategoria | INT | No | | PK | Identificador de la categoría |
| Nombre | VARCHAR(50) | No | | UQ | Nombre (Remeras, Buzos, Pantalones...) |
| Descripcion | VARCHAR(200) | Sí | | | Descripción de la categoría |

## Marca

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdMarca | INT | No | | PK | Identificador de la marca |
| Nombre | VARCHAR(50) | No | | UQ | Nombre de la marca |

## Segmento

Público al que está dirigida una variante.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdSegmento | INT | No | | PK | Identificador del segmento |
| Nombre | VARCHAR(50) | No | | UQ | Hombre, Mujer, Niño, Niña, Unisex |

## Talle

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdTalle | INT | No | | PK | Identificador del talle |
| Descripcion | VARCHAR(10) | No | | UQ | Talle (S, M, L, XL, 38, 40...) |

## Color

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdColor | INT | No | | PK | Identificador del color |
| Nombre | VARCHAR(30) | No | | UQ | Nombre del color |

## Producto

Prenda del catálogo, independiente de su talle, color y segmento.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdProducto | INT | No | | PK | Identificador del producto |
| IdCategoria | INT | No | | FK → Categoria | Categoría del producto |
| IdMarca | INT | No | | FK → Marca | Marca del producto |
| Nombre | VARCHAR(100) | No | | | Nombre comercial |
| Descripcion | VARCHAR(500) | Sí | | | Descripción detallada |
| PrecioBase | DECIMAL(12,2) | No | | `>= 0` | Precio de referencia del producto |
| Activo | INT | No | 1 | `IN (0, 1)` | 1 = a la venta, 0 = dado de baja |

## VarianteProducto

Combinación concreta de producto, segmento, talle y color que se vende y se stockea.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdVariante | INT | No | | PK | Identificador de la variante |
| IdProducto | INT | No | | FK → Producto; UQ (combinación) | Producto al que pertenece |
| IdSegmento | INT | No | | FK → Segmento; UQ (combinación) | Público destinatario |
| IdTalle | INT | No | | FK → Talle; UQ (combinación) | Talle |
| IdColor | INT | No | | FK → Color; UQ (combinación) | Color |
| SKU | VARCHAR(30) | No | | UQ | Código único de la variante |
| PrecioVenta | DECIMAL(12,2) | No | | `>= 0` | Precio de venta actual |
| StockActual | INT | No | 0 | `>= 0` | Unidades disponibles. Lo mantienen los triggers de venta, anulación, recepción de compra y ajuste |
| StockMinimo | INT | No | 0 | `>= 0` | Umbral para generar alertas de reposición |

## Proveedor

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdProveedor | INT | No | | PK | Identificador del proveedor |
| RazonSocial | VARCHAR(100) | No | | | Nombre legal de la empresa |
| CUIT | VARCHAR(13) | No | | UQ | CUIT con guiones (XX-XXXXXXXX-X) |
| Telefono | VARCHAR(20) | Sí | | | Teléfono de contacto |
| Email | VARCHAR(100) | Sí | | | Correo electrónico |
| Direccion | VARCHAR(150) | Sí | | | Dirección |

## Compra

Cabecera de un pedido de mercadería a un proveedor.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdCompra | INT | No | | PK | Identificador de la compra |
| IdProveedor | INT | No | | FK → Proveedor | Proveedor |
| IdUsuario | INT | No | | FK → Usuario | Usuario que registró la compra |
| Fecha | DATETIME | No | `GETDATE()` | | Fecha de la compra |
| NroComprobante | VARCHAR(30) | Sí | | | Número de factura o remito del proveedor |
| Total | DECIMAL(12,2) | No | 0 | `>= 0` | Suma de las líneas. Lo calcula `SP_RegistrarCompra` |
| Estado | VARCHAR(20) | No | `'PENDIENTE'` | `IN ('PENDIENTE', 'RECIBIDA', 'ANULADA')` | Estado del pedido |

## DetalleCompra

Líneas de una compra (entidad dependiente de `Compra`).

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdCompra | INT | No | | PK; FK → Compra; UQ (con IdVariante) | Compra a la que pertenece |
| NroLinea | INT | No | | PK | Número de línea dentro de la compra |
| IdVariante | INT | No | | FK → VarianteProducto; UQ (con IdCompra) | Variante comprada |
| Cantidad | INT | No | | `> 0` | Unidades compradas |
| CostoUnitario | DECIMAL(12,2) | No | | `>= 0` | Costo por unidad |

## Cliente

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdCliente | INT | No | | PK | Identificador del cliente |
| Nombre | VARCHAR(50) | No | | | Nombre |
| Apellido | VARCHAR(50) | No | | | Apellido |
| DNI | VARCHAR(10) | No | | UQ | Documento (dato personal) |
| Email | VARCHAR(100) | Sí | | | Correo electrónico (dato personal) |
| Telefono | VARCHAR(20) | Sí | | | Teléfono (dato personal) |
| Direccion | VARCHAR(150) | Sí | | | Dirección (dato personal) |

## Venta

Cabecera de una venta.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdVenta | INT | No | | PK | Identificador de la venta |
| IdCliente | INT | Sí | | FK → Cliente | Cliente. `NULL` = consumidor final |
| IdUsuario | INT | No | | FK → Usuario | Vendedor que registró la venta |
| Fecha | DATETIME | No | `GETDATE()` | | Fecha y hora de la venta |
| MedioPago | VARCHAR(20) | No | | `IN ('EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA')` | Forma de pago |
| Total | DECIMAL(12,2) | No | 0 | `>= 0` | Suma de las líneas menos descuentos. Lo calculan `SP_RegistrarVenta` y `TR_CalcularTotalVenta` |
| Estado | VARCHAR(20) | No | `'CONFIRMADA'` | `IN ('CONFIRMADA', 'ANULADA')` | Estado de la venta |

## DetalleVenta

Líneas de una venta (entidad dependiente de `Venta`).

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdVenta | INT | No | | PK; FK → Venta; UQ (con IdVariante) | Venta a la que pertenece |
| NroLinea | INT | No | | PK | Número de línea dentro de la venta |
| IdVariante | INT | No | | FK → VarianteProducto; UQ (con IdVenta) | Variante vendida |
| Cantidad | INT | No | | `> 0` | Unidades vendidas |
| PrecioUnitario | DECIMAL(12,2) | No | | `>= 0` | Precio al momento de la venta |
| Descuento | DECIMAL(12,2) | No | 0 | `>= 0` y `<= Cantidad × PrecioUnitario` | Descuento total de la línea, en pesos |

## MovimientoStock

Historial de todos los cambios de stock. Es la fuente de verdad del inventario.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdMovimiento | INT | No | | PK | Identificador del movimiento |
| IdVariante | INT | No | | FK → VarianteProducto | Variante afectada |
| IdUsuario | INT | No | | FK → Usuario | Usuario responsable |
| Fecha | DATETIME | No | `GETDATE()` | | Fecha y hora del movimiento |
| TipoMovimiento | VARCHAR(20) | No | | `IN ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION')` | Tipo de movimiento |
| Cantidad | INT | No | | `AJUSTE`: `<> 0`; resto: `> 0` | Unidades. En los ajustes lleva signo (negativo = faltante) |
| IdCompra | INT | Sí | | FK → Compra | Compra de origen (`ENTRADA`; hoy no se genera) |
| IdVenta | INT | Sí | | FK → Venta | Venta de origen (`SALIDA` o `DEVOLUCION`; hoy no se genera) |
| Observacion | VARCHAR(200) | Sí | | | Detalle o motivo |

Restricción adicional: `CK_Mov_Origen` impide que un movimiento tenga `IdCompra` e `IdVenta` a la vez.

## HistorialPrecio

Auditoría de cambios de precio. La carga el trigger `TR_HistorialPrecio`.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdHistorial | INT | No | `IDENTITY(1,1)` | PK | Identificador del registro |
| IdVariante | INT | No | | FK → VarianteProducto | Variante cuyo precio cambió |
| PrecioAnterior | DECIMAL(12,2) | No | | | Precio antes del cambio |
| PrecioNuevo | DECIMAL(12,2) | No | | | Precio después del cambio |
| Fecha | DATETIME | No | `GETDATE()` | | Fecha del cambio |

## AlertaStock

Alertas de reposición. Las carga el trigger `TR_AvisoStockMinimo`.

| Columna | Tipo | Nulo | Default | Restricciones | Descripción |
|---|---|---|---|---|---|
| IdAlerta | INT | No | `IDENTITY(1,1)` | PK | Identificador de la alerta |
| IdVariante | INT | No | | FK → VarianteProducto | Variante con stock bajo |
| StockActual | INT | No | | | Stock al momento de la alerta |
| StockMinimo | INT | No | | | Mínimo vigente al momento de la alerta |
| Fecha | DATETIME | No | `GETDATE()` | | Fecha de la alerta |
| Atendida | INT | No | 0 | `IN (0, 1)` | 0 = pendiente, 1 = atendida |

---

## Tipo de tabla: TipoDetalleVenta

Script: `sql/sp/SPs.sql`. Es el parámetro con el que `SP_RegistrarVenta` recibe las líneas de la venta.

| Columna | Tipo | Nulo | Default | Descripción |
|---|---|---|---|---|
| IdVariante | INT | No | | Variante a vender |
| Cantidad | INT | No | | Unidades |
| PrecioUnitario | DECIMAL(12,2) | No | | Precio por unidad |
| Descuento | DECIMAL(12,2) | No | 0 | Descuento de la línea, en pesos |
