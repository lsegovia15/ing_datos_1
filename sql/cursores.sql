USE SIAM;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InformeReposicionStock
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdVariante INT;
    DECLARE @SKU VARCHAR(30);
    DECLARE @Producto VARCHAR(100);
    DECLARE @StockActual INT;
    DECLARE @StockMinimo INT;
    DECLARE @Objetivo INT;
    DECLARE @CantidadSugerida INT;
    DECLARE @Prioridad VARCHAR(15);

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

    DECLARE cursor_reposicion CURSOR LOCAL FAST_FORWARD FOR
        SELECT v.IdVariante, v.SKU, p.Nombre,
               v.StockActual, v.StockMinimo
        FROM dbo.VarianteProducto AS v
        INNER JOIN dbo.Producto AS p ON p.IdProducto = v.IdProducto
        WHERE p.Activo = 1
          AND v.StockActual <= v.StockMinimo
        ORDER BY v.IdVariante;

    BEGIN TRY
        OPEN cursor_reposicion;

        FETCH NEXT FROM cursor_reposicion
            INTO @IdVariante, @SKU, @Producto, @StockActual, @StockMinimo;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Objetivo = CASE
                WHEN @StockMinimo = 0 THEN 1
                ELSE @StockMinimo * 2
            END;

            SET @CantidadSugerida = @Objetivo - @StockActual;
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

            FETCH NEXT FROM cursor_reposicion
                INTO @IdVariante, @SKU, @Producto, @StockActual, @StockMinimo;
        END;

        CLOSE cursor_reposicion;

        DEALLOCATE cursor_reposicion;

        SELECT IdVariante, SKU, Producto, StockActual, StockMinimo,
               CantidadSugerida, Prioridad
        FROM @Informe
        ORDER BY CASE WHEN Prioridad = 'URGENTE' THEN 0 ELSE 1 END, IdVariante;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cursor_reposicion') >= 0
            CLOSE cursor_reposicion;
        IF CURSOR_STATUS('local', 'cursor_reposicion') > -3
            DEALLOCATE cursor_reposicion;

        THROW;
    END CATCH;
END;
GO