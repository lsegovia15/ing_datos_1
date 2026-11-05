# SIAM – Documentación técnica de la base de datos

Motor: SQL Server (T-SQL). Base: `SIAM`. Los scripts están en `sql/`; `00_master.sql` los ejecuta en orden con `sqlcmd` (modo SQLCMD, `:r`).

## 1. Resumen del esquema

SIAM gestiona el inventario, las ventas y las compras de un comercio de indumentaria. El stock se lleva por variante (producto + segmento + talle + color), no por producto.

Flujos principales:

- **Venta:** `SP_RegistrarVenta` crea la cabecera y el detalle; los triggers descuentan stock y recalculan el total.
- **Anulación:** `SP_AnularVenta` pasa la venta a `ANULADA`; un trigger devuelve el stock.
- **Compra:** `SP_RegistrarCompra` deja la compra en `PENDIENTE`; `SP_RecibirCompra` la pasa a `RECIBIDA` y un trigger suma el stock.
- **Ajuste manual:** `SP_AjustarStock` inserta un `MovimientoStock` tipo `AJUSTE` con la diferencia firmada.
- **Seguridad:** dos roles de BD (`rol_administrador`, `rol_vendedor`), con permisos por `GRANT`/`DENY`. Los SPs validan además el rol de negocio (`Rol.Nombre`) del `@IdUsuario` recibido.

Orden de ejecución (`00_master.sql`): `init_db` → `siam_triggers` → `funciones` → `vistas` → `sp/SPs` → `sp/SP_*` → `cursores` → `seed_data` → `seguridad`.

`init_db.sql` **dropea y recrea la base `SIAM`** (`SINGLE_USER WITH ROLLBACK IMMEDIATE`). No correrlo contra datos que se quieran conservar.

Las PK no son `IDENTITY` (salvo `AlertaStock` y `HistorialPrecio`): los IDs se generan en los SPs con `MAX(Id)+1` bajo `UPDLOCK, HOLDLOCK`.

## 2. Diccionario de datos

### 2.1 Catálogo y usuarios

| Tabla | Rol | PK | Relaciones / restricciones |
|---|---|---|---|
| `Rol` | Roles de negocio (`Administrador`, `Vendedor`). | `IdRol` | `Nombre` único. |
| `Usuario` | Usuarios del sistema. | `IdUsuario` | FK `IdRol → Rol`. `NombreUsuario` y `Email` únicos. `Activo IN (0,1)`. Guarda `Contrasena` (VARCHAR 255). |
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
| `MovimientoStock` | Historial de movimientos de stock. | `IdMovimiento` | FK `IdVariante`, `IdUsuario`; `IdCompra` y `IdVenta` nullables (`ON DELETE SET NULL`). `TipoMovimiento IN ('ENTRADA','SALIDA','AJUSTE','DEVOLUCION')`. `AJUSTE` exige `Cantidad <> 0` (con signo); el resto `Cantidad > 0`. No puede tener `IdCompra` e `IdVenta` a la vez. |
| `AlertaStock` | Alertas por stock bajo el mínimo (creada en `siam_triggers.sql`). | `IdAlerta` (IDENTITY) | FK `IdVariante`. `Atendida IN (0,1)`. |
| `HistorialPrecio` | Cambios de `PrecioVenta` (creada en `siam_triggers.sql`). | `IdHistorial` (IDENTITY) | FK `IdVariante`. |

### 2.5 Tipos de tabla (TVP) – `sp/SPs.sql`

| Tipo | Columnas |
|---|---|
| `dbo.TipoDetalleVenta` | `IdVariante`, `Cantidad`, `PrecioUnitario`, `Descuento` (default 0) |
| `dbo.TipoDetalleCompra` | `IdVariante`, `Cantidad`, `CostoUnitario` |

### 2.6 Índices

Un índice por cada FK (`IX_<Tabla>_Id<Ref>`) más: `IX_Producto_Nombre`, `IX_Cliente_Apellido_Nombre`, `IX_Compra_Fecha`, `IX_Venta_Fecha`, `IX_Mov_Fecha`.

## 3. Lógica de negocio y programabilidad

### 3.1 Stored procedures

Todos usan `SET NOCOUNT ON`, `SET XACT_ABORT ON`, `TRY/CATCH` con `ROLLBACK` si hay transacción abierta y `THROW` para propagar el error. Devuelven un resultset de una fila con el resultado y un `Mensaje`.

#### `SP_RegistrarVenta`

Parámetros: `@IdCliente INT = NULL`, `@IdUsuario INT`, `@MedioPago VARCHAR(20)`, `@Detalle TipoDetalleVenta READONLY`.

Qué hace:
1. Valida detalle no vacío, usuario activo con rol `Administrador` o `Vendedor`, cliente existente (si viene), variantes no repetidas, variantes existentes y stock suficiente (informa SKU, solicitado y disponible).
2. Calcula `Total = SUM(Cantidad * PrecioUnitario - Descuento)`.
3. En transacción: genera `IdVenta` (`MAX+1` con `UPDLOCK, HOLDLOCK`), inserta `Venta` en `CONFIRMADA` e inserta `DetalleVenta` numerando líneas con `ROW_NUMBER()`.
4. Marca `PermitirDetalleVenta = 1` en `SESSION_CONTEXT` durante el insert del detalle y la limpia al salir (también en el `CATCH`, porque el rollback no la revierte).

Devuelve `IdVentaGenerada`, `TotalVenta`, `Mensaje`.

Errores: 50001 detalle vacío, 50002 usuario inexistente/inactivo, 50003 cliente inexistente, 50004 variante repetida, 50005 variante inexistente, 50006 stock insuficiente, 50007 rol no habilitado.

#### `SP_AnularVenta`

Parámetros: `@IdVenta INT`, `@IdUsuario INT`.

Qué hace:
1. Valida que el usuario exista y sea `Administrador` activo.
2. En transacción, lee `Venta.Estado` con `UPDLOCK, HOLDLOCK`. Falla si no existe o no está `CONFIRMADA`.
3. Guarda `@IdUsuario` en `SESSION_CONTEXT` (`IdUsuarioOperacion`) y hace `UPDATE Venta SET Estado = 'ANULADA' WHERE Estado = 'CONFIRMADA'`. Si el `UPDATE` no afecta filas, falla (anulación concurrente).
4. Limpia el contexto de sesión (también en el `CATCH`).

La devolución de stock la hace el trigger sobre `Venta` (ver 3.2).

Errores: 50010 venta inexistente, 50011 venta ya anulada / estado inválido, 50012 usuario inexistente, 50013 usuario no es Administrador.

#### `SP_RegistrarCompra`

Parámetros: `@IdProveedor INT`, `@IdUsuario INT`, `@NroComprobante VARCHAR(30) = NULL`, `@Detalle TipoDetalleCompra READONLY`.

Qué hace:
1. Valida detalle no vacío, proveedor existente, usuario activo y `Administrador`, variantes no repetidas, cantidades > 0, costos >= 0 y variantes existentes.
2. Calcula `Total = SUM(Cantidad * CostoUnitario)`.
3. En transacción: genera `IdCompra`, inserta `Compra` en `PENDIENTE` y su `DetalleCompra`.

No modifica stock. Devuelve `IdCompraGenerada`, `TotalCompra`, `Mensaje`.

Errores: 50100 detalle vacío, 50101 proveedor inexistente, 50102 usuario inexistente/inactivo, 50103 variante repetida, 50104 cantidad <= 0, 50105 costo negativo, 50106 variante inexistente, 50107 usuario no es Administrador.

#### `SP_RecibirCompra`

Parámetros: `@IdCompra INT`, `@IdUsuario INT`.

Qué hace:
1. Valida usuario activo y `Administrador`.
2. En transacción, lee `Compra.Estado` con `UPDLOCK, HOLDLOCK`. Exige estado `PENDIENTE` y al menos una línea de detalle.
3. Guarda `@IdUsuario` en `SESSION_CONTEXT` (`IdUsuarioOperacion`) y hace `UPDATE Compra SET Estado = 'RECIBIDA' WHERE Estado = 'PENDIENTE'`.
4. Limpia el contexto de sesión.

El stock lo suma el trigger sobre `Compra` (ver 3.2). Devuelve `IdCompraRecibida`, `Mensaje`.

Errores: 50110 compra inexistente, 50111 compra sin detalle, 50112 estado no permitido, 50113 usuario inexistente/inactivo, 50114 usuario no es Administrador.

#### `SP_AjustarStock`

Parámetros: `@IdVariante INT`, `@NuevaCantidad INT`, `@IdUsuario INT`, `@Observacion VARCHAR(200) = 'Ajuste manual de inventario'`.

Qué hace:
1. Valida `@NuevaCantidad >= 0`, usuario activo y `Administrador`.
2. En transacción: genera `IdMovimiento` (bloqueando `MovimientoStock`), lee `StockActual` con `UPDLOCK, HOLDLOCK` y calcula `Diferencia = NuevaCantidad - StockActual`.
3. Si la diferencia es 0, confirma y devuelve "No hubo diferencia" sin registrar nada.
4. Si no, inserta un `MovimientoStock` tipo `AJUSTE` con la diferencia con signo. `TR_AplicarAjusteStock` aplica el cambio a `VarianteProducto.StockActual`.

Devuelve `IdVariante`, `StockAnterior`, `StockNuevo`, `Diferencia`, `Mensaje`.

Errores: 50020 cantidad negativa, 50021 usuario inexistente/inactivo, 50022 variante inexistente, 50023 usuario no es Administrador.

#### `SP_InformeReposicionStock` (`cursores.sql`)

Sin parámetros. Recorre con un cursor `LOCAL FAST_FORWARD` las variantes de productos activos con `StockActual <= StockMinimo` y, por cada una:
- `Objetivo = 1` si `StockMinimo = 0`; si no, `StockMinimo * 2`.
- `CantidadSugerida = Objetivo - StockActual`.
- `Prioridad = 'URGENTE'` si `StockActual = 0`, si no `'NORMAL'`.

Acumula en una tabla variable y devuelve el informe con las `URGENTE` primero, luego por `IdVariante`. En el `CATCH` cierra y libera el cursor y relanza el error.

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
| `vw_CategoriasMasVendidasPorSegmento` | Categoría con más unidades vendidas por segmento (`RANK()`, empate por total vendido). Solo ventas `CONFIRMADA`. |

### 3.5 Consultas de ejemplo

- `Subconsultas.sql`: clientes que compraron la categoría `Buzos` (`IN`), productos sin ventas (`NOT EXISTS`), variantes más caras que todos los productos de la marca `Nangallery` (`> ALL`).
- `sp/ConsultasAvanzadas.sql`: `UNION` de ventas y compras, ranking de vendedores (`GROUP BY` + `HAVING`), ventas por mes y medio de pago, subconsultas `EXISTS`/`IN`/`ALL` y subconsultas correlacionadas.

Son scripts de consulta, no objetos de la base. No están en `00_master.sql`.

### 3.6 Seguridad (`seguridad.sql`)

Crea los logins `login_admin_siam` y `login_vendedor_siam` (con contraseñas fijas en el script, hay que cambiarlas fuera del entorno de práctica), los usuarios `usr_admin` y `usr_vendedor`, y los roles `rol_administrador` y `rol_vendedor`.

| | `rol_administrador` | `rol_vendedor` |
|---|---|---|
| Tablas | `SELECT/INSERT/UPDATE/DELETE` sobre el esquema `dbo` | Solo `SELECT` sobre catálogo, `Cliente` y las 4 vistas |
| `Usuario.Contrasena` | `DENY SELECT` | `DENY SELECT` |
| `DELETE` | Denegado en `Venta`, `DetalleVenta`, `Compra`, `DetalleCompra` | Denegado |
| Stock (`VarianteProducto`) | Por SPs/triggers | `DENY INSERT/UPDATE/DELETE` |
| `Venta`, `DetalleVenta` | Escritura | `DENY INSERT/UPDATE/DELETE` (solo vía `SP_RegistrarVenta`) |
| `Compra`, `DetalleCompra`, `Proveedor`, `MovimientoStock` | Acceso | `DENY` total |
| SPs | `EXECUTE` sobre `dbo` | `EXECUTE` en `SP_RegistrarVenta`, `SP_InformeReposicionStock`, `fn_EstadoStock`. `DENY EXECUTE` en `SP_AnularVenta`, `SP_AjustarStock`, `SP_RegistrarCompra`, `SP_RecibirCompra`. |
| `fn_ResumenVentasPorUsuario` | `SELECT` | `DENY SELECT` |

La regla de rol de negocio (`Usuario.IdRol`) se valida dentro de los SPs; los permisos de BD se aplican al login que ejecuta.

## 4. Notas

1. **Movimientos de stock.** Solo `SP_AjustarStock` escribe en `MovimientoStock`. Ventas, anulaciones y recepciones modifican `StockActual` directo desde los triggers. El `CHECK` de la tabla admite `ENTRADA`, `SALIDA` y `DEVOLUCION`, pero ningún objeto los inserta.
2. **`SESSION_CONTEXT`.** `SP_RegistrarVenta`, `SP_AnularVenta` y `SP_RecibirCompra` setean `PermitirDetalleVenta` e `IdUsuarioOperacion`; ningún trigger las lee.
3. **Códigos de triggers.** Los triggers usan el rango 50200–50299 (50200 sin stock, 50201/50202 cambio de estado no permitido, 50203 borrado de venta), separado de los SPs.
4. **`TR_NoBorrarVenta` lanza error 50203.** No hay trigger equivalente para `Compra`; la protección es el `DENY DELETE`.
5. **No se valida** que el producto esté activo al vender ni que una venta anulada no pueda reactivarse con un `UPDATE` directo.
6. **`00_master.sql`** usa `\` como separador de rutas en `:r`, por lo que solo funciona en Windows. No incluye `Subconsultas.sql` ni `ConsultasAvanzadas.sql`.
7. **Archivos duplicados sin trackear** con sufijo ` 2` (`cursores 2.sql`, `funciones 2.sql`, `ConsultasAvanzadas 2.sql`, `docs/documentacion/* 2.md`, `.gitignore 2`). Parecen copias de macOS y no están en `00_master.sql`.
