USE SIAM;
GO

-- pasa una compra de PENDIENTE a RECIBIDA (solo administrador)
-- el trigger TR_SumarStockCompra suma el stock

CREATE OR ALTER PROCEDURE dbo.SP_RecibirCompra
    @IdCompra  INT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50113, 'El usuario que recibe la compra no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50114, 'Solo un usuario Administrador puede recibir compras.', 1;
        END

        SELECT @EstadoActual = Estado
        FROM Compra
        WHERE IdCompra = @IdCompra;

        IF (@EstadoActual IS NULL)
        BEGIN
            THROW 50110, 'La compra especificada no existe.', 1;
        END

        IF (@EstadoActual <> 'PENDIENTE')
        BEGIN
            THROW 50112, 'Solo una compra en estado PENDIENTE puede recibirse.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM DetalleCompra WHERE IdCompra = @IdCompra)
        BEGIN
            THROW 50111, 'No se puede recibir una compra sin líneas de detalle.', 1;
        END

        BEGIN TRANSACTION;

        UPDATE Compra
        SET Estado = 'RECIBIDA'
        WHERE IdCompra = @IdCompra
          AND Estado = 'PENDIENTE';

        COMMIT TRANSACTION;

        SELECT @IdCompra AS IdCompraRecibida,
               'Compra recibida y stock actualizado' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
