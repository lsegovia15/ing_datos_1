USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_AnularVenta
    @IdVenta INT,
    @IdUsuario INT
AS
BEGIN
    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY
        -- 1. VALIDACIONES
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
            PRINT 'Error: Solo un usuario Administrador activo puede anular ventas.';
            RETURN;
        END

        SELECT @EstadoActual = Estado
        FROM Venta
        WHERE IdVenta = @IdVenta;

        IF @EstadoActual IS NULL
        BEGIN
            PRINT 'Error: La venta especificada no existe.';
            RETURN;
        END

        IF (@EstadoActual = 'ANULADA')
        BEGIN
            PRINT 'Error: La venta ya se encuentra anulada.';
            RETURN;
        END

        IF (@EstadoActual <> 'CONFIRMADA')
        BEGIN
            PRINT 'Error: Solo se pueden anular ventas en estado CONFIRMADA.';
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Datos de sesión para triggers
        EXEC sys.sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        -- Dispara el trigger TR_DevolverStockAnulacion
        UPDATE Venta
        SET Estado = 'ANULADA'
        WHERE IdVenta = @IdVenta;

        COMMIT TRANSACTION;

        SELECT @IdVenta AS IdVentaAnulada, 'Venta anulada y stock devuelto exitosamente por el trigger' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO