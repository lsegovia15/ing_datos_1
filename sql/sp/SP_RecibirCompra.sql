USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_RecibirCompra
    @IdCompra  INT,
    @IdUsuario INT -- Usuario que recibe físicamente la compra
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY
        SET XACT_ABORT ON;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50113, 'El usuario que recibe la compra no existe o está inactivo.', 1;
        END;

        BEGIN TRANSACTION;

        -- Bloqueo de la compra para que dos recepciones concurrentes no
        -- ingresen el stock dos veces.
        SELECT @EstadoActual = Estado
        FROM Compra WITH (UPDLOCK, HOLDLOCK)
        WHERE IdCompra = @IdCompra;

        IF @EstadoActual IS NULL
        BEGIN
            THROW 50110, 'La compra especificada no existe.', 1;
        END;

        IF @EstadoActual <> 'PENDIENTE'
        BEGIN
            THROW 50112, 'Solo una compra en estado PENDIENTE puede recibirse.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM DetalleCompra WHERE IdCompra = @IdCompra)
        BEGIN
            THROW 50111, 'No se puede recibir una compra sin líneas de detalle.', 1;
        END;

        -- El trigger TR_Compra_CambioEstado usa este contexto para registrar
        -- los movimientos de ENTRADA a nombre de quien recibe.
        EXEC sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        UPDATE Compra
        SET Estado = 'RECIBIDA'
        WHERE IdCompra = @IdCompra
          AND Estado = 'PENDIENTE';

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50112, 'La compra cambió de estado y no puede recibirse.', 1;
        END;

        EXEC sp_set_session_context @key = N'IdUsuarioOperacion', @value = NULL;

        COMMIT TRANSACTION;

        SELECT @IdCompra AS IdCompraRecibida,
               'Compra recibida y stock actualizado exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        EXEC sp_set_session_context @key = N'IdUsuarioOperacion', @value = NULL;

        THROW;
    END CATCH
END;
GO
