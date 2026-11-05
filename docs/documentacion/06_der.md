# 6. Diagrama Entidad-Relación

El diagrama usa notación de "pata de gallo" (*crow's foot*). Cada extremo de una relación indica la cardinalidad y la participación:

| Símbolo | Significado |
|---|---|
| `\|\|` | Exactamente uno (participación obligatoria) |
| `o\|` | Cero o uno (participación opcional) |
| `\|{` | Uno o muchos (participación obligatoria) |
| `o{` | Cero o muchos (participación opcional) |

![DER de SIAM](../DER.png)

La imagen `docs/DER.png` es el render del diagrama de abajo. Si cambia el modelo, se actualiza el bloque Mermaid y se vuelve a exportar la imagen.

```mermaid
erDiagram
    ROL ||--o{ USUARIO : "pertenece"
    CATEGORIA ||--o{ PRODUCTO : "clasifica"
    MARCA ||--o{ PRODUCTO : "fabrica"
    PRODUCTO ||--o{ VARIANTE_PRODUCTO : "se presenta en"
    SEGMENTO ||--o{ VARIANTE_PRODUCTO : "segmenta"
    TALLE ||--o{ VARIANTE_PRODUCTO : "tiene talle"
    COLOR ||--o{ VARIANTE_PRODUCTO : "tiene color"

    PROVEEDOR ||--o{ COMPRA : "provee"
    USUARIO ||--o{ COMPRA : "gestiona"
    COMPRA ||--o{ DETALLE_COMPRA : "incluye"
    VARIANTE_PRODUCTO ||--o{ DETALLE_COMPRA : "se compra en"

    CLIENTE |o--o{ VENTA : "realiza"
    USUARIO ||--o{ VENTA : "registra"
    VENTA ||--|{ DETALLE_VENTA : "contiene"
    VARIANTE_PRODUCTO ||--o{ DETALLE_VENTA : "se vende en"

    VARIANTE_PRODUCTO ||--o{ MOVIMIENTO_STOCK : "afecta"
    USUARIO ||--o{ MOVIMIENTO_STOCK : "ejecuta"
    COMPRA |o--o{ MOVIMIENTO_STOCK : "origina"
    VENTA |o--o{ MOVIMIENTO_STOCK : "genera"

    VARIANTE_PRODUCTO ||--o{ HISTORIAL_PRECIO : "audita"
    VARIANTE_PRODUCTO ||--o{ ALERTA_STOCK : "avisa"

    ROL {
        int IdRol PK
        varchar Nombre UK
        varchar Descripcion
    }
    USUARIO {
        int IdUsuario PK
        int IdRol FK
        varchar NombreUsuario UK
        varchar Email UK
        varchar Contrasena
        varchar Nombre
        varchar Apellido
        int Activo
        datetime FechaAlta
    }
    CATEGORIA {
        int IdCategoria PK
        varchar Nombre UK
        varchar Descripcion
    }
    MARCA {
        int IdMarca PK
        varchar Nombre UK
    }
    SEGMENTO {
        int IdSegmento PK
        varchar Nombre UK
    }
    TALLE {
        int IdTalle PK
        varchar Descripcion UK
    }
    COLOR {
        int IdColor PK
        varchar Nombre UK
    }
    PRODUCTO {
        int IdProducto PK
        int IdCategoria FK
        int IdMarca FK
        varchar Nombre
        varchar Descripcion
        decimal PrecioBase
        int Activo
    }
    VARIANTE_PRODUCTO {
        int IdVariante PK
        int IdProducto FK
        int IdSegmento FK
        int IdTalle FK
        int IdColor FK
        varchar SKU UK
        decimal PrecioVenta
        int StockActual
        int StockMinimo
    }
    PROVEEDOR {
        int IdProveedor PK
        varchar RazonSocial
        varchar CUIT UK
        varchar Telefono
        varchar Email
        varchar Direccion
    }
    COMPRA {
        int IdCompra PK
        int IdProveedor FK
        int IdUsuario FK
        datetime Fecha
        varchar NroComprobante
        decimal Total
        varchar Estado
    }
    DETALLE_COMPRA {
        int IdCompra PK, FK
        int NroLinea PK
        int IdVariante FK
        int Cantidad
        decimal CostoUnitario
    }
    CLIENTE {
        int IdCliente PK
        varchar Nombre
        varchar Apellido
        varchar DNI UK
        varchar Email
        varchar Telefono
        varchar Direccion
    }
    VENTA {
        int IdVenta PK
        int IdCliente FK "NULL = consumidor final"
        int IdUsuario FK
        datetime Fecha
        varchar MedioPago
        decimal Total
        varchar Estado
    }
    DETALLE_VENTA {
        int IdVenta PK, FK
        int NroLinea PK
        int IdVariante FK
        int Cantidad
        decimal PrecioUnitario
        decimal Descuento
    }
    MOVIMIENTO_STOCK {
        int IdMovimiento PK
        int IdVariante FK
        int IdUsuario FK
        datetime Fecha
        varchar TipoMovimiento
        int Cantidad
        int IdCompra FK "NULL si no viene de una compra"
        int IdVenta FK "NULL si no viene de una venta"
        varchar Observacion
    }
    HISTORIAL_PRECIO {
        int IdHistorial PK
        int IdVariante FK
        decimal PrecioAnterior
        decimal PrecioNuevo
        datetime Fecha
    }
    ALERTA_STOCK {
        int IdAlerta PK
        int IdVariante FK
        int StockActual
        int StockMinimo
        datetime Fecha
        int Atendida
    }
```

## Entidades

| Entidad | Tipo | Identificador |
|---|---|---|
| Rol, Categoria, Marca, Segmento, Talle, Color | Fuerte (referencia) | Id propio |
| Usuario, Producto, Proveedor, Cliente | Fuerte | Id propio |
| VarianteProducto | Fuerte | `IdVariante` (claves alternativas: `SKU` y la combinación producto + segmento + talle + color) |
| Compra, Venta, MovimientoStock | Fuerte (transaccional) | Id propio |
| **DetalleCompra** | **Débil**, depende de `Compra` | `IdCompra` + `NroLinea` |
| **DetalleVenta** | **Débil**, depende de `Venta` | `IdVenta` + `NroLinea` |
| HistorialPrecio, AlertaStock | Fuerte (auditoría) | Id autonumérico |

`DetalleCompra` y `DetalleVenta` son **entidades dependientes**: una línea no tiene sentido sin su cabecera, y su identificador incluye el de la cabecera (`NroLinea` solo es único dentro de cada compra o venta).

## Relaciones, cardinalidad y participación

| Relación | Cardinalidad | Participación |
|---|---|---|
| Rol – Usuario | 1 : N | Todo usuario tiene un rol (obligatoria). Un rol puede no tener usuarios |
| Categoría – Producto | 1 : N | Todo producto tiene una categoría (obligatoria) |
| Marca – Producto | 1 : N | Todo producto tiene una marca (obligatoria) |
| Producto – Variante | 1 : N | Toda variante pertenece a un producto (obligatoria). Un producto recién creado puede no tener variantes todavía |
| Segmento / Talle / Color – Variante | 1 : N | Toda variante tiene un segmento, un talle y un color (obligatoria) |
| Proveedor – Compra | 1 : N | Toda compra tiene un proveedor (obligatoria) |
| Compra – DetalleCompra | 1 : N | Toda línea pertenece a una compra. Una compra pendiente puede no tener líneas todavía, pero no se puede recibir sin líneas |
| Cliente – Venta | 1 : N | **Opcional del lado de la venta**: una venta puede no tener cliente (consumidor final) |
| Venta – DetalleVenta | 1 : N | Toda venta tiene **al menos una** línea (lo garantiza `SP_RegistrarVenta`) |
| Variante – DetalleVenta / DetalleCompra | 1 : N | Toda línea refiere a una variante (obligatoria) |
| Usuario – Venta / Compra / Movimiento | 1 : N | Toda operación tiene el usuario que la registró (obligatoria) |
| Variante – Movimiento | 1 : N | Todo movimiento afecta a una variante (obligatoria) |
| Compra / Venta – Movimiento | 1 : N | **Opcional**: un movimiento proviene de una compra, de una venta o de ninguna (ajuste), pero nunca de ambas |
| Variante – HistorialPrecio / AlertaStock | 1 : N | Cada registro pertenece a una variante (obligatoria) |

## Relación ternaria resuelta en VarianteProducto

La variante es la intersección de **producto, segmento, talle y color**. No se modeló como relaciones binarias separadas (producto–talle, producto–color) porque lo que se vende y se stockea es una **combinación concreta**: puede existir la remera en M negra y en L blanca sin que exista la L negra. Esto se justifica formalmente en la [sección 7, formas normales 4 y 5](07_normalizacion.md#cuarta-forma-normal-4fn).
