USE SIAM;
GO

-- Crea el procedimiento si no existe o actualiza su definicion si ya existe.
-- Se puede ejecutar para consultar que productos requieren reposicion.
CREATE OR ALTER PROCEDURE dbo.SP_InformeReposicionStock
AS
BEGIN

    SET NOCOUNT ON;

    -- Variables que reciben los valores de CADA fila leida por el cursor.
    DECLARE @IdVariante INT;
    DECLARE @SKU VARCHAR(30);
    DECLARE @Producto VARCHAR(100);
    DECLARE @StockActual INT;
    DECLARE @StockMinimo INT;
    -- Variables donde guardamos los calculos para la variante actual.
    DECLARE @Objetivo INT;
    DECLARE @CantidadSugerida INT;
    DECLARE @Prioridad VARCHAR(15);

    -- Tabla variable temporal: acumula los resultados procesados
    -- y permite devolverlos todos juntos al finalizar el recorrido.
    DECLARE @Informe TABLE
    (
        IdVariante INT,
        SKU VARCHAR(30),
        Producto VARCHAR(100),
        StockActual INT,
        StockMinimo INT,
        CantidadSugerida INT,
        Prioridad VARCHAR(15)
    );

-- Cursor que recorre, uno por uno, los productos que necesitan reposicion.
-- LOCAL limita su alcance y FAST_FORWARD permite recorrerlos hacia adelante.

    DECLARE cursor_reposicion CURSOR LOCAL FAST_FORWARD FOR
        SELECT v.IdVariante, v.SKU, p.Nombre,
               v.StockActual, v.StockMinimo
        -- Une cada variante con su producto para obtener el nombre.
        FROM dbo.VarianteProducto AS v
        INNER JOIN dbo.Producto AS p ON p.IdProducto = v.IdProducto
        -- Solo se incluyen productos activos con stock actual
        -- menor o igual al minimo permitido para esa variante.
        WHERE p.Activo = 1
          AND v.StockActual <= v.StockMinimo
        -- Establece el orden en que se visitaran las variantes.
        ORDER BY v.IdVariante;

    -- intenta recorrer el cursor y armar el informe.
    -- Si ocurre un error de ejecucion, se pasa al CATCH.
    BEGIN TRY
    -- Abre el cursor para comenzar a recorrer los registros.
        OPEN cursor_reposicion;

    -- Obtiene el primer registro y guarda sus datos
    -- en las variables declaradas anteriormente.

        FETCH NEXT FROM cursor_reposicion
            INTO @IdVariante, @SKU, @Producto, @StockActual, @StockMinimo;

-- Mientras existan registros disponibles, se ejecuta
-- el bloque de instrucciones para cada variante.

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Determina cuanto stock se desea alcanzar:
            -- si el minimo es 0, el objetivo es 1 unidad;
            -- de lo contrario, es el doble del minimo.
            SET @Objetivo = CASE
                WHEN @StockMinimo = 0 THEN 1
                ELSE @StockMinimo * 2
            END;

            -- Calcula cuantas unidades faltan para llegar al objetivo.

            SET @CantidadSugerida = @Objetivo - @StockActual;
            -- Clasifica la reposicion: sin unidades => URGENTE;
            -- con un valor distinto de cero => NORMAL.
            SET @Prioridad = CASE
                WHEN @StockActual = 0 THEN 'URGENTE'
                ELSE 'NORMAL'
            END;

            INSERT INTO @Informe
            (
                IdVariante, SKU, Producto, StockActual, StockMinimo,
                CantidadSugerida, Prioridad
            )
            VALUES
            (
                @IdVariante, @SKU, @Producto, @StockActual, @StockMinimo,
                @CantidadSugerida, @Prioridad
            );

            -- Avanza a la siguiente fila para repetir los calculos.
            FETCH NEXT FROM cursor_reposicion
                INTO @IdVariante, @SKU, @Producto, @StockActual, @StockMinimo;
        END;

        CLOSE cursor_reposicion;

        DEALLOCATE cursor_reposicion;

        -- Devuelve todas las filas calculadas. Primero aparecen
        -- las URGENTES; luego, las NORMALES. En cada grupo se
        -- ordena por IdVariante.
        SELECT IdVariante, SKU, Producto, StockActual, StockMinimo,
               CantidadSugerida, Prioridad
        FROM @Informe
        ORDER BY CASE WHEN Prioridad = 'URGENTE' THEN 0 ELSE 1 END, IdVariante;
    END TRY

    BEGIN CATCH
        -- Si el cursor existe y esta abierto, lo cierra.
        IF CURSOR_STATUS('local', 'cursor_reposicion') >= 0
            CLOSE cursor_reposicion;
        -- Si el cursor sigue existiendo, libera su definicion.
        IF CURSOR_STATUS('local', 'cursor_reposicion') > -3
            DEALLOCATE cursor_reposicion;

        THROW;
    END CATCH;
END;
GO