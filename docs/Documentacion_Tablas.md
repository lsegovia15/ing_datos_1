# SIAM – Sistema de gestión para local de ropa

## 1. Catálogo

El módulo de catálogo contiene la información necesaria para identificar y organizar los productos que comercializa el local.

### Producto

Representa cada producto comercializado por el local.

Se relaciona con:

- **Categoría**
- **Marca**
- **VarianteProducto**

Ejemplo:

> Remera Oversize Graffiti → Categoría: Remeras → Marca: Nangallery → Variante para público Hombre.

### Categoría

Clasifica los productos según su tipo.

Ejemplos:

- Remeras
- Buzos
- Pantalones
- Bermudas
- Camperas

### Marca

Permite identificar la marca a la que pertenece cada producto.

### Segmento

Indica **a qué público está destinada cada variante del producto**.

Ejemplos:

- Hombre
- Mujer
- Niño
- Niña
- Unisex

> En el dibujo aparece como **“Público”**. En el modelo se utiliza `Segmento`, que representa el público al que está destinada la variante.

### VarianteProducto

Representa una combinación específica de un producto con sus características de venta.

Contendrá:

- Producto
- Segmento (público destinatario)
- Talle
- Color
- Stock
- Stock mínimo

Ejemplo:

> Remera Oversize Graffiti + Talle M + Color Negro → Stock: 5.

Un mismo producto puede tener varias variantes.

---

## 2. Compras y proveedores

Este módulo registra la adquisición de mercadería.

### Proveedor

Representa a las personas o empresas a las que el local compra mercadería.

### Compra

Registra una compra realizada a un proveedor.

Contendrá, entre otros datos:

- Fecha
- Proveedor
- Total

### DetalleCompra

Indica qué variantes de productos forman parte de una compra.

Ejemplo:

> Compra #25  
> 10 Remeras Oversize M negras  
> 5 Remeras Oversize L negras  
> 8 Bermudas Baggy M celestes

Se relaciona con **Compra** y **VarianteProducto**.

---

## 3. Ventas

Este módulo registra las ventas realizadas por el local.

### Cliente

Representa al cliente que realiza una compra.

### Venta

Registra una operación de venta.

Contendrá:

- Fecha
- Cliente
- Usuario que realizó la venta
- Total

### DetalleVenta

Indica qué productos y cantidades forman parte de una venta.

Ejemplo:

> Venta #150  
> 1 Remera Oversize M negra  
> 1 Bermuda Baggy L celeste

Se relaciona con **Venta** y **VarianteProducto**.

---

## 4. Control de stock

### MovimientoStock

Registra los movimientos de stock de una variante de producto. En la implementación actual solo se insertan movimientos de tipo **Ajuste** (corrección manual del stock). El `CHECK` admite además `ENTRADA`, `SALIDA` y `DEVOLUCION`, pero ningún objeto los genera.

Se relaciona con **VarianteProducto**.

El stock se controla automáticamente mediante triggers y procedimientos almacenados: las ventas, anulaciones, compras recibidas y ajustes actualizan `VarianteProducto.StockActual` y las alertas de stock mínimo se registran en la tabla auxiliar `AlertaStock`. Las ventas, anulaciones y recepciones no dejan fila en `MovimientoStock`; solo los ajustes quedan registrados ahí.

---

## 5. Usuarios y roles

### Usuario

Representa a las personas que utilizan el sistema.

Ejemplos:

- Administrador
- Vendedor

### Rol

Define el tipo de usuario y sus permisos dentro del sistema.

Ejemplo:

**Administrador**
- Gestionar productos.
- Gestionar proveedores.
- Consultar stock.
- Gestionar usuarios.

**Vendedor**
- Registrar ventas.
- Consultar productos.
- Consultar stock.

---

# 6. Relaciones principales

## Catálogo

```text
CATEGORIA
    │
    │ 1:N
    ▼
PRODUCTO ◄──────── MARCA
    │
    │ 1:N
    ▼
VARIANTE_PRODUCTO
    │
    ├──────── SEGMENTO
    │
    ├──────── TALLE
    │
    └──────── COLOR
```

## Compras

```text
PROVEEDOR
    │
    │ 1:N
    ▼
COMPRA
    │
    │ 1:N
    ▼
DETALLE_COMPRA
    │
    │ N:1
    ▼
VARIANTE_PRODUCTO
```

## Ventas

```text
CLIENTE
    │
    │ 1:N
    ▼
VENTA
    │
    │ 1:N
    ▼
DETALLE_VENTA
    │
    │ N:1
    ▼
VARIANTE_PRODUCTO
```

## Usuarios

```text
ROL
 │
 │ 1:N
 ▼
USUARIO
```

## Stock

```text
VARIANTE_PRODUCTO
        │
        │ 1:N
        ▼
MOVIMIENTO_STOCK
```

---

# 7. Tablas del sistema

| Nº | Tabla | Función |
|---|---|---|
| 1 | **Producto** | Información general del producto |
| 2 | **Categoria** | Tipo de producto |
| 3 | **Segmento** | Público al que está destinada la variante |
| 4 | **Marca** | Marca del producto |
| 5 | **Talle** | Talles disponibles |
| 6 | **Color** | Colores disponibles |
| 7 | **VarianteProducto** | Producto + segmento + talle + color + stock |
| 8 | **Proveedor** | Proveedores de mercadería |
| 9 | **Compra** | Compras realizadas |
| 10 | **DetalleCompra** | Productos incluidos en cada compra |
| 11 | **Cliente** | Clientes |
| 12 | **Venta** | Ventas realizadas |
| 13 | **DetalleVenta** | Productos incluidos en cada venta |
| 14 | **MovimientoStock** | Ajustes manuales de stock |
| 15 | **Usuario** | Personas que utilizan el sistema |
| 16 | **Rol** | Permisos/tipo de usuario |
| 17 | **HistorialPrecio** | Auxiliar: auditoría de cambios de precio |
| 18 | **AlertaStock** | Auxiliar: alertas de stock mínimo |

**Total: 16 tablas principales + 2 auxiliares (18 tablas).**

### 7.1 Vistas de negocio

- `vw_StockVariante`: stock y estado por variante.
- `vw_VentasDetalladas`: ventas con cliente, vendedor y estado.
- `vw_ProductosPremium`: productos activos con precio superior al promedio.
- `vw_CategoriasMasVendidasPorSegmento`: categoría más vendida dentro de cada segmento.

---

# 8. Consideraciones del modelo

### Segmento

La tabla `Segmento` representa el público al que está destinada una variante de producto.

Ejemplo:

```text
Segmento
--------
1 | Hombre
2 | Mujer
3 | Niño
4 | Niña
5 | Unisex
```

La `VarianteProducto` tendrá una referencia hacia `Segmento` mediante una clave foránea. Esto permite que un mismo producto tenga variantes para distintos públicos.

Esto permite realizar consultas como:

- Mostrar todas las variantes destinadas a hombres.
- Mostrar todas las variantes destinadas a mujeres.
- Mostrar todas las variantes destinadas a niños.
- Consultar el stock disponible por segmento.
- Obtener las categorías más vendidas para cada segmento con la vista `vw_CategoriasMasVendidasPorSegmento`.

### VarianteProducto

La tabla `VarianteProducto` permitirá diferenciar las distintas combinaciones de un mismo producto.

Ejemplo:

```text
Producto: Remera Oversize Graffiti

Variante 1 → Talle M + Color Negro → Stock: 5
Variante 2 → Talle L + Color Negro → Stock: 2
Variante 3 → Talle M + Color Blanco → Stock: 7
```

De esta forma, el stock no se almacena simplemente para el producto general, sino para cada variante específica.

---

# 9. Estado de implementación

El modelo está implementado en los scripts SQL del repositorio:

- `sql/init_db.sql`: 16 tablas principales, claves y restricciones.
- `sql/siam_triggers.sql`: triggers y 2 tablas auxiliares (`HistorialPrecio`, `AlertaStock`).
- `sql/funciones.sql`: funciones de estado de stock y resumen de ventas.
- `sql/vistas.sql`: vistas de negocio, incluida `vw_CategoriasMasVendidasPorSegmento`.
- `sql/sp/`: procedimientos de ventas, compras, anulaciones y ajustes (una línea por llamada).
- `sql/cursores.sql`: informe de reposición de stock.
- `sql/seed_data.sql`: datos de prueba y casos borde.
- `sql/seguridad.sql`: logins, usuarios, roles y permisos del motor.

El orden de ejecución completo está documentado en `docs/ORDEN_EJECUCION.md` y automatizado en `sql/00_master.sql`.
