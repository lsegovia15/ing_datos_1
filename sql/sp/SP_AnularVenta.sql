USE SIAM;
GO

CREATE PROCEDURE SP_AnularVenta
    @IdVenta INT,
    @IdUsuario INT
AS
BEGIN
    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY
        -- 1. VALIDACIONES 
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario)
        BEGIN
            PRINT 'Error: El usuario que anula la venta no existe.';
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

        -- Verificar existencia de la venta y obtener estado actual
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
            PRINT 'Error: La venta no se encuentra en un estado que permita anularla.';
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Actualización del estado
        UPDATE Venta
        SET Estado = 'ANULADA'
        WHERE IdVenta = @IdVenta;

        COMMIT TRANSACTION;

        SELECT @IdVenta AS IdVentaAnulada, 'Venta anulada y stock devuelto exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
