USE SIAM;
GO

-- informe de reposicion: recorre con un cursor las variantes que quedaron
-- en el minimo o por debajo y calcula cuanto pedir de cada una
-- EXEC dbo.SP_InformeReposicionStock;

CREATE OR ALTER PROCEDURE dbo.SP_InformeReposicionStock
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SKU              VARCHAR(30);
    DECLARE @Producto         VARCHAR(100);
    DECLARE @StockActual      INT;
    DECLARE @StockMinimo      INT;
    DECLARE @Objetivo         INT;
    DECLARE @CantidadSugerida INT;
    DECLARE @Prioridad        VARCHAR(10);
    DECLARE @Cantidad         INT = 0;

    -- por si el cursor quedó abierto de antes
    IF CURSOR_STATUS('global', 'cursor_reposicion') >= 0
        CLOSE cursor_reposicion;
    IF CURSOR_STATUS('global', 'cursor_reposicion') >= -1
        DEALLOCATE cursor_reposicion;

    DECLARE cursor_reposicion CURSOR FOR
        SELECT v.SKU, p.Nombre, v.StockActual, v.StockMinimo
        FROM VarianteProducto v
        INNER JOIN Producto p ON p.IdProducto = v.IdProducto
        WHERE p.Activo = 1
          AND v.StockActual <= v.StockMinimo
        ORDER BY v.StockActual, v.IdVariante;

    OPEN cursor_reposicion;

    FETCH NEXT FROM cursor_reposicion
        INTO @SKU, @Producto, @StockActual, @StockMinimo;

    PRINT 'INFORME DE REPOSICIÓN DE STOCK';
    PRINT '------------------------------';

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- objetivo: el doble del minimo
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

    CLOSE cursor_reposicion;

    DEALLOCATE cursor_reposicion;
END;
GO
