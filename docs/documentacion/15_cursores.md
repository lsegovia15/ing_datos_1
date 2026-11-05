# 15. Cursores

Script: `sql/cursores.sql`

## SP_InformeReposicionStock

### Problema que se desea resolver

El administrador necesita saber qué variantes hay que reponer, en qué cantidad y con qué urgencia, para armar el pedido al proveedor. No alcanza con listar las variantes con stock bajo: para cada una hay que decidir cuánto pedir y qué prioridad tiene.

### Registros procesados

El cursor recorre las variantes de **productos activos** cuyo stock está en el mínimo o por debajo:

```sql
DECLARE cursor_reposicion CURSOR FOR
    SELECT v.SKU, p.Nombre, v.StockActual, v.StockMinimo
    FROM VarianteProducto v
    INNER JOIN Producto p ON p.IdProducto = v.IdProducto
    WHERE p.Activo = 1
      AND v.StockActual <= v.StockMinimo
    ORDER BY v.StockActual, v.IdVariante;
```

Se ordenan por stock actual, así las que no tienen stock aparecen primero.

### Operación realizada sobre cada registro

Para cada variante:

1. **Calcula el stock objetivo:** el doble del mínimo, para no volver a quedar al límite apenas se venda una unidad. Si el mínimo es 0, el objetivo es 1.
2. **Calcula la cantidad sugerida:** `Objetivo - StockActual`.
3. **Asigna la prioridad:** `URGENTE` si el stock es 0 (no se puede vender) o `NORMAL` si queda algo.
4. **Muestra un mensaje** con `PRINT` y la información de la variante.

Al final muestra cuántas variantes hay que reponer.

### Fases del cursor

Sigue las mismas fases que el ejemplo de la Clase XI:

| Fase | Instrucción |
|---|---|
| Limpiar un cursor anterior | `IF CURSOR_STATUS('global', 'cursor_reposicion') ...` → `CLOSE` / `DEALLOCATE` |
| Declarar | `DECLARE cursor_reposicion CURSOR FOR SELECT ...` |
| Abrir | `OPEN cursor_reposicion` |
| Obtener el primer registro | `FETCH NEXT FROM cursor_reposicion INTO @SKU, @Producto, @StockActual, @StockMinimo` |
| Recorrer | `WHILE @@FETCH_STATUS = 0 BEGIN ... FETCH NEXT ... END` |
| Cerrar | `CLOSE cursor_reposicion` |
| Liberar memoria | `DEALLOCATE cursor_reposicion` |

El primer paso evita el error "el cursor ya existe" si una ejecución anterior se cortó antes de liberarlo.

### Ejemplo

```sql
EXEC dbo.SP_InformeReposicionStock;
```

Salida (con los datos del seed):

```
INFORME DE REPOSICIÓN DE STOCK
------------------------------
URGENTE - REM-OVG-M-BLA (Remera Oversize Graffiti)
   Stock actual: 0 | Mínimo: 5 | Pedir: 10 unidades
...
NORMAL - REM-OVG-L-NEG (Remera Oversize Graffiti)
   Stock actual: 3 | Mínimo: 5 | Pedir: 7 unidades
------------------------------
Variantes a reponer: 8
```

### Motivo por el cual se utiliza un cursor

- **La decisión es por variante.** Cada registro pasa por varias reglas en secuencia (objetivo, cantidad, prioridad) y genera un mensaje propio. Es el caso de uso de la Clase XI: recorrer registros uno por uno para tomar decisiones individuales.
- **Volumen acotado.** Solo se procesan las variantes con stock bajo, que en un local de indumentaria son pocas. El costo de procesar fila por fila es despreciable.
- **Solo lectura.** El cursor no modifica datos, así que no interfiere con las ventas en curso.

> **Alternativa considerada:** este cálculo también se puede resolver con un solo `SELECT` que use `CASE`, que es más rápido en volúmenes grandes. Se eligió el cursor porque cada variante requiere una evaluación propia que puede crecer con nuevas reglas de reposición y el volumen de datos lo permite.
