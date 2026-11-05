# Implementación de Procedimientos Almacenados y Control de Errores

Los Procedimientos Almacenados (SPs) encapsulan las operaciones que modifican ventas, compras, stock y estados. Se apoyan en restricciones y triggers para mantener la integridad de los datos.

### 1. Parámetros de las operaciones

Cada SP recibe los datos de **una sola línea** de venta o de compra. No se usan Table-Valued Parameters ni tipos de tabla: `SP_RegistrarVenta` recibe `@IdVariante`, `@Cantidad`, `@PrecioUnitario` y `@Descuento`, y `SP_RegistrarCompra` recibe `@IdVariante`, `@Cantidad` y `@CostoUnitario`.

El SP inserta la cabecera y la línea con `NroLinea = 1`. Para una venta o compra de varias líneas, las restantes se insertan directamente sobre la misma cabecera. En ventas, los triggers descuentan el stock y recalculan el total; en compras, hay que recalcular `Compra.Total` a partir de todas las líneas.

### 2. Reparto de responsabilidades entre SPs y triggers

Los SPs validan los datos de entrada y escriben la operación principal (`Venta`, `DetalleVenta`, cambio de `Estado`, `MovimientoStock` de tipo `AJUSTE`). La actualización de `VarianteProducto.StockActual` y de los totales la hacen los triggers de `siam_triggers.sql`:

| Operación | Lo hace el SP | Lo hace el trigger |
|---|---|---|
| Registrar venta | Valida e inserta `Venta` y la línea `NroLinea = 1` de `DetalleVenta` | `TR_DescontarStockVenta` resta el stock; `TR_CalcularTotalVenta` recalcula el `Total` |
| Anular venta | Valida rol `Administrador` y pasa `Estado` a `ANULADA` | `TR_DevolverStockAnulacion` suma el stock |
| Registrar compra | Inserta `Compra` y la línea `NroLinea = 1` de `DetalleCompra` en `PENDIENTE` y calcula el `Total` | — |
| Recibir compra | Cambia `PENDIENTE` a `RECIBIDA` | `TR_SumarStockCompra` suma el stock |
| Ajustar stock | Inserta el `AJUSTE` con la diferencia firmada | `TR_AplicarAjusteStock` suma o resta el stock |

`TR_AvisoStockMinimo` se dispara en cada `UPDATE` de `VarianteProducto`: solo genera la alerta cuando el stock cruza el mínimo, para no repetirla en cada venta.

Los SPs no usan `sp_set_session_context` ni ninguna otra marca de sesión.

### 3. Transacciones (ACID)

Los SPs que modifican datos abren una transacción después de las validaciones (`BEGIN TRANSACTION` ... `COMMIT TRANSACTION`), y los triggers corren dentro de esa misma transacción. Si falla una inserción o un trigger rechaza la operación (por ejemplo, `TR_DescontarStockVenta` por falta de stock), el `CATCH` ejecuta `ROLLBACK` y la cabecera no queda huérfana.

No se usa `SET XACT_ABORT ON`; la reversión depende del `ROLLBACK` del bloque `CATCH`.

### 4. Manejo de errores con TRY / CATCH

Todos los SPs usan `BEGIN TRY ... END CATCH`.

- Las validaciones de negocio no lanzan excepciones: ejecutan `PRINT` con el mensaje y `RETURN`. La operación termina sin modificar datos, sin resultset de éxito y sin código de error.
- El bloque `CATCH` hace el `ROLLBACK` si hay una transacción abierta y relanza el error original con `THROW;`, conservando su número y mensaje.
- El único objeto que lanza un error propio es `TR_DescontarStockVenta`, con `THROW 50001, 'No hay stock suficiente para realizar la venta.', 1`.

Como los rechazos de validación no son excepciones, quien llama debe verificar el estado o los conteos después de ejecutar el SP.

### 5. Identificadores y concurrencia

- **IDs con `MAX + 1`:** `SP_RegistrarVenta`, `SP_RegistrarCompra` y `SP_AjustarStock` generan el identificador con `ISNULL(MAX(Id), 0) + 1` sin `UPDLOCK` ni `HOLDLOCK`. En uso concurrente, dos operaciones pueden obtener el mismo número y una falla por la clave primaria.
- **Stock:** la validación previa del SP lee `StockActual` fuera de la transacción. `TR_DescontarStockVenta` vuelve a comprobar el stock antes de restar y el `CHECK (StockActual >= 0)` es la última barrera; una de dos ventas simultáneas por la última unidad falla.
- **Ajuste de stock:** el SP lee el stock antes de la transacción; no hay bloqueo que impida que una venta lo modifique entre la lectura y el ajuste.
- **Anulación y recepción:** los SPs leen el estado antes de la transacción y el `UPDATE` no vuelve a condicionar por estado. El trigger solo actúa cuando la fila pasa de `CONFIRMADA` a `ANULADA` o de `PENDIENTE` a `RECIBIDA`.

### 6. Códigos de error del motor y del trigger

| Código | Origen | Situación |
|---|---|---|
| 2627 | Motor | `UNIQUE` duplicado: SKU, DNI, CUIT, email o nombre de usuario |
| 547 | Motor | `CHECK` o `FK` violado |
| 515 | Motor | `NOT NULL` violado |
| 229 | Motor | Permiso insuficiente sobre una tabla, vista o SP |
| 230 | Motor | Permiso insuficiente sobre una columna |
| 50001 | `TR_DescontarStockVenta` | No hay stock suficiente para la venta |

**Defensa en profundidad:** además de los permisos de `seguridad.sql`, los SPs administrativos validan que el usuario de aplicación esté activo y tenga el rol correspondiente. Así, aunque se concediera `EXECUTE` a otro rol de motor, la regla de negocio seguiría vigente.

**Casos borde cubiertos en `seed_data.sql`:** venta sin stock, compra sin líneas de detalle, recepción sin líneas, ajuste sin diferencia, anulación duplicada, anulación por vendedor, ajuste por vendedor, compra por vendedor, recepción por vendedor y venta con usuario inactivo. El seed ejecuta cada caso y muestra el resultado; como las validaciones no lanzan excepción, el rechazo se reconoce por el mensaje impreso y por el estado de los datos.

### 7. Documentación por procedimiento

- [SP_RegistrarVenta](SP_RegistrarVenta.md)
- [SP_AnularVenta](SP_AnularVenta.md)
- [SP_AjustarStock](SP_AjustarStock.md)
- [SP_RegistrarCompra](SP_RegistrarCompra.md)
- [SP_RecibirCompra](SP_RecibirCompra.md)
