USE SIAM;
GO

-- SP_InformeReposicionStock
--
-- Problema que resuelve: indicar qué variantes hay que reponer y cuántas
-- unidades pedir de cada una.
-- Por qué un cursor: para cada variante se toma una decisión individual
-- (prioridad URGENTE o NORMAL y cantidad a pedir) y se muestra un mensaje
-- distinto según el caso, recorriendo los registros uno por uno.
-- Registros procesados: variantes de productos activos con
-- StockActual <= StockMinimo.
-- Operación sobre cada registro:
--   - Objetivo de stock = el doble del mínimo (o 1 si el mínimo es 0).
--   - Cantidad sugerida = objetivo - stock actual.
--   - Prioridad URGENTE si no queda stock; NORMAL en otro caso.
--
-- Ejemplo:
--   EXEC dbo.SP_InformeReposicionStock;

CREATE OR ALTER PROCEDURE dbo.SP_InformeReposicionStock
AS
BEGIN
    SET NOCOUNT ON;

    -- VARIABLES
    DECLARE @SKU              VARCHAR(30);
    DECLARE @Producto         VARCHAR(100);
    DECLARE @StockActual      INT;
    DECLARE @StockMinimo      INT;
    DECLARE @Objetivo         INT;
    DECLARE @CantidadSugerida INT;
    DECLARE @Prioridad        VARCHAR(10);
    DECLARE @Cantidad         INT = 0;

    -- ELIMINAR CURSOR SI QUEDÓ ABIERTO DE UNA EJECUCIÓN ANTERIOR
    IF CURSOR_STATUS('global', 'cursor_reposicion') >= 0
        CLOSE cursor_reposicion;
    IF CURSOR_STATUS('global', 'cursor_reposicion') >= -1
        DEALLOCATE cursor_reposicion;

    -- DECLARAR CURSOR
    DECLARE cursor_reposicion CURSOR FOR
        SELECT v.SKU, p.Nombre, v.StockActual, v.StockMinimo
        FROM VarianteProducto v
        INNER JOIN Producto p ON p.IdProducto = v.IdProducto
        WHERE p.Activo = 1
          AND v.StockActual <= v.StockMinimo
        ORDER BY v.StockActual, v.IdVariante;

    -- ABRIR CURSOR
    OPEN cursor_reposicion;

    -- OBTENER PRIMER REGISTRO
    FETCH NEXT FROM cursor_reposicion
        INTO @SKU, @Producto, @StockActual, @StockMinimo;

    PRINT 'INFORME DE REPOSICIÓN DE STOCK';
    PRINT '------------------------------';

    -- RECORRER
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Stock que se quiere alcanzar
        IF @StockMinimo = 0
            SET @Objetivo = 1;
        ELSE
            SET @Objetivo = @StockMinimo * 2;

        SET @CantidadSugerida = @Objetivo - @StockActual;

        IF @StockActual = 0
            SET @Prioridad = 'URGENTE';
        ELSE
            SET @Prioridad = 'NORMAL';

        PRINT CONCAT(@Prioridad, ' - ', @SKU, ' (', @Producto, ')');
        PRINT CONCAT('   Stock actual: ', @StockActual,
                     ' | Mínimo: ', @StockMinimo,
                     ' | Pedir: ', @CantidadSugerida, ' unidades');

        SET @Cantidad = @Cantidad + 1;

        FETCH NEXT FROM cursor_reposicion
            INTO @SKU, @Producto, @StockActual, @StockMinimo;
    END;

    PRINT '------------------------------';
    PRINT CONCAT('Variantes a reponer: ', @Cantidad);

    -- CERRAR CURSOR
    CLOSE cursor_reposicion;

    -- LIBERAR MEMORIA
    DEALLOCATE cursor_reposicion;
END;
GO
