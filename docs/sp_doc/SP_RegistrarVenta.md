## Procedimiento Almacenado: SP_RegistrarVenta

**Descripción:**
Registra la venta de un producto (una variante) de forma transaccional: cabecera en `Venta` y una línea en `DetalleVenta`. El precio se toma de `VarianteProducto.PrecioVenta`. El descuento de `StockActual` y el cálculo del total los hacen los triggers `TR_DescontarStockVenta` y `TR_CalcularTotalVenta`.

**Parámetros:**
- `@IdCliente` (INT, opcional): cliente. Si es NULL, se asume consumidor final.
- `@IdUsuario` (INT, obligatorio): usuario que registra la venta.
- `@MedioPago` (VARCHAR(20), obligatorio): EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA.
- `@IdVariante` (INT, obligatorio): variante vendida.
- `@Cantidad` (INT, obligatorio): unidades.
- `@Descuento` (DECIMAL(12,2), opcional, 0): descuento en pesos.

**Roles:** usuarios activos con rol de aplicación `Vendedor` o `Administrador`. El permiso de motor `EXECUTE` se otorga a `rol_vendedor` y `rol_administrador`.

**Control de errores y validaciones:**
1. `TRY...CATCH`; en el `CATCH`, `ROLLBACK` si hay transacción abierta y `THROW;` para devolver el error.
2. Cantidad mayor a cero (50001).
3. Usuario existente y activo (50002) con rol `Administrador` o `Vendedor` (50007).
4. Cliente existente cuando se informa (50003).
5. Medio de pago válido (50004).
6. Variante existente (50005) y stock suficiente (50006).
7. Descuento entre 0 y el importe (50008).
8. `BEGIN TRANSACTION` / `COMMIT`: `IdVenta` se genera con `MAX + 1` y se insertan cabecera y detalle juntos.
