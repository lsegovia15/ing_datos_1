# SIAM – Documentación técnica de la base de datos

Motor: SQL Server (T-SQL). Base: `SIAM`. Los scripts están en `sql/`; `00_master.sql` los ejecuta en orden con `sqlcmd` (modo SQLCMD, `:r`).

## 1. Resumen del esquema

SIAM gestiona el inventario, las ventas y las compras de un comercio de indumentaria. El stock se lleva por variante (producto + segmento + talle + color), no por producto.

Flujos principales:

- **Venta:** `SP_RegistrarVenta` crea la cabecera y una línea de detalle; los triggers descuentan stock y recalculan el total.
- **Anulación:** `SP_AnularVenta` pasa la venta a `ANULADA`; un trigger devuelve el stock.
- **Compra:** `SP_RegistrarCompra` deja la compra en `PENDIENTE`; `SP_RecibirCompra` la pasa a `RECIBIDA` y un trigger suma el stock.
- **Ajuste manual:** `SP_AjustarStock` inserta un `MovimientoStock` tipo `AJUSTE` con la diferencia firmada.
- **Seguridad:** dos roles de BD (`rol_administrador`, `rol_vendedor`) con permisos otorgados por `GRANT`. Los SPs validan además el rol de negocio (`Rol.Nombre`) del `@IdUsuario` recibido.

Orden de ejecución (`00_master.sql`): `init_db` → `siam_triggers` → `funciones` → `vistas` → `sp/SPs` → `sp/SP_*` → `cursores` → `seed_data` → `seguridad`.

`init_db.sql` **dropea y recrea la base `SIAM`** (`SINGLE_USER WITH ROLLBACK IMMEDIATE`). No correrlo contra datos que se quieran conservar.

Las PK no son `IDENTITY` (salvo `AlertaStock` y `HistorialPrecio`): los IDs se generan en los SPs con `ISNULL(MAX(Id), 0) + 1`, **sin** `UPDLOCK` ni `HOLDLOCK`.

## 2. Diccionario de datos

### 2.1 Catálogo y usuarios

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `Rol` | Roles de negocio (`Administrador`, `Vendedor`). | `IdRol` | `Nombre` único. |
| `Usuario` | Usuarios del sistema. | `IdUsuario` | FK `IdRol → Rol`. `NombreUsuario` y `Email` únicos. `Activo IN (0,1)`. Guarda `Contrasena` (VARCHAR 255) como hash SHA-256 sin sal. |
| `Categoria` | Tipo de prenda. | `IdCategoria` | `Nombre` único. |
| `Marca` | Marca del producto. | `IdMarca` | `Nombre` único. |
| `Segmento` | Público de la variante (Hombre, Mujer, Niño, Niña, Unisex). | `IdSegmento` | `Nombre` único. |
| `Talle` | Talles. | `IdTalle` | `Descripcion` única. |
| `Color` | Colores. | `IdColor` | `Nombre` único. |
| `Producto` | Artículo base. | `IdProducto` | FK `IdCategoria → Categoria`, `IdMarca → Marca`. `PrecioBase >= 0`. `Activo IN (0,1)`. |
| `VarianteProducto` | Unidad de stock y de venta. | `IdVariante` | FK `IdProducto`, `IdSegmento`, `IdTalle`, `IdColor`. `SKU` único. Combinación `(IdProducto, IdSegmento, IdTalle, IdColor)` única. `PrecioVenta >= 0`, `StockActual >= 0`, `StockMinimo >= 0`. |

### 2.2 Compras

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `Proveedor` | Proveedores. | `IdProveedor` | `CUIT` único. |
| `Compra` | Cabecera de compra. | `IdCompra` | FK `IdProveedor`, `IdUsuario`. `Estado IN ('PENDIENTE','RECIBIDA','ANULADA')`, default `PENDIENTE`. `Total >= 0`. |
| `DetalleCompra` | Líneas de compra. | `(IdCompra, NroLinea)` | FK `IdCompra → Compra` (`ON DELETE CASCADE`), `IdVariante → VarianteProducto`. `(IdCompra, IdVariante)` único. `Cantidad > 0`, `CostoUnitario >= 0`. |

### 2.3 Ventas

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `Cliente` | Clientes. | `IdCliente` | `DNI` único. |
| `Venta` | Cabecera de venta. | `IdVenta` | FK `IdCliente → Cliente` (nullable, `ON DELETE SET NULL`; null = consumidor final), `IdUsuario → Usuario`. `MedioPago IN ('EFECTIVO','DEBITO','CREDITO','TRANSFERENCIA')`. `Estado IN ('CONFIRMADA','ANULADA')`, default `CONFIRMADA`. |
| `DetalleVenta` | Líneas de venta. | `(IdVenta, NroLinea)` | FK `IdVenta → Venta` (`ON DELETE CASCADE`), `IdVariante → VarianteProducto`. `(IdVenta, IdVariante)` único. `Cantidad > 0`. `Descuento` entre 0 y `Cantidad * PrecioUnitario` (importe, no porcentaje). |

### 2.4 Inventario y auditoría

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `MovimientoStock` | Registro de movimientos de stock. En la práctica solo guarda los ajustes manuales. | `IdMovimiento` | FK `IdVariante`, `IdUsuario`; `IdCompra` y `IdVenta` nullables (`ON DELETE SET NULL`). `TipoMovimiento IN ('ENTRADA','SALIDA','AJUSTE','DEVOLUCION')`. `AJUSTE` exige `Cantidad <> 0` (con signo); el resto `Cantidad > 0`. No puede tener `IdCompra` e `IdVenta` a la vez. |
| `AlertaStock` | Alertas por stock bajo el mínimo (creada en `siam_triggers.sql`). | `IdAlerta` (IDENTITY) | FK `IdVariante`. `Atendida IN (0,1)`. |
| `HistorialPrecio` | Cambios de `PrecioVenta` (creada en `siam_triggers.sql`). | `IdHistorial` (IDENTITY) | FK `IdVariante`. |

### 2.5 Índices

Un índice por cada FK (`IX_<Tabla>_Id<Ref>`) más: `IX_Producto_Nombre`, `IX_Cliente_Apellido_Nombre`, `IX_Compra_Fecha`, `IX_Venta_Fecha`, `IX_Mov_Fecha`.

## 3. Lógica de negocio y programabilidad

### 3.1 Stored procedures

Todos siguen la misma estructura: `BEGIN TRY`, validaciones, `BEGIN TRANSACTION` → `COMMIT`, un `SELECT` final con el resultado y `BEGIN CATCH` con `ROLLBACK` si hay transacción abierta y `THROW;`.

No usan `SET NOCOUNT ON` ni `SET XACT_ABORT ON`. Las validaciones de negocio no lanzan excepciones: ejecutan `PRINT` con el mensaje y `RETURN`, sin resultset y sin código de error. Quien llama debe verificar el estado o los conteos después de ejecutar el SP.

Cada SP que registra una venta o una compra inserta **una sola línea** de detalle, siempre con `NroLinea = 1`. Las operaciones de varias líneas se completan insertando el resto directamente sobre el detalle.

#### `SP_RegistrarVenta`

Parámetros: `@IdCliente INT = NULL`, `@IdUsuario INT`, `@MedioPago VARCHAR(20)`, `@IdVariante INT`, `@Cantidad INT`, `@PrecioUnitario DECIMAL(12,2)`, `@Descuento DECIMAL(12,2) = 0`.

Qué hace:
1. Valida usuario activo con rol `Administrador` o `Vendedor`, cliente existente (si viene), variante existente y stock suficiente. Cada rechazo hace `PRINT` + `RETURN`.
2. Calcula `Total = Cantidad * PrecioUnitario - Descuento`.
3. En transacción: genera `IdVenta` (`MAX+1` sin bloqueo), inserta `Venta` en `CONFIRMADA` e inserta `DetalleVenta` con `NroLinea = 1`.
4. `TR_DescontarStockVenta` descuenta el stock (y lanza `50001` si no alcanza) y `TR_CalcularTotalVenta` recalcula el total.

Devuelve `IdVentaGenerada`, `TotalVenta`, `Mensaje`.

No valida explícitamente que `@Cantidad` sea mayor a cero, que `@PrecioUnitario` no sea negativo, que el descuento no supere el importe de la línea ni que `@MedioPago` sea uno de los valores permitidos: esas condiciones quedan a cargo de los `CHECK` de `DetalleVenta` y `Venta`.

#### `SP_AnularVenta`

Parámetros: `@IdVenta INT`, `@IdUsuario INT`.

Qué hace:
1. Valida que el usuario exista y sea `Administrador` activo.
2. Lee `Venta.Estado`. Falla con `PRINT` + `RETURN` si no existe, si ya está `ANULADA` o si no está `CONFIRMADA`.
3. En transacción: `UPDATE Venta SET Estado = 'ANULADA'` y `COMMIT`.

La devolución de stock la hace `TR_DevolverStockAnulacion` (ver 3.2). No usa `UPDLOCK`/`HOLDLOCK` ni una segunda comprobación de estado en el `UPDATE`.

Devuelve `IdVentaAnulada`, `Mensaje`.

#### `SP_RegistrarCompra`

Parámetros: `@IdProveedor INT`, `@IdUsuario INT`, `@IdVariante INT`, `@Cantidad INT`, `@CostoUnitario DECIMAL(12,2)`, `@NroComprobante VARCHAR(30) = NULL`.

Qué hace:
1. Valida cantidad > 0, costo >= 0, proveedor existente, usuario activo y `Administrador`, y variante existente. Cada rechazo hace `PRINT` + `RETURN`.
2. Calcula `Total = Cantidad * CostoUnitario`.
3. En transacción: genera `IdCompra` (`MAX+1` sin bloqueo), inserta `Compra` en `PENDIENTE` y su `DetalleCompra` con `NroLinea = 1`.

No modifica stock. Devuelve `IdCompraGenerada`, `TotalCompra`, `Mensaje`.

#### `SP_RecibirCompra`

Parámetros: `@IdCompra INT`, `@IdUsuario INT`.

Qué hace:
1. Valida usuario activo y `Administrador`.
2. Lee `Compra.Estado`. Falla con `PRINT` + `RETURN` si la compra no existe, si no está `PENDIENTE` o si no tiene líneas de detalle.
3. En transacción: `UPDATE Compra SET Estado = 'RECIBIDA'` y `COMMIT`.

El stock lo suma `TR_SumarStockCompra` (ver 3.2). No usa `UPDLOCK`/`HOLDLOCK` ni una segunda comprobación de estado en el `UPDATE`.

Devuelve `IdCompraRecibida`, `Mensaje`.

#### `SP_AjustarStock`

Parámetros: `@IdVariante INT`, `@NuevaCantidad INT`, `@IdUsuario INT`, `@Observacion VARCHAR(200) = 'Ajuste manual de inventario'`.

Qué hace:
1. Valida `@NuevaCantidad >= 0`, usuario activo y `Administrador`, y que la variante exista. Cada rechazo hace `PRINT` + `RETURN`.
2. Lee `StockActual` y calcula `Diferencia = NuevaCantidad - StockActual`.
3. Si la diferencia es 0, devuelve "No hubo diferencia" sin abrir transacción ni registrar nada.
4. Si no, en transacción: genera `IdMovimiento` (`MAX+1` sin bloqueo) e inserta un `MovimientoStock` tipo `AJUSTE` con la diferencia con signo. `TR_AplicarAjusteStock` aplica el cambio a `VarianteProducto.StockActual`.

La lectura de `StockActual` no está bloqueada: una venta concurrente puede modificarlo entre la lectura y el ajuste.

Devuelve `IdVariante`, `StockAnterior`, `StockNuevo`, `Diferencia`, `Mensaje`.

#### `SP_InformeReposicionStock` (`cursores.sql`)

Sin parámetros. Recorre con un cursor `LOCAL FAST_FORWARD` las variantes de productos activos con `StockActual <= StockMinimo` y, por cada una:
- `Objetivo = 1` si `StockMinimo = 0`; si no, `StockMinimo * 2`.
- `CantidadSugerida = Objetivo - StockActual`.
- `Prioridad = 'URGENTE'` si `StockActual = 0`, si no `'NORMAL'`.

Acumula en una tabla variable y devuelve el informe con las `URGENTE` primero, luego por `IdVariante`. En el `CATCH` cierra y libera el cursor y relanza el error.

### 3.2 Triggers (`siam_triggers.sql`)

| Trigger | Tabla / evento | Qué hace |
|---|---|---|
| `TR_DescontarStockVenta` | `DetalleVenta` AFTER INSERT | Si alguna línea supera el `StockActual`, lanza `THROW 50001` (cancela el insert). Si no, descuenta `Cantidad` de `VarianteProducto.StockActual`. |
| `TR_CalcularTotalVenta` | `DetalleVenta` AFTER INSERT | Recalcula `Venta.Total = SUM(Cantidad * PrecioUnitario - Descuento)` de las ventas afectadas. |
| `TR_DevolverStockAnulacion` | `Venta` AFTER UPDATE | Para ventas que pasan de `CONFIRMADA` a `ANULADA`, suma al stock las cantidades de sus líneas. No inserta `MovimientoStock`. |
| `TR_SumarStockCompra` | `Compra` AFTER UPDATE | Para compras que pasan de `PENDIENTE` a `RECIBIDA`, suma al stock las cantidades de sus líneas. No inserta `MovimientoStock`. |
| `TR_AvisoStockMinimo` | `VarianteProducto` AFTER UPDATE | Inserta en `AlertaStock` cuando una variante cruza el mínimo (antes `StockActual > StockMinimo`, ahora `<=`). Imprime un aviso. |
| `TR_HistorialPrecio` | `VarianteProducto` AFTER UPDATE | Inserta en `HistorialPrecio` (precio anterior y nuevo) cuando cambia `PrecioVenta`. |
| `TR_NoBorrarVenta` | `Venta` INSTEAD OF DELETE | Reemplaza el `DELETE` por un `PRINT`: no borra nada y no devuelve error. |
| `TR_AplicarAjusteStock` | `MovimientoStock` AFTER INSERT | Para movimientos `AJUSTE`, suma `Cantidad` (con signo) al stock de la variante. Los otros tipos no los toca. |

### 3.3 Funciones (`funciones.sql`)

| Función | Parámetros | Devuelve |
|---|---|---|
| `dbo.fn_EstadoStock` (escalar) | `@IdVariante INT` | `VARCHAR(20)`: `INACTIVO` (producto inactivo), `SIN STOCK` (stock 0), `BAJO STOCK` (stock <= mínimo), `STOCK SUFICIENTE`. `NULL` si la variante no existe. |
| `dbo.fn_ResumenVentasPorUsuario` (tabla inline) | `@FechaDesde DATE`, `@FechaHasta DATE` | Por usuario: `IdUsuario`, `NombreUsuario`, `CantidadVentas`, `TotalVendido`. Solo ventas `CONFIRMADA`; el rango incluye todo el día de `@FechaHasta`. |

### 3.4 Vistas (`vistas.sql`)

| Vista | Contenido |
|---|---|
| `vw_StockVariante` | Variante con producto, marca, categoría, segmento, talle, color, SKU, precio, stock y `EstadoStock`. Solo productos activos. |
| `vw_VentasDetalladas` | Venta con cliente (`Consumidor Final` si es null), vendedor, medio de pago, estado y total. |
| `vw_ProductosPremium` | Productos activos con `PrecioBase` mayor al promedio de los activos. |
| `vw_CategoriasMasVendidasPorSegmento` | Categoría con más unidades vendidas por segmento, calculada con `GROUP BY` + `HAVING` y una subconsulta correlacionada que compara contra el máximo de unidades por categoría del mismo segmento. Solo ventas `CONFIRMADA`. |

La cuarta vista puede devolver más de una fila por segmento si dos categorías empatan en unidades vendidas: no usa `RANK()` ni desempata por monto.

### 3.5 Consultas de ejemplo

- `Subconsultas.sql`: clientes que compraron la categoría `Buzos` (`IN`), productos sin ventas (`NOT EXISTS`), variantes más caras que todos los productos de la marca `Nangallery` (`> ALL`).
- `sp/ConsultasAvanzadas.sql`: `UNION` de ventas y compras, ranking de vendedores (`GROUP BY` + `HAVING`), ventas por mes y medio de pago, subconsultas `EXISTS`/`IN`/`ALL` y subconsultas correlacionadas.

Son scripts de consulta, no objetos de la base. No están en `00_master.sql`.

### 3.6 Seguridad (`seguridad.sql`)

Crea los logins `login_admin_siam` y `login_vendedor_siam` (con contraseñas fijas en el script, hay que cambiarlas fuera del entorno de práctica), los usuarios `usr_admin` y `usr_vendedor`, y los roles `rol_administrador` y `rol_vendedor`.

El script no es idempotente: `CREATE LOGIN` y `CREATE ROLE` fallan si el objeto ya existe. `init_db.sql` solo dropea la base, no los logins del servidor, así que una segunda ejecución del master falla en este script salvo que se borren los logins o se adapte el archivo.

| | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Catálogo y maestros | `SELECT/INSERT/UPDATE/DELETE` sobre `Rol`, `Usuario`, `Categoria`, `Segmento`, `Marca`, `Talle`, `Color`, `Producto`, `Proveedor`, `Cliente`, `VarianteProducto` | Solo `SELECT` sobre `Producto`, `VarianteProducto`, `Categoria`, `Marca`, `Talle`, `Color`, `Segmento` y `Cliente` |
| Compras | `SELECT/INSERT/UPDATE/DELETE` sobre `Compra` y `DetalleCompra` | Sin acceso |
| Ventas | Solo `SELECT` sobre `Venta` y `DetalleVenta` | Sin acceso a las tablas; opera mediante `SP_RegistrarVenta` |
| `MovimientoStock` | Solo `SELECT` | Sin acceso |
| Vistas | `SELECT` sobre `vw_StockVariante`, `vw_VentasDetalladas`, `vw_ProductosPremium` | Las mismas tres vistas |
| SPs | `EXECUTE` sobre los cinco SPs de operación y `SP_InformeReposicionStock` | `EXECUTE` sobre `SP_RegistrarVenta` y `SP_InformeReposicionStock` |
| Funciones | `EXECUTE` sobre `fn_EstadoStock` y `SELECT` sobre `fn_ResumenVentasPorUsuario` | `EXECUTE` sobre `fn_EstadoStock` |

No se usa `DENY` ni `REVOKE`: los permisos del vendedor son simplemente los que se le otorgan. Tampoco se protege la columna `Usuario.Contrasena`.

La regla de rol de negocio (`Usuario.IdRol`) se valida dentro de los SPs; los permisos de BD se aplican al login que ejecuta.

## 4. Notas

1. **Movimientos de stock.** Solo `SP_AjustarStock` escribe en `MovimientoStock`. Ventas, anulaciones y recepciones modifican `StockActual` directo desde los triggers y no dejan movimiento. El `CHECK` de la tabla admite `ENTRADA`, `SALIDA` y `DEVOLUCION`, pero ningún objeto los inserta.
2. **Sin contexto de sesión.** Ningún SP usa `SESSION_CONTEXT` ni otra marca de sesión. Los triggers trabajan solo con las tablas `inserted` y `deleted`.
3. **Código 50001.** Lo usa únicamente `TR_DescontarStockVenta` para rechazar una venta sin stock. Es el único error lanzado con `THROW` en la lógica de negocio.
4. **`TR_NoBorrarVenta` no lanza error.** Un `DELETE` sobre `Venta` termina sin borrar y solo imprime un mensaje. El administrador tampoco tiene permiso `DELETE` sobre `Venta` ni `DetalleVenta`, así que un borrado directo falla por permisos antes de llegar al trigger. No hay trigger equivalente para `Compra`: el administrador sí puede borrar compras y sus detalles en cascada.
5. **No se valida** que el producto esté activo al vender ni que una venta anulada no pueda reactivarse con un `UPDATE` directo.
6. **`00_master.sql`** usa `\` como separador de rutas en `:r`, por lo que solo funciona en Windows. No incluye `Subconsultas.sql` ni `ConsultasAvanzadas.sql`.
