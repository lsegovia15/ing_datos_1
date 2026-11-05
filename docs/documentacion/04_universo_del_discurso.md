# 4. Universo del Discurso

## Contexto del sistema

Firme38 es un local de indumentaria urbana atendido por un administrador y uno o más vendedores. El local compra mercadería a proveedores y la vende al público en el mostrador.

Cada **producto** (por ejemplo, "Remera Oversize Graffiti") pertenece a una **categoría** (Remeras) y a una **marca**. El mismo producto se ofrece en distintas combinaciones de **talle**, **color** y **segmento de público** (Hombre, Mujer, Niño, Niña, Unisex). Cada combinación es una **variante**, con su propio código SKU, precio de venta y stock. Por ejemplo, "Remera Oversize Graffiti – Hombre – M – Negro" es una variante y "Remera Oversize Graffiti – Hombre – L – Negro" es otra.

El stock se maneja **por variante**: no tiene sentido decir "quedan 10 remeras" si son todas talle XL.

## Objetivo de la base de datos

- Registrar el catálogo con todas sus variantes.
- Conocer en todo momento el stock real de cada variante y cómo se llegó a ese número.
- Registrar compras y ventas de forma consistente con el stock.
- Saber qué usuario realizó cada operación.
- Detectar a tiempo las variantes que hay que reponer.

## Actores involucrados

| Actor | Descripción | Qué hace en el sistema |
|---|---|---|
| **Administrador** | Responsable del local | Gestiona el catálogo, los proveedores, las compras y los usuarios. Ajusta el stock, anula ventas y consulta informes |
| **Vendedor** | Atiende al público | Consulta productos y stock, registra clientes y registra ventas |
| **Proveedor** | Empresa que vende mercadería al local | No usa el sistema: se registra como dato para asociarlo a las compras |
| **Cliente** | Persona que compra en el local | No usa el sistema. Puede registrarse con sus datos o comprar como consumidor final |

## Información que se necesita almacenar

| Concepto | Datos |
|---|---|
| Producto | Nombre, descripción, categoría, marca, precio base, si está activo |
| Variante | Producto, segmento, talle, color, SKU, precio de venta, stock actual, stock mínimo |
| Categoría, marca, talle, color, segmento | Nombre o descripción |
| Proveedor | Razón social, CUIT, teléfono, email, dirección |
| Compra | Proveedor, usuario que la registra, fecha, número de comprobante, total, estado |
| Detalle de compra | Variante, cantidad y costo unitario de cada línea |
| Cliente | Nombre, apellido, DNI, email, teléfono, dirección |
| Venta | Cliente (opcional), vendedor, fecha, medio de pago, total, estado |
| Detalle de venta | Variante, cantidad, precio unitario y descuento de cada línea |
| Movimiento de stock | Variante, usuario, fecha, tipo, cantidad, compra o venta de origen, observación |
| Usuario | Rol, nombre de usuario, email, contraseña, nombre, apellido, si está activo, fecha de alta |
| Rol | Nombre y descripción |
| Historial de precios | Variante, precio anterior, precio nuevo, fecha, usuario |
| Alerta de stock | Variante, stock y mínimo al momento de la alerta, fecha, si fue atendida |

## Reglas de negocio

Se detallan en la sección [5. Reglas de negocio](05_reglas_de_negocio.md).

## Procesos principales

### Compra de mercadería
1. El administrador registra una compra a un proveedor. La compra queda **PENDIENTE**.
2. Carga las líneas: qué variantes, cuántas unidades y a qué costo. El total se calcula solo.
3. Cuando llega la mercadería, marca la compra como **RECIBIDA**. Recién en ese momento el stock aumenta.
4. Si el pedido se cancela, la marca como **ANULADA** y el stock no cambia.

### Venta
1. El vendedor arma la venta con una o más variantes, cantidades, precios y descuentos.
2. Indica el medio de pago y, si corresponde, el cliente. Si no hay cliente, la venta es a consumidor final.
3. El sistema verifica que haya stock de todo y registra la venta completa: cabecera, detalle y descuento del stock.
4. Si falta stock de alguna línea, no se registra nada.

### Anulación de una venta
1. El administrador anula la venta indicando quién autoriza.
2. La venta pasa a **ANULADA** y el stock de cada línea vuelve a estar disponible.
3. La venta no se borra: queda en el historial como anulada.

### Ajuste de inventario
1. El administrador hace un recuento físico de una variante.
2. Si no coincide con el sistema, registra la cantidad real y el motivo.
3. El sistema registra un movimiento de ajuste por la diferencia y actualiza el stock.

### Reposición
1. Cuando el stock de una variante llega a su mínimo, el sistema genera una alerta.
2. El administrador consulta el informe de reposición, que indica cuánto pedir de cada variante y con qué prioridad.

## Restricciones del sistema

- El stock de una variante nunca puede ser negativo.
- El stock solo cambia por compras recibidas, ventas, anulaciones y ajustes.
- Las ventas y compras no se borran: se anulan.
- Los productos no se borran: se dan de baja (`Activo = 0`).
- Un usuario dado de baja no puede registrar operaciones.
- No pueden existir dos variantes con la misma combinación de producto, segmento, talle y color.
- No se repiten SKU, DNI de cliente, CUIT de proveedor, nombre de usuario ni email de usuario.

## Relaciones entre los elementos del dominio

- Una **categoría** agrupa muchos productos y una **marca** tiene muchos productos. Cada producto pertenece a una sola categoría y a una sola marca.
- Un **producto** tiene muchas variantes. Cada **variante** combina un producto con un segmento, un talle y un color.
- Un **proveedor** recibe muchas compras. Cada **compra** tiene muchas líneas, y cada línea corresponde a una variante.
- Un **cliente** puede hacer muchas ventas, y una **venta** puede no tener cliente (consumidor final). Cada venta tiene muchas líneas, y cada línea corresponde a una variante.
- Un **usuario** tiene un rol y registra compras, ventas y movimientos de stock.
- Cada **movimiento de stock** afecta a una variante y puede originarse en una compra, en una venta o en ninguna de las dos (ajuste), pero nunca en ambas.
- Cada cambio de precio de una variante genera un registro de **historial de precios**, y cada vez que su stock llega al mínimo se genera una **alerta de stock**.
