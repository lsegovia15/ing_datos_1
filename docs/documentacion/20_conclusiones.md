# 20. Conclusiones

## Sobre el diseño

El punto central del modelo fue reconocer que en un local de ropa **lo que se vende y se stockea no es el producto, sino la variante**: una combinación concreta de producto, segmento, talle y color. Modelarla como una entidad propia, en lugar de guardar listas de talles y colores en el producto, permitió llevar el stock exacto de cada combinación y llegar a la quinta forma normal sin perder información.

La segunda decisión fue que el stock se actualice por operaciones del sistema (venta, anulación, recepción de compra y ajuste). Los triggers aplican cada cambio sobre `VarianteProducto.StockActual` y los ajustes manuales quedan registrados en `MovimientoStock` con usuario, fecha y motivo. El administrador conserva permiso de `UPDATE` directo sobre `VarianteProducto`, por lo que la regla se sostiene por el uso de los SPs y no por una prohibición del motor.

## Sobre la centralización de la lógica

Implementar las reglas en la base de datos, y no en una aplicación, permite que la mayoría se aplique sin depender del cliente:

- Las **restricciones** (`CHECK`, `UNIQUE`, `FK`) impiden los datos inválidos desde el primer nivel.
- Los **triggers** mantienen automáticamente el stock, el total de las ventas, el historial de precios y las alertas de stock bajo, y evitan que se borre una venta.
- Los **stored procedures** agrupan las operaciones de varios pasos en transacciones: una venta se registra completa o no se registra.
- Los **permisos** del motor limitan al vendedor a operar a través de los SPs y le quitan acceso a compras, ventas y movimientos de stock. El administrador, en cambio, conserva escritura directa sobre catálogo, stock y compras.

Las restricciones y los triggers no se pueden saltear. Las validaciones que viven solo en los SPs sí se pueden omitir con una escritura directa del administrador, y las que usan `PRINT` + `RETURN` no generan una excepción.

## Sobre el manejo de errores y la concurrencia

Una de las lecciones más importantes fue que una operación correcta para un solo usuario puede fallar con varios usuarios a la vez. Generar IDs con `MAX + 1` sin bloqueo permite que dos sesiones obtengan el mismo número y una falle por la clave primaria. La implementación actual mantiene ese esquema simple y documenta la limitación: no usa `UPDLOCK`/`HOLDLOCK` ni un orden de bloqueo uniforme. Tampoco hay códigos de error por stored procedure: las validaciones de negocio imprimen un mensaje y salen con `RETURN`, y solo el trigger de stock lanza `THROW 50001`.

## Limitaciones y trabajo futuro

- **Identificadores manuales:** las claves de ventas, compras y movimientos se generan con `MAX + 1` sin bloqueo. Con operaciones concurrentes puede haber colisiones de clave primaria. Convendría usar `IDENTITY`, `SEQUENCE` o agregar bloqueo.
- **Usuario de la operación:** los SPs reciben el `IdUsuario` como parámetro y validan su rol, pero no lo relacionan con el login conectado. Una mejora sería obtenerlo de la sesión de base de datos, para que no se pueda operar a nombre de otro.
- **Contraseñas:** se guardan como hash `SHA2_256`, pero sin *salt*. Agregarlo evitaría que dos contraseñas iguales tengan el mismo hash.
- **Anulación de compras:** existe la transición `PENDIENTE → ANULADA`, pero no hay un SP que la encapsule como `SP_AnularVenta` lo hace con las ventas.
- **Devoluciones parciales:** hoy solo se puede anular una venta completa. Devolver una sola prenda requeriría un nuevo tipo de operación.

## Cierre

El trabajo permitió recorrer el proceso completo de una base de datos: desde el análisis del negocio y la normalización hasta la implementación de reglas, el control de errores y la concurrencia. El resultado es una base que almacena los datos con restricciones de integridad y deja trazabilidad de las operaciones principales, con límites documentados en la generación de IDs, en las validaciones por `PRINT`/`RETURN` y en los permisos del administrador.
