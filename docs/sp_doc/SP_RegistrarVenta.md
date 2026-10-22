## Procedimiento Almacenado: SP_RegistrarVenta

**Descripción:** 
Registra una venta completa (cabecera, detalle y movimiento de stock) de forma transaccional. Valida stock y consistencia de datos antes de guardar.

**Tecnología utilizada:**
Se utiliza un **Table-Valued Parameter (TVP)** (`TipoDetalleVenta`) para enviar el carrito de compras. Esto evita el uso de strings dinámicos o JSON, manteniendo la integridad de los tipos de datos y permitiendo procesar múltiples líneas en una sola llamada.

**Parámetros:**
- `@IdCliente` (INT, opcional): ID del cliente. Si es NULL, se asume consumidor final.
- `@IdUsuario` (INT, obligatorio): ID del vendedor.
- `@MedioPago` (VARCHAR(20), obligatorio): EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA.
- `@Detalle` (TipoDetalleVenta READONLY, obligatorio): Tabla con las columnas IdVariante, Cantidad, PrecioUnitario y Descuento.

**Control de Errores y Validaciones:**
1. Uso de `TRY...CATCH` con `RAISERROR` para propagar errores.
2. Validación de existencia de Usuario y Cliente.
3. Validación de duplicados en el carrito (no se puede mandar la misma variante dos veces).
4. Validación de Stock: se cruza la tabla de detalle con `VarianteProducto` para verificar que `StockActual >= Cantidad`. Si falla, se genera un mensaje indicando el SKU exacto que causó el problema.
5. Uso de Transacciones (`BEGIN TRAN` / `COMMIT` / `ROLLBACK`) para asegurar atomicidad.