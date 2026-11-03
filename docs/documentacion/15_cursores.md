# 15. Cursores

Script: `sql/cursores.sql`

## SP_InformeReposicionStock

### Problema que se desea resolver

El administrador necesita saber qué variantes hay que reponer, en qué cantidad y con qué urgencia, para armar el pedido al proveedor. No alcanza con listar las variantes con stock bajo: para cada una hay que decidir cuánto pedir y qué prioridad tiene.

### Registros procesados

El cursor recorre las variantes de **productos activos** cuyo stock está en el mínimo o por debajo:

```sql
SELECT v.IdVariante, v.SKU, p.Nombre, v.StockActual, v.StockMinimo
FROM VarianteProducto v
INNER JOIN Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1
  AND v.StockActual <= v.StockMinimo
ORDER BY v.IdVariante;
```

### Operación realizada sobre cada registro

Para cada variante:

1. **Calcula el stock objetivo:** el doble del mínimo, para no volver a quedar al límite apenas se venda una unidad. Si el mínimo es 0, el objetivo es 1, para que la variante no quede sin stock.
2. **Calcula la cantidad sugerida:** `Objetivo - StockActual`.
3. **Asigna la prioridad:** `URGENTE` si el stock es 0 (no se puede vender) o `NORMAL` si queda algo.
4. **Inserta el resultado** en una variable de tabla `@Informe`.

Al terminar, devuelve el informe ordenado con los urgentes primero.

### Ejemplo

Con stock mínimo 3:

| Stock actual | Objetivo | Sugerido | Prioridad |
|---|---|---|---|
| 0 | 6 | 6 | URGENTE |
| 2 | 6 | 4 | NORMAL |

```sql
EXEC SP_InformeReposicionStock;
```

### Motivo por el cual se utiliza un cursor

- **La decisión es por variante.** Cada registro pasa por varias reglas en secuencia (objetivo, cantidad, prioridad). Escrito con un cursor, cada regla es una línea clara y fácil de modificar. Por ejemplo, se podría agregar que ciertas categorías tengan otro objetivo sin reescribir una consulta compleja.
- **Volumen acotado.** Solo se procesan las variantes con stock bajo, que en un local de indumentaria son pocas decenas. El costo de procesar fila por fila es despreciable.
- **No bloquea la operación.** Es un cursor de solo lectura sobre datos que no modifica, así que no interfiere con las ventas en curso.

> **Alternativa considerada:** este cálculo también se puede resolver con un solo `SELECT` que use `CASE`. Se eligió el cursor porque cada variante requiere una evaluación propia que puede crecer con nuevas reglas de reposición, y porque el volumen de datos lo permite sin impacto en el rendimiento. Si el catálogo creciera mucho, convendría pasar a la versión de conjunto.

### Buenas prácticas aplicadas

- **`LOCAL`:** el cursor solo existe dentro del procedimiento y no choca con otros cursores de la sesión.
- **`FAST_FORWARD`:** es de solo avance y solo lectura, el tipo de cursor más liviano.
- **Liberación garantizada:** `CLOSE` y `DEALLOCATE` se ejecutan al terminar y también en el `CATCH`, verificando antes con `CURSOR_STATUS` si el cursor sigue abierto. Si ocurre un error en medio del recorrido, el cursor no queda ocupando recursos.
