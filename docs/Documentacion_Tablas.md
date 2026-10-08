# TPO – Sistema de gestión para local de ropa

## 1. Catálogo

El módulo de catálogo contiene la información necesaria para identificar y organizar los productos que comercializa el local.

### Producto

Representa cada producto comercializado por el local.

Se relaciona con:

- **Categoría**
- **Marca**
- **CategoríaSegmento / Público**
- **VarianteProducto**

Ejemplo:

> Remera Oversize Graffiti → Categoría: Remeras → Marca: Nangallery → Público: Hombre.

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

### CategoríaSegmento

Indica **a qué público está destinado el producto**.

Ejemplos:

- Hombre
- Mujer
- Niño

> En el dibujo aparece como **“Público”**. Para el TPO se utilizará `CategoriaSegmento`, ya que representa el segmento al que está destinado el producto.

### VarianteProducto

Representa una combinación específica de un producto con sus características de venta.

Contendrá:

- Producto
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

Registra los movimientos que afectan al stock de una variante de producto.

Tipos de movimiento:

- **Entrada:** ingreso de mercadería por una compra.
- **Salida:** producto vendido.
- **Ajuste:** corrección manual del stock.

Se relaciona con **VarianteProducto**.

Esta tabla también permitirá posteriormente implementar mecanismos de control del stock mediante triggers.

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
    │
    └──────── CATEGORIA_SEGMENTO
    │
    │ 1:N
    ▼
VARIANTE_PRODUCTO
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
| 3 | **CategoriaSegmento** | Público al que está destinado |
| 4 | **Marca** | Marca del producto |
| 5 | **Talle** | Talles disponibles |
| 6 | **Color** | Colores disponibles |
| 7 | **VarianteProducto** | Producto + talle + color + stock |
| 8 | **Proveedor** | Proveedores de mercadería |
| 9 | **Compra** | Compras realizadas |
| 10 | **DetalleCompra** | Productos incluidos en cada compra |
| 11 | **Cliente** | Clientes |
| 12 | **Venta** | Ventas realizadas |
| 13 | **DetalleVenta** | Productos incluidos en cada venta |
| 14 | **MovimientoStock** | Entradas, salidas y ajustes de stock |
| 15 | **Usuario** | Personas que utilizan el sistema |
| 16 | **Rol** | Permisos/tipo de usuario |

**Total: 16 tablas.**

---

# 8. Consideraciones del modelo

### CategoríaSegmento

La tabla `CategoriaSegmento` representa el público al que está destinado un producto.

Ejemplo:

```text
CategoriaSegmento
-----------------
1 | Hombre
2 | Mujer
3 | Niño
```

El `Producto` tendrá una referencia hacia `CategoriaSegmento` mediante una clave foránea.

Esto permite realizar consultas como:

- Mostrar todos los productos destinados a hombres.
- Mostrar todos los productos destinados a mujeres.
- Mostrar todos los productos destinados a niños.
- Consultar el stock disponible por segmento.
- Obtener las categorías más vendidas para cada segmento.

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

# 9. Próximo paso

Una vez aprobada esta propuesta de tablas, se deberán definir:

1. Los atributos de cada tabla.
2. Las claves primarias (PK).
3. Las claves foráneas (FK).
4. Las relaciones y cardinalidades.
5. Las restricciones de integridad.
6. El DER definitivo.
7. El modelo relacional.
8. Las consultas SQL.
9. Los triggers, procedimientos, cursores y roles requeridos por el TPO.
