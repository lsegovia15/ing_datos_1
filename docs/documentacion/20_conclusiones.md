# 20. Conclusiones

## Sobre el diseño

El punto central del modelo fue reconocer que en un local de ropa **lo que se vende y se stockea no es el producto, sino la variante**: una combinación concreta de producto, segmento, talle y color. Modelarla como una entidad propia, en lugar de guardar listas de talles y colores en el producto, permitió llevar el stock exacto de cada combinación y llegar a la quinta forma normal sin perder información.

La segunda decisión fue que el stock se actualice solo por operaciones del sistema (venta, anulación, recepción de compra y ajuste) y no editándolo a mano. Los triggers aplican cada cambio sobre `VarianteProducto.StockActual` y los ajustes manuales quedan registrados en `MovimientoStock` con usuario, fecha y motivo.

## Sobre la centralización de la lógica

Implementar las reglas en la base de datos, y no en una aplicación, garantiza que se cumplan siempre:

- Las **restricciones** (`CHECK`, `UNIQUE`, `FK`) impiden los datos inválidos desde el primer nivel.
- Los **triggers** mantienen automáticamente el stock, el total de las ventas, el historial de precios y las alertas de stock bajo, y evitan que se borre una venta.
- Los **stored procedures** agrupan las operaciones de varios pasos en transacciones: una venta se registra completa o no se registra.
- Los **permisos** del motor hacen que cada rol solo pueda operar a través de esos SPs, sin tocar las tablas directamente.

En la práctica, el sistema no puede quedar en un estado inconsistente aunque se use de forma incorrecta.

## Sobre el manejo de errores y la concurrencia

Una de las lecciones más importantes fue la diferencia entre avisar un error y lanzarlo. Con `PRINT` el procedimiento termina como si hubiera salido bien y quien lo llamó no se entera; con `THROW` el error llega al `CATCH` de quien llama y la transacción se revierte completa. También se separaron los códigos de error por stored procedure y por trigger, para identificar de inmediato el origen de cada falla. Y en los triggers se aprendió a no asumir que se ejecutan fila por fila: una sola sentencia puede afectar varias filas a la vez.

## Limitaciones y trabajo futuro

- **Identificadores manuales:** las claves de ventas, compras y movimientos se generan con `MAX + 1` dentro de la transacción. Con muchos usuarios operando a la vez, dos operaciones simultáneas podrían calcular el mismo número; convendría usar `IDENTITY`.
- **Un producto por operación:** cada venta y cada compra registra una sola variante. Una venta de varios productos se registra como varias ventas.
- **Usuario de la operación:** los SPs reciben el `IdUsuario` como parámetro y validan su rol, pero no lo relacionan con el login conectado. Una mejora sería obtenerlo de la sesión de base de datos, para que no se pueda operar a nombre de otro.
- **Contraseñas:** se guardan como hash SHA-256 y ni el administrador puede leer la columna. En un sistema real convendría agregar una sal por usuario antes de calcular el hash.
- **Anulación de compras:** existe la transición `PENDIENTE → ANULADA`, pero no hay un SP que la encapsule como `SP_AnularVenta` lo hace con las ventas.
- **Devoluciones parciales:** hoy solo se puede anular una venta completa. Devolver una sola prenda requeriría un nuevo tipo de operación.

## Cierre

El trabajo permitió recorrer el proceso completo de una base de datos: desde el análisis del negocio y la normalización hasta la implementación de reglas, el control de errores y la concurrencia. El resultado es una base que no solo almacena datos, sino que **garantiza su integridad** y deja trazabilidad de cada operación del local.
