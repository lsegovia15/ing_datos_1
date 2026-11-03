# 20. Conclusiones

## Sobre el diseño

El punto central del modelo fue reconocer que en un local de ropa **lo que se vende y se stockea no es el producto, sino la variante**: una combinación concreta de producto, segmento, talle y color. Modelarla como una entidad propia, en lugar de guardar listas de talles y colores en el producto, permitió llevar el stock exacto de cada combinación y llegar a la quinta forma normal sin perder información.

La segunda decisión importante fue tratar el stock como **el resultado de un historial de movimientos** y no como un número que se edita. Cada entrada, salida, devolución o ajuste queda registrado con su usuario, su fecha y su origen. El stock actual es siempre la suma de ese historial, así que ante cualquier diferencia se puede reconstruir qué pasó.

## Sobre la centralización de la lógica

Implementar las reglas en la base de datos, y no en una aplicación, garantiza que se cumplan siempre:

- Las **restricciones** (`CHECK`, `UNIQUE`, `FK`) impiden los datos inválidos desde el primer nivel.
- Los **triggers** mantienen automáticamente el stock, los totales, el historial de precios y las alertas, y bloquean operaciones prohibidas, como borrar una venta.
- Los **stored procedures** agrupan las operaciones de varios pasos en transacciones: una venta se registra completa o no se registra.

En la práctica, el sistema no puede quedar en un estado inconsistente aunque se use de forma incorrecta.

## Sobre el manejo de errores y la concurrencia

Una de las lecciones más importantes fue que una operación correcta para un solo usuario puede fallar con varios usuarios a la vez. Las pruebas con sesiones simultáneas mostraron que generar IDs con `MAX + 1` sin bloqueo producía claves duplicadas. Se resolvió con bloqueos explícitos (`UPDLOCK, HOLDLOCK`) y un orden de bloqueo uniforme para evitar deadlocks. También se separaron los códigos de error de SPs y triggers, para identificar de inmediato el origen de cada falla.

## Limitaciones y trabajo futuro

- **Identificadores manuales:** las claves de ventas, compras y movimientos se generan con `MAX + 1` bloqueado. Funciona correctamente, pero serializa las operaciones. Con mucho volumen convendría usar `IDENTITY` o `SEQUENCE`.
- **Usuario de la operación:** los SPs reciben el `IdUsuario` como parámetro. Una mejora sería obtenerlo de la sesión de base de datos, para que no se pueda operar a nombre de otro.
- **Contraseñas:** se almacenan tal como se ingresan. Deberían guardarse como hash con *salt*.
- **Compras por SP:** las compras se gestionan con sentencias directas controladas por triggers. Un `SP_RegistrarCompra` análogo al de ventas unificaría la forma de operar.
- **Devoluciones parciales:** hoy solo se puede anular una venta completa. Devolver una sola prenda requeriría un nuevo tipo de operación.

## Cierre

El trabajo permitió recorrer el proceso completo de una base de datos: desde el análisis del negocio y la normalización hasta la implementación de reglas, el control de errores y la concurrencia. El resultado es una base que no solo almacena datos, sino que **garantiza su integridad** y deja trazabilidad de cada operación del local.
