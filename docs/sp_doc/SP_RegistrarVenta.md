## Procedimiento Almacenado: SP_RegistrarVenta

**Descripción:**
Registra una venta de **una línea** (cabecera y detalle) de forma transaccional. Valida stock y consistencia de datos antes de guardar. El descuento de `StockActual` y el recálculo del total los realizan los triggers `TR_DescontarStockVenta` y `TR_CalcularTotalVenta`.

**Parámetros:**
- `@IdCliente` (INT, opcional): ID del cliente. Si es NULL, se asume consumidor final.
- `@IdUsuario` (INT, obligatorio): ID del vendedor.
- `@MedioPago` (VARCHAR(20), obligatorio): EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA.
- `@IdVariante` (INT, obligatorio): variante vendida.
- `@Cantidad` (INT, obligatorio): unidades vendidas.
- `@PrecioUnitario` (DECIMAL(12,2), obligatorio): precio de la unidad.
- `@Descuento` (DECIMAL(12,2), opcional, por defecto `0`): descuento total de la línea, en pesos.

**Roles:** pueden ejecutarlo usuarios activos con rol de aplicación `Vendedor` o `Administrador`. El permiso de motor `EXECUTE` se concede a `rol_vendedor` y a `rol_administrador`.

**Control de Errores y Validaciones:**
1. `BEGIN TRY` / `BEGIN CATCH` con `ROLLBACK` si hay una transacción abierta y `THROW;` para relanzar el error original.
2. Validación de existencia y estado activo del Usuario. Si falla, se ejecuta `PRINT` y `RETURN` (sin excepción y sin resultset).
3. Validación del rol de aplicación: solo `Administrador` o `Vendedor` activo. Si falla, `PRINT` + `RETURN`.
4. Validación de existencia del Cliente cuando se especifica. Si falla, `PRINT` + `RETURN`.
5. Validación de existencia de la variante. Si falla, `PRINT` + `RETURN`.
6. Validación de stock: se lee `StockActual` de la variante y se compara con `@Cantidad`. Si no alcanza, `PRINT` + `RETURN`. Además, `TR_DescontarStockVenta` vuelve a validar el stock al insertar el detalle y, si no alcanza, lanza `THROW 50001, 'No hay stock suficiente para realizar la venta.', 1`.
7. Uso de transacción (`BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`) para asegurar atomicidad.
8. El `IdVenta` se genera con `ISNULL(MAX(IdVenta), 0) + 1`, sin `UPDLOCK` ni `HOLDLOCK`. Dos ventas concurrentes pueden obtener el mismo número y una fallará por la clave primaria.
9. El SP inserta la cabecera y una línea de detalle con `NroLinea = 1`. `TR_DescontarStockVenta` descuenta el stock y `TR_CalcularTotalVenta` recalcula el `Total`.

**Resultado:** devuelve `IdVentaGenerada`, `TotalVenta` y un mensaje de éxito.

**Ventas de varias líneas:** el SP solo registra la primera línea. Para agregar más líneas a la misma venta se insertan directamente en `DetalleVenta` con `NroLinea` 2 en adelante; los triggers vuelven a descontar stock y a recalcular el total.

```sql
EXEC SP_RegistrarVenta
     @IdCliente      = NULL,
     @IdUsuario      = 2,
     @MedioPago      = 'DEBITO',
     @IdVariante     = 1,
     @Cantidad       = 2,
     @PrecioUnitario = 15000,
     @Descuento      = 0;
```
