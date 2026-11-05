# Documentación – Firme38 (SIAM)

Documentación del Trabajo Práctico Integrador de Ingeniería de Datos 1, organizada según la sección 20 del enunciado.

## Índice

| # | Sección | Documento | Script relacionado |
|---|---|---|---|
| 1–2 | Carátula e integrantes | [01_caratula.md](01_caratula.md) | |
| 3 | Descripción del sistema | [03_descripcion_sistema.md](03_descripcion_sistema.md) | |
| 4 | Universo del Discurso | [04_universo_del_discurso.md](04_universo_del_discurso.md) | |
| 5 | Reglas de negocio | [05_reglas_de_negocio.md](05_reglas_de_negocio.md) | |
| 6 | DER | [06_der.md](06_der.md) | |
| 7 | Proceso de normalización | [07_normalizacion.md](07_normalizacion.md) | |
| 8 | Modelo de tablas | [08_modelo_tablas.md](08_modelo_tablas.md) | `sql/init_db.sql` |
| 9 | Diccionario de datos | [09_diccionario_datos.md](09_diccionario_datos.md) | `sql/init_db.sql` |
| 10 | Consultas SQL | [10_consultas.md](10_consultas.md) | `sql/sp/ConsultasAvanzadas.sql` |
| 11 | Subconsultas | [11_subconsultas.md](11_subconsultas.md) | `sql/Subconsultas.sql` |
| 12 | Vistas | [12_vistas.md](12_vistas.md) | `sql/vistas.sql` |
| 13 | Stored Procedures | [13_stored_procedures.md](13_stored_procedures.md) | `sql/sp/*.sql` |
| 14 | Triggers | [14_triggers.md](14_triggers.md) | `sql/siam_triggers.sql` |
| 15 | Cursores | [15_cursores.md](15_cursores.md) | `sql/cursores.sql` |
| 16 | Funciones | [16_funciones.md](16_funciones.md) | `sql/funciones.sql` |
| 17 | Manejo de errores | [17_manejo_errores.md](17_manejo_errores.md) | todos |
| 18 | Seguridad de la base de datos | [18_seguridad.md](18_seguridad.md) | `sql/seguridad.sql` |
| 19 | Centralización de la lógica en la capa de datos | [19_centralizacion.md](19_centralizacion.md) | todos |
| 20 | Conclusiones | [20_conclusiones.md](20_conclusiones.md) | |

## Script de la base de datos: orden de ejecución

Los scripts dependen unos de otros. La forma más simple de crear todo es ejecutar `sql/00_master.sql` en modo SQLCMD, que corre el resto en orden:

```
cd sql
sqlcmd -S localhost -E -C -b -i 00_master.sql
```

En SSMS hay que habilitar **Query → SQLCMD Mode** antes de abrir el archivo. Se necesita un usuario `sysadmin`, porque el script crea la base y los logins.

El orden que sigue el script maestro es:

| # | Script | Crea |
|---|---|---|
| 1 | `sql/init_db.sql` | Base de datos, tablas, restricciones e índices (borra la base si ya existe) |
| 2 | `sql/siam_triggers.sql` | Tablas `HistorialPrecio` y `AlertaStock`, y los 8 triggers |
| 3 | `sql/funciones.sql` | Funciones |
| 4 | `sql/vistas.sql` | Vistas |
| 5 | `sql/sp/SPs.sql` | Tipos de tabla `TipoDetalleVenta` y `TipoDetalleCompra` |
| 6 | `sql/sp/SP_RegistrarVenta.sql`<br>`sql/sp/SP_AnularVenta.sql`<br>`sql/sp/SP_AjustarStock.sql`<br>`sql/sp/SP_RegistrarCompra.sql`<br>`sql/sp/SP_RecibirCompra.sql` | Stored procedures de operación |
| 7 | `sql/cursores.sql` | `SP_InformeReposicionStock` (usa un cursor) |
| 8 | `sql/seed_data.sql` | Datos de prueba (no se vuelve a cargar si ya hay datos) |
| 9 | `sql/seguridad.sql` | Logins, usuarios, roles de base de datos y permisos |

Las consultas de `sql/Subconsultas.sql` y `sql/sp/ConsultasAvanzadas.sql` no crean objetos: se ejecutan una vez cargados los datos.

## Vista general de la arquitectura

La lógica de negocio se reparte en capas dentro del motor:

```
 Aplicación / usuario  (login con rol de base: administrador o vendedor)
        │
        ▼
 Stored Procedures ── validan parámetros y reglas, abren la transacción
        │
        ▼
 Tablas (Venta, DetalleVenta, Compra, MovimientoStock...)
        │  restricciones: PK, FK, UNIQUE, CHECK
        ▼
 Triggers ── actualizan StockActual, recalculan el total de la venta,
             auditan precios y alertan stock bajo
```

`VarianteProducto.StockActual` lo actualizan los triggers de venta, anulación, recepción de compra y ajuste. `MovimientoStock` registra los ajustes manuales.
