USE SIAM;
GO

CREATE PROCEDURE SP_AjustarStock
    @IdVariante     INT,
    @NuevaCantidad  INT,
    @IdUsuario      INT,
    @Observacion    VARCHAR(200) = 'Ajuste manual de inventario'
AS
BEGIN
    DECLARE @StockActual INT;
    DECLARE @Diferencia INT;
    DECLARE @IdMovimiento INT;

    BEGIN TRY
        -- 1. VALIDACIONES 
        IF (@NuevaCantidad < 0)
        BEGIN
            PRINT 'Error: La nueva cantidad de stock no puede ser negativa.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            PRINT 'Error: El usuario que realiza el ajuste no existe o está inactivo.';
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            INNER JOIN Rol r ON r.IdRol = u.IdRol
            WHERE u.IdUsuario = @IdUsuario
              AND u.Activo = 1
              AND r.Nombre = 'Administrador'
        )
        BEGIN
            PRINT 'Error: Solo un usuario Administrador activo puede ajustar stock.';
            RETURN;
        END

        -- Verificar existencia de la variante y capturar stock actual
        SELECT @StockActual = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF @StockActual IS NULL
        BEGIN
            PRINT 'Error: La variante especificada no existe.';
            RETURN;
        END

        -- Calcular diferencia
        SET @Diferencia = @NuevaCantidad - @StockActual;

        IF (@Diferencia = 0)
        BEGIN
            SELECT @IdVariante AS IdVariante, @StockActual AS StockActual, 'No hubo diferencia. No se registró ajuste.' AS Mensaje;
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Generar ID con MAX e ISNULL
        SELECT @IdMovimiento = ISNULL(MAX(IdMovimiento), 0) + 1 FROM MovimientoStock;

        -- Registrar el movimiento de ajuste
        INSERT INTO MovimientoStock (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
        VALUES (@IdMovimiento, @IdVariante, @IdUsuario, GETDATE(), 'AJUSTE', @Diferencia, @Observacion);

        COMMIT TRANSACTION;

        -- 3. RESULTADO DE SALIDA
        SELECT
            @IdVariante AS IdVariante,
            @StockActual AS StockAnterior,
            @NuevaCantidad AS StockNuevo,
            @Diferencia AS Diferencia,
            'Ajuste de stock registrado correctamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO