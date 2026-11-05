# 3. Descripción del sistema

## Nombre y dominio

**Firme38** es un sistema de gestión para un local de indumentaria urbana que vende remeras, buzos, pantalones, bermudas, camperas y otros artículos de ropa.

## Problema a resolver

La gestión del local suele hacerse en forma manual o con herramientas sueltas (planillas, cuadernos, mensajes) que no están integradas entre sí. Esto genera dificultades concretas:

- No se sabe con precisión cuánto stock hay de cada prenda.
- Una misma prenda se vende en varios talles, colores y para distintos públicos, y el stock de cada combinación es distinto.
- Las ventas, las compras a proveedores y las correcciones de inventario quedan registradas en lugares distintos, o no quedan registradas.
- No hay forma de saber quién hizo cada operación.
- Un error de carga (por ejemplo, vender algo que no hay) se detecta tarde.

## Solución propuesta

Una base de datos centralizada que registra productos, variantes, stock, compras, ventas, clientes, proveedores y usuarios. Las reglas del negocio (por ejemplo, "no se puede vender sin stock" o "una venta no se borra, se anula") se implementan en la propia base mediante restricciones, triggers y procedimientos almacenados.

## Alcance

El sistema gestiona:

- **Catálogo:** productos, categorías, marcas, talles, colores, segmentos de público y variantes.
- **Stock:** cantidad disponible por variante, con el registro de los ajustes manuales en `MovimientoStock`.
- **Compras:** pedidos a proveedores y su recepción.
- **Ventas:** registro y anulación de ventas, con su detalle.
- **Clientes y proveedores.**
- **Usuarios y roles** del personal del local.
- **Consultas e informes** de stock, ventas y compras.

## Fuera del alcance

- Contabilidad general.
- Liquidación de sueldos.
- Facturación electrónica.
- Gestión de envíos y logística.
- Administración impositiva.

## Objetivo general

Centralizar la información del local en una base de datos que aplique restricciones de integridad sobre el stock, deje trazabilidad de las operaciones principales y concentre las reglas de negocio, reduciendo los errores de la gestión diaria.
