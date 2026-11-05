# SIAM – Sistema de Gestión para Local de Indumentaria

## 1. Nombre y dominio del proyecto

**Nombre del proyecto:** SIAM – Sistema Integrado de Administración Múltiple.

**Dominio del proyecto:** Gestión integral de un emprendimiento dedicado a la comercialización de indumentaria urbana, incluyendo productos como remeras, buzos, pantalones, bermudas y otros artículos de ropa.

El sistema estará orientado a centralizar y organizar la información relacionada con los productos, sus variantes, el stock, las compras, las ventas, los proveedores y los usuarios del negocio.

## 2. Problema a resolver

Actualmente, la gestión de un local de indumentaria puede realizarse de manera manual o utilizando diferentes herramientas que no se encuentran integradas entre sí. Esta situación puede dificultar el control de la información y aumentar la posibilidad de cometer errores.

Entre las principales dificultades se encuentran:

- Conocer con precisión el stock disponible.
- Controlar las distintas variantes de cada producto, principalmente por talle y color.
- Registrar y consultar las ventas realizadas.
- Llevar un seguimiento de las compras efectuadas a los proveedores.
- Mantener actualizada la cantidad de productos disponibles.
- Centralizar la información del negocio en un único sistema.

La base de datos propuesta permitirá centralizar esta información y mantenerla organizada, facilitando la gestión diaria del local y mejorando el control sobre el stock, las compras y las ventas.

## 3. Actores principales

Los principales actores que interactuarán con el sistema serán:

### Administrador

Será el usuario con mayor nivel de permisos dentro del sistema. Podrá:

- Gestionar productos, categorías, talles y colores.
- Administrar proveedores.
- Gestionar usuarios y roles.
- Registrar y consultar compras.
- Consultar y controlar el stock.
- Consultar información relacionada con las ventas.
- Realizar tareas de administración general del sistema.

### Vendedor

Tendrá permisos orientados principalmente a la operación diaria del local. Podrá:

- Consultar los productos disponibles.
- Consultar el stock.
- Registrar ventas.
- Registrar los productos incluidos en cada venta.
- Consultar información necesaria para realizar una venta.

### Proveedor

Los proveedores serán registrados en el sistema para poder asociarlos con las compras de mercadería realizadas por el local.

La gestión de los proveedores estará a cargo de los usuarios autorizados del sistema.

## 4. Alcance del sistema

El sistema permitirá gestionar y almacenar información relacionada con:

- **Productos:** nombre, descripción, precio y demás datos relevantes.
- **Categorías:** clasificación de los productos según su tipo.
- **Talles:** talles disponibles para cada producto.
- **Colores:** colores disponibles para cada producto.
- **Variantes de productos:** combinación de producto, talle y color.
- **Stock:** cantidad disponible de cada variante.
- **Proveedores:** información de los proveedores del negocio.
- **Compras:** registro de las compras de mercadería realizadas a proveedores.
- **Detalle de compras:** productos, cantidades y precios correspondientes a cada compra.
- **Ventas:** registro de las operaciones de venta realizadas.
- **Detalle de ventas:** productos y cantidades incluidas en cada venta.
- **Clientes:** registro de clientes cuando corresponda.
- **Usuarios:** cuentas de acceso al sistema.
- **Roles y permisos:** diferenciación de las operaciones que pueden realizar los distintos tipos de usuario.

Además, se podrán realizar consultas relacionadas con el estado del stock, las ventas realizadas y las compras efectuadas.

### Fuera del alcance

El sistema no contemplará, en esta etapa, los siguientes procesos:

- Contabilidad general.
- Liquidación de sueldos.
- Facturación electrónica.
- Gestión de envíos y logística.
- Administración impositiva.
- Gestión de proveedores externos al proceso de compras.

## 5. Complejidad de la propuesta

La propuesta contempla distintos recursos que permiten cumplir con los requerimientos de complejidad del proyecto y, al mismo tiempo, automatizar operaciones frecuentes del sistema.

### Triggers

Se implementarán **triggers** para automatizar determinadas operaciones sobre la base de datos.

Por ejemplo, al registrar una venta, se podrá actualizar automáticamente el stock correspondiente, evitando que el usuario tenga que modificarlo manualmente.

También podrán utilizarse para controlar determinadas condiciones y mantener la integridad de la información.

### Procedimientos almacenados

Se utilizarán **procedimientos almacenados** para encapsular operaciones frecuentes o que requieran varias modificaciones sobre la base de datos.

Por ejemplo, se podrá implementar un procedimiento para registrar una venta junto con sus correspondientes detalles y actualizar el stock de los productos involucrados.

### Cursores

Se podrán utilizar **cursores** en aquellas operaciones que requieran recorrer registros de manera secuencial para realizar controles, cálculos o generar información a partir de varios registros.

Su utilización estará orientada a resolver casos en los que el procesamiento registro por registro resulte necesario.

### Roles y permisos

El sistema contará con diferentes **roles de usuario**, principalmente `Administrador` y `Vendedor`, con permisos diferenciados.

Esto permitirá restringir determinadas operaciones según el tipo de usuario. Por ejemplo, un vendedor podrá registrar ventas, pero no tendrá permisos para modificar la configuración general del sistema o administrar usuarios.

## 6. Objetivo general

El objetivo principal del proyecto es desarrollar una base de datos que permita gestionar de manera centralizada la información de un local de indumentaria, facilitando el control de productos, variantes, stock, compras y ventas.

La implementación de reglas de integridad, automatizaciones y permisos permitirá mantener la información organizada y reducir errores en las operaciones habituales del negocio.

## 7. Documentación complementaria

- [Modelo de tablas](Documentacion_Tablas.md)
- [Orden de ejecución](ORDEN_EJECUCION.md)
- [Seguridad y permisos](SEGURIDAD.md)
- [Procedimientos almacenados y errores](sp_doc/sp_y_errores.md)
