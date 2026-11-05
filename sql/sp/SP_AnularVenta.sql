USE SIAM;
GO

-- SP_AnularVenta
-- Anula una venta CONFIRMADA. Solo puede hacerlo un Administrador activo.
-- Al pasar la venta a ANULADA se dispara TR_DevolverStockAnulacion,
-- que devuelve el stock.
--
-- Ejemplo:
--   EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 1;

CREATE OR ALTER PROCEDURE dbo.SP_AnularVenta
    @IdVenta   INT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY

        -- 1. VALIDACIONES
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50012, 'El usuario que anula la venta no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50013, 'Solo un usuario Administrador puede anular ventas.', 1;
        END

        SELECT @EstadoActual = Estado
        FROM Venta
        WHERE IdVenta = @IdVenta;

        IF (@EstadoActual IS NULL)
        BEGIN
            THROW 50010, 'La venta especificada no existe.', 1;
        END

        IF (@EstadoActual <> 'CONFIRMADA')
        BEGIN
            THROW 50011, 'La venta ya se encuentra anulada.', 1;
        END

        -- 2. TRANSACCIÓN
        BEGIN TRANSACTION;

        -- Dispara TR_DevolverStockAnulacion
        UPDATE Venta
        SET Estado = 'ANULADA'
        WHERE IdVenta = @IdVenta
          AND Estado = 'CONFIRMADA';

        COMMIT TRANSACTION;

        SELECT @IdVenta AS IdVentaAnulada,
               'Venta anulada y stock devuelto' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
