USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_RecibirCompra
    @IdCompra  INT,
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
            PRINT 'Error: Solo un usuario Administrador activo puede recibir compras.';
            RETURN;
        END

        SELECT @EstadoActual = Estado
        FROM Compra
        WHERE IdCompra = @IdCompra;

        IF @EstadoActual IS NULL
        BEGIN
            PRINT 'Error: La compra especificada no existe.';
            RETURN;
        END

        IF (@EstadoActual <> 'PENDIENTE')
        BEGIN
            PRINT 'Error: Solo una compra en estado PENDIENTE puede recibirse.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM DetalleCompra WHERE IdCompra = @IdCompra)
        BEGIN
            PRINT 'Error: No se puede recibir una compra sin líneas de detalle.';
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Guardar datos de sesión para triggers
        EXEC sys.sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        -- Al actualizar a RECIBIDA, el trigger TR_SumarStockCompra ingresa las unidades al inventario
        UPDATE Compra
        SET Estado = 'RECIBIDA'
        WHERE IdCompra = @IdCompra;

        COMMIT TRANSACTION;

        SELECT @IdCompra AS IdCompraRecibida,
               'Compra recibida y stock sumado exitosamente por el trigger' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO