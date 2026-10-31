## Procedimiento Almacenado: SP_RegistrarVenta

**Descripción:** 
Registra una venta completa (cabecera y detalle) de forma transaccional. Valida stock y consistencia de datos antes de guardar. El movimiento de stock `SALIDA`, la actualización de `StockActual` y el recálculo del total los realizan los triggers.

**Tecnología utilizada:**
Se utiliza un **Table-Valued Parameter (TVP)** (`TipoDetalleVenta`) para enviar el carrito de compras. Esto evita el uso de strings dinámicos o JSON, manteniendo la integridad de los tipos de datos y permitiendo procesar múltiples líneas en una sola llamada.

**Parámetros:**
- `@IdCliente` (INT, opcional): ID del cliente. Si es NULL, se asume consumidor final.
- `@IdUsuario` (INT, obligatorio): ID del vendedor.
- `@MedioPago` (VARCHAR(20), obligatorio): EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA.
- `@Detalle` (TipoDetalleVenta READONLY, obligatorio): Tabla con las columnas IdVariante, Cantidad, PrecioUnitario y Descuento.

**Roles:** pueden ejecutarlo usuarios activos con rol de aplicación `Vendedor` o `Administrador`. Se define explícitamente que el `Administrador` también puede registrar ventas. El permiso de motor `EXECUTE` se concede a `rol_vendedor` y a `rol_administrador`.

**Control de Errores y Validaciones:**
1. Uso de `TRY...CATCH` con `THROW;` para propagar errores.
2. Validación de existencia y estado activo del Usuario (error `50002`). Un usuario inactivo se rechaza antes de abrir la transacción.
3. Validación del rol de aplicación: solo `Administrador` o `Vendedor` activo (error `50007`).
4. Validación de existencia del Cliente cuando se especifica.
5. Validación de duplicados en el carrito (no se puede mandar la misma variante dos veces).
6. Validación de Stock: se cruza la tabla de detalle con `VarianteProducto` para verificar que `StockActual >= Cantidad`. Si falla, se genera un mensaje indicando el SKU exacto que causó el problema. Si dos ventas compiten por la misma unidad, el trigger `TR_MovimientoStock_AplicarStock` rechaza la segunda dentro de la transacción.
7. Uso de Transacciones (`BEGIN TRAN` / `COMMIT` / `ROLLBACK`) para asegurar atomicidad.
8. El `IdVenta` se genera con `MAX + 1` bloqueado (`UPDLOCK, HOLDLOCK`) para evitar IDs duplicados entre ventas simultáneas.
9. El SP inserta la cabecera y el detalle. El movimiento `SALIDA` y el recálculo del `Total` los hace el trigger `TR_DetalleVenta_Insert`.