# SIAM – Documentación técnica de la base de datos

Motor: SQL Server (T-SQL). Base: `SIAM`. Los scripts están en `sql/`; `00_master.sql` los ejecuta en orden con `sqlcmd` (modo SQLCMD, `:r`).

## 1. Resumen del esquema

SIAM gestiona el inventario, las ventas y las compras de un comercio de indumentaria. El stock se lleva por variante (producto + segmento + talle + color), no por producto.

Flujos principales:

- **Venta:** `SP_RegistrarVenta` registra la venta de un producto (cabecera y una línea); los triggers descuentan stock y calculan el total.
- **Anulación:** `SP_AnularVenta` pasa la venta a `ANULADA`; un trigger devuelve el stock.
- **Compra:** `SP_RegistrarCompra` registra la compra de un producto en `PENDIENTE`; `SP_RecibirCompra` la pasa a `RECIBIDA` y un trigger suma el stock.
- **Ajuste manual:** `SP_AjustarStock` inserta un `MovimientoStock` tipo `AJUSTE` con la diferencia firmada.
- **Seguridad:** dos roles de BD (`rol_administrador`, `rol_vendedor`), con permisos otorgados solo con `GRANT`. Los SPs validan además el rol de negocio (`Rol.Nombre`) del `@IdUsuario` recibido.

Orden de ejecución (`00_master.sql`): `init_db` → `siam_triggers` → `funciones` → `vistas` → `sp/SP_*` → `cursores` → `seed_data` → `seguridad`.

`init_db.sql` **borra y recrea la base `SIAM`** (`DROP DATABASE IF EXISTS`). No correrlo contra datos que se quieran conservar.

Las PK no son `IDENTITY` (salvo `AlertaStock` y `HistorialPrecio`): los IDs se generan en los SPs con `MAX(Id)+1` dentro de la transacción.

## 2. Diccionario de datos

### 2.1 Catálogo y usuarios

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `Rol` | Roles de negocio (`Administrador`, `Vendedor`). | `IdRol` | `Nombre` único. |
| `Usuario` | Usuarios del sistema. | `IdUsuario` | FK `IdRol → Rol`. `NombreUsuario` y `Email` únicos. `Activo IN (0,1)`. Guarda `Contrasena` como hash SHA-256 en hexadecimal (VARCHAR 255). |
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
| `DetalleCompra` | Líneas de compra. | `(IdCompra, NroLinea)` | FK `IdCompra → Compra`, `IdVariante → VarianteProducto`. `(IdCompra, IdVariante)` único. `Cantidad > 0`, `CostoUnitario >= 0`. |

### 2.3 Ventas

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `Cliente` | Clientes. | `IdCliente` | `DNI` único. |
| `Venta` | Cabecera de venta. | `IdVenta` | FK `IdCliente → Cliente` (nullable; null = consumidor final), `IdUsuario → Usuario`. `MedioPago IN ('EFECTIVO','DEBITO','CREDITO','TRANSFERENCIA')`. `Estado IN ('CONFIRMADA','ANULADA')`, default `CONFIRMADA`. |
| `DetalleVenta` | Líneas de venta. | `(IdVenta, NroLinea)` | FK `IdVenta → Venta`, `IdVariante → VarianteProducto`. `(IdVenta, IdVariante)` único. `Cantidad > 0`. `Descuento` entre 0 y `Cantidad * PrecioUnitario` (importe, no porcentaje). |

### 2.4 Inventario y auditoría

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `MovimientoStock` | Historial de movimientos de stock. | `IdMovimiento` | FK `IdVariante`, `IdUsuario`; `IdCompra` y `IdVenta` nullables. `TipoMovimiento IN ('ENTRADA','SALIDA','AJUSTE','DEVOLUCION')`. `AJUSTE` exige `Cantidad <> 0` (con signo); el resto `Cantidad > 0`. No puede tener `IdCompra` e `IdVenta` a la vez. |
| `AlertaStock` | Alertas por stock bajo el mínimo (creada en `siam_triggers.sql`). | `IdAlerta` (IDENTITY) | FK `IdVariante`. `Atendida IN (0,1)`. |
| `HistorialPrecio` | Cambios de `PrecioVenta` (creada en `siam_triggers.sql`). | `IdHistorial` (IDENTITY) | FK `IdVariante`. |

Todas las FK usan el comportamiento por defecto (`NO ACTION`).

### 2.5 Índices

Un índice (`IX_<Tabla>_Id<Ref>`) por cada FK que no queda cubierta por una PK o una restricción `UNIQUE`, más: `IX_Producto_Nombre`, `IX_Cliente_Apellido_Nombre`, `IX_Compra_Fecha`, `IX_Venta_Fecha`, `IX_Mov_Fecha`.

## 3. Lógica de negocio y programabilidad

### 3.1 Stored procedures

Todos usan `SET NOCOUNT ON`, `TRY/CATCH`, `BEGIN TRANSACTION`/`COMMIT`, `ROLLBACK` en el `CATCH` si hay transacción abierta (`@@TRANCOUNT > 0`) y `THROW;` para devolver el error. Las validaciones lanzan `THROW` con un código propio. Devuelven un resultset de una fila con el resultado y un `Mensaje`. Cada venta y cada compra es de un producto.

| SP | Parámetros | Qué hace | Errores |
|---|---|---|---|
| `SP_RegistrarVenta` | `@IdCliente = NULL`, `@IdUsuario`, `@MedioPago`, `@IdVariante`, `@Cantidad`, `@Descuento = 0` | Valida, toma el precio de `VarianteProducto`, inserta `Venta` (`CONFIRMADA`) y una línea en `DetalleVenta`. Los triggers descuentan stock y calculan el total. | 50001 cantidad, 50002 usuario, 50003 cliente, 50004 medio de pago, 50005 variante, 50006 stock, 50007 rol, 50008 descuento |
| `SP_AnularVenta` | `@IdVenta`, `@IdUsuario` | Pasa una venta `CONFIRMADA` a `ANULADA`; el trigger devuelve el stock. | 50010 no existe, 50011 ya anulada, 50012 usuario, 50013 rol |
| `SP_AjustarStock` | `@IdVariante`, `@NuevaCantidad`, `@IdUsuario`, `@Observacion` | Inserta un `AJUSTE` con la diferencia; el trigger la aplica. Sin diferencia no registra nada. | 50020 cantidad, 50021 usuario, 50022 variante, 50023 rol |
| `SP_RegistrarCompra` | `@IdProveedor`, `@IdUsuario`, `@IdVariante`, `@Cantidad`, `@CostoUnitario`, `@NroComprobante = NULL` | Inserta `Compra` (`PENDIENTE`) y una línea en `DetalleCompra`. No mueve stock. | 50101 proveedor, 50102 usuario, 50104 cantidad, 50105 costo, 50106 variante, 50107 rol |
| `SP_RecibirCompra` | `@IdCompra`, `@IdUsuario` | Pasa una compra `PENDIENTE` a `RECIBIDA`; el trigger suma el stock. | 50110 no existe, 50111 sin líneas, 50112 no pendiente, 50113 usuario, 50114 rol |

#### `SP_InformeReposicionStock` (`cursores.sql`)

Sin parámetros. Recorre con un cursor las variantes de productos activos con `StockActual <= StockMinimo` y, por cada una, calcula el objetivo (doble del mínimo, o 1 si el mínimo es 0), la cantidad sugerida y la prioridad (`URGENTE` si el stock es 0, si no `NORMAL`), y muestra un mensaje con `PRINT`. Al empezar verifica con `CURSOR_STATUS` si quedó un cursor abierto de una ejecución anterior; al terminar hace `CLOSE` y `DEALLOCATE`.

### 3.2 Triggers (`siam_triggers.sql`)

| Trigger | Tabla / evento | Qué hace |
|---|---|---|
| `TR_DescontarStockVenta` | `DetalleVenta` AFTER INSERT | Si alguna línea supera el `StockActual`, lanza 50200 (cancela el insert). Si no, descuenta la cantidad (agrupada por variante) de `VarianteProducto.StockActual`. |
| `TR_CalcularTotalVenta` | `DetalleVenta` AFTER INSERT | Recalcula `Venta.Total = SUM(Cantidad * PrecioUnitario - Descuento)` de las ventas afectadas. |
| `TR_DevolverStockAnulacion` | `Venta` AFTER UPDATE | Para ventas que pasan de `CONFIRMADA` a `ANULADA`, suma al stock las cantidades de sus líneas. No inserta `MovimientoStock`. |
| `TR_SumarStockCompra` | `Compra` AFTER UPDATE | Para compras que pasan de `PENDIENTE` a `RECIBIDA`, suma al stock las cantidades de sus líneas. No inserta `MovimientoStock`. |
| `TR_AvisoStockMinimo` | `VarianteProducto` AFTER UPDATE | Inserta en `AlertaStock` cuando una variante cruza el mínimo (antes `StockActual > StockMinimo`, ahora `<=`). Imprime un aviso. |
| `TR_HistorialPrecio` | `VarianteProducto` AFTER UPDATE | Inserta en `HistorialPrecio` (precio anterior y nuevo) cuando cambia `PrecioVenta`. |
| `TR_NoBorrarVenta` | `Venta` INSTEAD OF DELETE | Reemplaza el `DELETE`: no borra nada y lanza el error 50203. |
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
| `vw_CategoriasMasVendidasPorSegmento` | Categoría con más unidades vendidas por segmento (`HAVING` con subconsulta correlacionada que calcula el máximo del segmento). Solo ventas `CONFIRMADA`. |

### 3.5 Consultas de ejemplo

- `Subconsultas.sql`: clientes que compraron la categoría `Buzos` (`IN`), productos sin ventas (`NOT EXISTS`), variantes más caras que todos los productos de la marca `Nangallery` (`> ALL`).
- `sp/ConsultasAvanzadas.sql`: `UNION` de ventas y compras, ranking de vendedores (`GROUP BY` + `HAVING`), ventas por mes y medio de pago, subconsultas `EXISTS`/`IN`/`ALL` y subconsultas correlacionadas.

Son scripts de consulta, no objetos de la base. No están en `00_master.sql`.

### 3.6 Seguridad (`seguridad.sql`)

Crea los logins `login_admin_siam` y `login_vendedor_siam` (solo si no existen; contraseñas de ejemplo), los usuarios `usr_admin` y `usr_vendedor`, y los roles `rol_administrador` y `rol_vendedor`. Solo se usa `GRANT`: lo que no se otorga queda sin acceso.

| | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Catálogo y `Cliente` | `SELECT/INSERT/UPDATE/DELETE` | `SELECT` |
| `Proveedor`, `Rol` | `SELECT/INSERT/UPDATE/DELETE` | Sin acceso |
| `Usuario` | `SELECT` (todas las columnas salvo `Contrasena`) / `INSERT/UPDATE/DELETE` | Sin acceso |
| `VarianteProducto` | `SELECT/INSERT`; `UPDATE` solo de `PrecioVenta` y `StockMinimo` | `SELECT` |
| `Venta`, `DetalleVenta`, `Compra`, `DetalleCompra`, `MovimientoStock`, `HistorialPrecio` | `SELECT` (se operan solo por SP) | Sin acceso |
| `AlertaStock` | `SELECT/UPDATE` | Sin acceso |
| Vistas | `SELECT` | `SELECT` |
| SPs | `EXECUTE` en los 6 | `EXECUTE` en `SP_RegistrarVenta` y `SP_InformeReposicionStock` |
| Funciones | `fn_EstadoStock` (`EXECUTE`), `fn_ResumenVentasPorUsuario` (`SELECT`) | `fn_EstadoStock` |

La regla de rol de negocio (`Usuario.IdRol`) se valida dentro de los SPs; los permisos de BD se aplican al login que ejecuta.

## 4. Notas

1. **Movimientos de stock.** Solo `SP_AjustarStock` escribe en `MovimientoStock`. Ventas, anulaciones y recepciones modifican `StockActual` directo desde los triggers. El `CHECK` de la tabla admite `ENTRADA`, `SALIDA` y `DEVOLUCION`, pero ningún objeto los inserta.
2. **Códigos de triggers.** Los triggers usan el rango 50200–50299: 50200 sin stock, 50201 y 50202 cambio de estado no permitido, 50203 borrado de venta.
3. **No se valida** que el producto esté activo al vender.
4. **`00_master.sql`** usa `\` como separador de rutas en `:r`, por lo que solo funciona en Windows. No incluye `Subconsultas.sql`, `ConsultasAvanzadas.sql` ni `99_test_siam.sql`.
5. **Pruebas.** `99_test_siam.sql` prueba funciones, vistas, SPs, triggers, el cursor y la integridad. Las pruebas que modifican datos terminan con `ROLLBACK`.
