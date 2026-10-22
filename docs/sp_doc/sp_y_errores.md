# Implementación de Procedimientos Almacenados y Control de Errores

Para garantizar la integridad de los datos y evitar condiciones de carrera (como vender un producto que ya no tiene stock), se implementaron Procedimientos Almacenados (SPs) con las siguientes características técnicas:

### 1. Uso de Table-Valued Parameters (TVP)
Para el registro de ventas, en lugar de enviar los datos uno por uno o usar strings concatenados, se creó el tipo de dato `TipoDetalleVenta`. Esto permite enviar todo el "carrito de compras" como una tabla en memoria al SP, lo que mejora el rendimiento y mantiene la integridad de los tipos de datos (evitando inyección SQL).

### 2. Transacciones (ACID)
Todos los SPs que modifican múltiples tablas (por ejemplo, `Venta`, `DetalleVenta` y `MovimientoStock`) están envueltos en bloques de transacción (`BEGIN TRANSACTION` ... `COMMIT TRANSACTION`). 
Esto asegura que, si falla la inserción del detalle por cualquier motivo, la cabecera de la venta no quede "huérfana" en la base de datos. Si ocurre un error, se ejecuta un `ROLLBACK TRANSACTION` que revierte todos los cambios a su estado anterior.

### 3. Manejo de Errores con TRY / CATCH
Se utilizan bloques `BEGIN TRY ... END CATCH` en todos los SPs. 
- Las validaciones de negocio (ej: "no hay stock suficiente" o "la venta ya está anulada") se lanzan intencionalmente usando `THROW`. 
- El bloque `CATCH` captura esos errores, hace el `ROLLBACK` si hay una transacción abierta y utiliza `RAISERROR` para devolver un mensaje claro y legible al usuario o al sistema que consuma la base de datos.

### 4. Concurrencia y Bloqueos
Al validar el stock justo antes de iniciar la transacción y al usar un SP (que se compila y ejecuta como un plan de ejecución único), se reduce drásticamente el riesgo de que dos usuarios compren la última unidad de una misma variante al mismo tiempo (condición de carrera).