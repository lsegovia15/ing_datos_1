# 7. Proceso de normalización

## Punto de partida: la planilla de ventas

Antes del sistema, una venta se anotaba en una planilla como esta:

| NroVenta | Fecha | Cliente | DNI | Vendedor | MedioPago | Productos |
|---|---|---|---|---|---|---|
| 150 | 01/10 | Juan Pérez | 30111222 | Ana | DEBITO | Remera Oversize (Remeras, Nangallery) M Negro x1 $15000; Bermuda Baggy (Bermudas, Nangallery) L Celeste x1 $22000 |
| 151 | 01/10 | Consumidor final | | Ana | EFECTIVO | Remera Oversize (Remeras, Nangallery) L Negro x2 $15000 |

Esta planilla tiene todos los problemas que la normalización resuelve:

- **Anomalía de inserción:** no se puede registrar un producto nuevo hasta que alguien lo compre.
- **Anomalía de modificación:** si "Nangallery" cambia de nombre, hay que corregirlo en cada venta.
- **Anomalía de eliminación:** si se borra la venta 151, se pierde la única información de que existe la remera en L negro.
- **Redundancia:** los datos del cliente y del producto se repiten en cada venta.

## Primera Forma Normal (1FN)

**Regla:** todos los atributos son atómicos y no hay grupos repetitivos.

**Problema:** la columna `Productos` contiene una lista (varios productos por celda), y cada producto mezcla varios datos (nombre, categoría, marca, talle, color, cantidad, precio).

**Solución:** cada producto vendido pasa a ser una fila, con un atributo por columna. La clave pasa a ser `(NroVenta, NroLinea)`:

| NroVenta | NroLinea | Fecha | Cliente | DNI | Vendedor | MedioPago | Producto | Categoria | Marca | Talle | Color | Cantidad | Precio |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 150 | 1 | 01/10 | Juan Pérez | 30111222 | Ana | DEBITO | Remera Oversize | Remeras | Nangallery | M | Negro | 1 | 15000 |
| 150 | 2 | 01/10 | Juan Pérez | 30111222 | Ana | DEBITO | Bermuda Baggy | Bermudas | Nangallery | L | Celeste | 1 | 22000 |
| 151 | 1 | 01/10 | — | — | Ana | EFECTIVO | Remera Oversize | Remeras | Nangallery | L | Negro | 2 | 15000 |

También se separó el nombre del cliente en `Nombre` y `Apellido`, para que cada atributo sea atómico.

## Segunda Forma Normal (2FN)

**Regla:** estar en 1FN y que todo atributo no clave dependa de la **clave completa**, no de una parte.

**Dependencias funcionales encontradas** (con clave `NroVenta, NroLinea`):

- `NroVenta → Fecha, Cliente, DNI, Vendedor, MedioPago`: dependen solo de una parte de la clave (**dependencia parcial**).
- `NroVenta, NroLinea → Producto, Talle, Color, Cantidad, Precio`: dependen de la clave completa.

**Solución:** se separa la cabecera del detalle:

- `Venta (IdVenta, Fecha, IdCliente, IdUsuario, MedioPago)`
- `DetalleVenta (IdVenta, NroLinea, Producto, Categoria, Marca, Talle, Color, Cantidad, PrecioUnitario)`

## Tercera Forma Normal (3FN)

**Regla:** estar en 2FN y que no haya **dependencias transitivas**, es decir, que ningún atributo no clave dependa de otro atributo no clave.

**Dependencias transitivas encontradas:**

| Dependencia transitiva | Solución |
|---|---|
| `IdVenta → DNI → Nombre, Apellido` (cliente) | Tabla `Cliente`. `Venta` guarda solo `IdCliente` |
| `IdVenta → Vendedor → datos del usuario` | Tabla `Usuario`. `Venta` guarda solo `IdUsuario` |
| `Usuario → Rol → descripción del rol` | Tabla `Rol` |
| Línea → Producto → Categoría, Marca | Tabla `Producto`, con FK a `Categoria` y `Marca` |
| Línea → (Producto, Talle, Color) → SKU, precio de venta, stock | Tabla `VarianteProducto`. `DetalleVenta` guarda solo `IdVariante` |
| Talle, Color, Segmento, Categoría, Marca como texto repetido | Tablas de referencia propias. Evitan que "Negro" y "negro" sean dos colores distintos |

El mismo análisis se aplicó a las compras: `Compra` (cabecera) → `DetalleCompra` (líneas) → `Proveedor`.

**Resultado:** cada tabla describe un solo concepto, y cada dato no clave depende "de la clave, de toda la clave y nada más que de la clave".

## Forma Normal de Boyce-Codd (FNBC)

**Regla:** todo determinante es una clave candidata.

El caso que requiere atención es `VarianteProducto`, porque tiene **tres claves candidatas**:

1. `IdVariante` (clave primaria elegida).
2. `SKU`.
3. `(IdProducto, IdSegmento, IdTalle, IdColor)`.

Las tres determinan todos los demás atributos (`PrecioVenta`, `StockActual`, `StockMinimo`) y ninguna otra combinación de atributos los determina. Como todo determinante es una clave candidata, la tabla está en FNBC. Las claves alternativas se declararon `UNIQUE` (`UQ_Variante_SKU` y `UQ_Variante_Combinacion`).

Lo mismo ocurre en `DetalleVenta` y `DetalleCompra`, cuyas claves candidatas son `(IdVenta, NroLinea)` y `(IdVenta, IdVariante)`. En las tablas de referencia (`Categoria`, `Marca`, etc.), el nombre también es clave candidata y está declarado `UNIQUE`.

## Claves candidatas por tabla

| Tabla | Clave primaria | Otras claves candidatas |
|---|---|---|
| Rol | IdRol | Nombre |
| Usuario | IdUsuario | NombreUsuario · Email |
| Categoria | IdCategoria | Nombre |
| Marca | IdMarca | Nombre |
| Segmento | IdSegmento | Nombre |
| Talle | IdTalle | Descripcion |
| Color | IdColor | Nombre |
| Producto | IdProducto | — |
| VarianteProducto | IdVariante | SKU · (IdProducto, IdSegmento, IdTalle, IdColor) |
| Proveedor | IdProveedor | CUIT |
| Cliente | IdCliente | DNI |
| Compra | IdCompra | — |
| DetalleCompra | (IdCompra, NroLinea) | (IdCompra, IdVariante) |
| Venta | IdVenta | — |
| DetalleVenta | (IdVenta, NroLinea) | (IdVenta, IdVariante) |
| MovimientoStock | IdMovimiento | — |
| HistorialPrecio | IdHistorial | — |
| AlertaStock | IdAlerta | — |

Se eligieron claves subrogadas (`Id...`) como claves primarias porque son cortas, estables y no cambian si cambia un dato del negocio. Por ejemplo, si se corrige un SKU mal cargado, no hay que actualizar todas las ventas que lo referencian.

## Cuarta Forma Normal (4FN)

**Regla:** estar en FNBC y no tener **dependencias multivaluadas** no triviales. Una dependencia multivaluada `A →→ B` existe cuando, para un valor de `A`, el conjunto de valores de `B` es independiente de los demás atributos.

**Caso analizado:** ¿hay dependencias multivaluadas `Producto →→ Talle` y `Producto →→ Color`?

Las habría si cada producto se ofreciera en **todas** las combinaciones de sus talles y sus colores. En ese caso convendría separar `ProductoTalle (IdProducto, IdTalle)` y `ProductoColor (IdProducto, IdColor)`.

En el local esto **no se cumple**. Ejemplo real:

| Producto | Segmento | Talle | Color |
|---|---|---|---|
| Remera Oversize | Hombre | M | Negro |
| Remera Oversize | Hombre | L | Negro |
| Remera Oversize | Hombre | M | Blanco |

La remera existe en talle L y en color Blanco, pero **no** existe en L Blanco. Los talles disponibles dependen del color (y del segmento), así que no son independientes. Por lo tanto, no hay dependencia multivaluada, y `VarianteProducto` está en 4FN.

Además, cada variante tiene atributos propios (`SKU`, `PrecioVenta`, `StockActual`, `StockMinimo`) que dependen de la combinación completa. Eso confirma que la combinación es una entidad real y no un producto cartesiano.

## Quinta Forma Normal (5FN)

**Regla:** estar en 4FN y que la tabla no pueda descomponerse en proyecciones más chicas que, al unirse con `JOIN`, reconstruyan exactamente la tabla original (**dependencia de join**).

**Caso analizado:** ¿se puede reconstruir `VarianteProducto` uniendo `(Producto, Talle)`, `(Producto, Color)` y `(Talle, Color)`?

Con el ejemplo anterior:

- `(Producto, Talle)`: {Remera–M, Remera–L}
- `(Producto, Color)`: {Remera–Negro, Remera–Blanco}
- `(Talle, Color)`: {M–Negro, L–Negro, M–Blanco}

Al unirlas aparecen Remera–M–Negro, Remera–L–Negro y Remera–M–Blanco, que son correctas. En este ejemplo la reconstrucción funciona, pero solo por casualidad: la proyección `(Talle, Color)` se calcula sobre **todos** los productos. Si otro producto, por ejemplo un buzo, existiera en L Blanco, aparecería el par L–Blanco, y el `JOIN` generaría una **Remera L Blanco que no existe**.

Como la reconstrucción no está garantizada, no existe una dependencia de join, y la tabla no debe descomponerse. `VarianteProducto` está en 5FN. Las demás tablas, cuyas claves tienen una o dos columnas sin dependencias multivaluadas, también cumplen 4FN y 5FN.

## Redundancias controladas (desnormalización deliberada)

Hay tres datos que podrían calcularse a partir de otros y que, sin embargo, se almacenan:

| Dato | Se podría calcular como | Por qué se guarda | Cómo se evita la inconsistencia |
|---|---|---|---|
| `VarianteProducto.StockActual` | Compras recibidas − ventas confirmadas ± ajustes | Se consulta en cada venta. Recalcularlo cada vez sería costoso | Lo modifican los triggers `TR_DescontarStockVenta`, `TR_DevolverStockAnulacion`, `TR_SumarStockCompra` y `TR_AplicarAjusteStock` |
| `Venta.Total` | Suma de las líneas de `DetalleVenta` | Se lista en informes y búsquedas de ventas | Lo calcula `SP_RegistrarVenta` y lo recalcula el trigger `TR_CalcularTotalVenta` |
| `Compra.Total` | Suma de las líneas de `DetalleCompra` | Ídem | Lo calcula `SP_RegistrarCompra` al crear la compra |

En los tres casos la redundancia es **controlada**: un trigger o un SP mantiene el valor sincronizado y los permisos de `seguridad.sql` restringen la modificación directa. Se aprovecha la ventaja de rendimiento sin las anomalías de modificación.

## Datos que parecen redundantes pero no lo son

- **`DetalleVenta.PrecioUnitario`** frente a `VarianteProducto.PrecioVenta`: el primero es el precio **al que se vendió**, y el segundo es el precio **actual**. Si mañana sube el precio, las ventas pasadas no deben cambiar. Es un dato histórico distinto.
- **`Producto.PrecioBase`** frente a `VarianteProducto.PrecioVenta`: el precio base es la referencia del producto, y cada variante puede tener su propio precio (por ejemplo, talles especiales más caros).
- **`AlertaStock.StockActual` y `StockMinimo`**: son una "foto" del momento en que se generó la alerta, no el valor actual.

## Resultado

El modelo final tiene 18 tablas en 5FN, con tres redundancias controladas por triggers y SPs. Se eliminaron las anomalías de inserción, modificación y eliminación de la planilla original:

- Un producto se puede dar de alta sin haberlo vendido.
- El nombre de una marca se corrige en un solo lugar.
- Anular una venta no borra información del catálogo.
