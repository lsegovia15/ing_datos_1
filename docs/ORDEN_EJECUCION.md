# Orden de ejecución del motor SIAM

El proyecto se ejecuta de punta a punta con `sql/00_master.sql`. El orden no es arbitrario: cada script depende de objetos creados por el anterior.

> **Advertencia:** `init_db.sql` elimina y recrea la base `SIAM` si ya existe. No ejecutar el master sobre una base con datos reales sin un backup previo. Los logins de `seguridad.sql` viven en el servidor y no se eliminan al recrear la base, así que una segunda ejecución completa del master falla en ese script salvo que se borren los logins o se adapte el archivo.

## 1. Orden recomendado

| Paso | Script | Qué crea / por qué va en ese lugar |
|---|---|---|
| 1 | `sql/init_db.sql` | Crea la base `SIAM` y las 16 tablas principales con sus PK, FK, CHECK e índices. |
| 2 | `sql/siam_triggers.sql` | Crea las 2 tablas auxiliares (`HistorialPrecio`, `AlertaStock`) y los 8 triggers. |
| 3 | `sql/funciones.sql` | Crea `fn_EstadoStock` y `fn_ResumenVentasPorUsuario`; dependen de las tablas. |
| 4 | `sql/vistas.sql` | Crea las 4 vistas de negocio, incluida `vw_CategoriasMasVendidasPorSegmento`. |
| 5 | `sql/sp/SPs.sql` | Crea las tablas temporales `#DetalleVenta` y `#DetalleCompra` para la carga de detalles. |
| 6 | `sql/sp/SP_RegistrarVenta.sql` | SP de ventas; los triggers de `DetalleVenta` descuentan stock y recalculan el total. |
| 7 | `sql/sp/SP_AnularVenta.sql` | SP de anulación; valida rol Administrador. `TR_DevolverStockAnulacion` devuelve el stock. |
| 8 | `sql/sp/SP_AjustarStock.sql` | SP de ajustes; inserta movimientos `AJUSTE`, que aplica `TR_AplicarAjusteStock`. |
| 9 | `sql/sp/SP_RegistrarCompra.sql` | SP de compras; registra una línea en estado `PENDIENTE`. |
| 10 | `sql/sp/SP_RecibirCompra.sql` | SP de recepción; `TR_SumarStockCompra` suma el stock. |
| 11 | `sql/cursores.sql` | Crea `SP_InformeReposicionStock`; usa las tablas y la lógica de stock. |
| 12 | `sql/seed_data.sql` | Carga roles, usuarios, catálogos, compras, ventas, movimientos y casos borde. Usa los SPs y triggers ya creados. |
| 13 | `sql/seguridad.sql` | Crea logins, usuarios, roles y permisos del motor. Va al final, cuando ya existen todos los objetos. |

## 2. Ejecución automática con SQLCMD

Desde la carpeta `sql`:

```powershell
cd sql
sqlcmd -S "localhost\SQLEXPRESS" -E -C -b -f 65001 -i 00_master.sql
```

- `-S` indica el servidor. `localhost` solo funciona si hay una instancia por defecto; en una instalación con instancia nombrada hay que usar `localhost\SQLEXPRESS` (o el nombre que corresponda).
- `-E` usa autenticación de Windows.
- `-C` confía en el certificado del servidor.
- `-b` devuelve código de error si algo falla.
- `-f 65001` interpreta los archivos como UTF-8 (acentos y ñ).
- El script requiere permisos de **sysadmin** porque crea la base y los logins.
- Las rutas de `:r` en `00_master.sql` usan `\\` como separador, por lo que el master está pensado para Windows. En otro sistema hay que correr los scripts uno por uno en el orden de la tabla.

En SSMS: habilitar **SQLCMD Mode**, abrir `sql/00_master.sql` y ejecutar con la carpeta `sql` como directorio de trabajo (o ajustar `:setvar Base` a una ruta absoluta).

## 3. Dependencias que no se deben alterar

- `siam_triggers.sql` **debe** ejecutarse antes de `seed_data.sql`, porque el seed espera que existan `AlertaStock` y los triggers de stock.
- `sp/SPs.sql` se ejecuta antes de los cinco `sp/SP_*.sql`, según el orden del master.
- Los cinco scripts `sp/SP_*.sql` **deben** ejecutarse después de `init_db.sql` y antes de `seed_data.sql`, que los invoca.
- `vistas.sql` **debe** ejecutarse antes de `seguridad.sql`, porque el script de seguridad otorga `SELECT` sobre las vistas.
- `cursores.sql` **debe** ejecutarse antes de `seguridad.sql`, que otorga `EXECUTE` sobre `SP_InformeReposicionStock`.
- `seed_data.sql` **debe** ejecutarse antes de `seguridad.sql` para que los usuarios de aplicación existan; el seed se ejecuta como administrador de la base.
- `seguridad.sql` **debe** ejecutarse al final: crea los usuarios de motor y aplica los `GRANT`.

## 4. Casos borde incluidos en el seed

Las validaciones de los SPs no lanzan excepciones: imprimen un mensaje y salen con `RETURN`. El seed ejecuta cada caso y muestra el resultado de la llamada; el rechazo se reconoce por el mensaje y porque la operación no queda registrada:

- **Venta sin stock:** no se inserta la venta.
- **Compra sin líneas de detalle:** no se inserta la compra.
- **Recepción de compra sin líneas:** la compra sigue `PENDIENTE`.
- **Ajuste sin diferencia:** no se genera movimiento.
- **Anulación duplicada:** la venta sigue `ANULADA` y el stock no cambia.
- **Anulación ejecutada por un vendedor:** la venta sigue `CONFIRMADA` y el stock no cambia.
- **Ajuste ejecutado por un vendedor:** el stock y la cantidad de movimientos no cambian.
- **Compra registrada por un vendedor:** no se inserta la compra.
- **Recepción de compra ejecutada por un vendedor:** la compra sigue `PENDIENTE`.
- **Venta registrada por un usuario inactivo:** no se inserta la venta.

## 5. Consultas opcionales

Después del seed se pueden ejecutar, sin formar parte del motor:

- `sql/Subconsultas.sql`
- `sql/sp/ConsultasAvanzadas.sql`

Ambas usan datos reales del seed (por ejemplo, la marca `Nangallery`) y no crean objetos.
