USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_AjustarStock
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
            PRINT 'Error: El usuario no existe o está inactivo.';
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

        SELECT @StockActual = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF @StockActual IS NULL
        BEGIN
            PRINT 'Error: La variante especificada no existe.';
            RETURN;
        END

        SET @Diferencia = @NuevaCantidad - @StockActual;

        IF (@Diferencia = 0)
        BEGIN
            SELECT @IdVariante AS IdVariante, @StockActual AS StockActual, 'No hubo diferencia. No se registró ajuste.' AS Mensaje;
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Guardar datos de sesión para triggers
        EXEC sys.sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        SELECT @IdMovimiento = ISNULL(MAX(IdMovimiento), 0) + 1 FROM MovimientoStock;

        -- Inserción del movimiento: TR_AplicarAjusteStock actualiza VarianteProducto.StockActual
        INSERT INTO MovimientoStock (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
        VALUES (@IdMovimiento, @IdVariante, @IdUsuario, GETDATE(), 'AJUSTE', @Diferencia, @Observacion);

        COMMIT TRANSACTION;

        SELECT
            @IdVariante AS IdVariante,
            @StockActual AS StockAnterior,
            @NuevaCantidad AS StockNuevo,
            @Diferencia AS Diferencia,
            'Ajuste de stock aplicado exitosamente mediante trigger' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO