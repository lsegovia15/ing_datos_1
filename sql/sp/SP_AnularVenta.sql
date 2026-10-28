USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_AnularVenta
    @IdVenta INT,
    @IdUsuario INT -- El usuario que autoriza la anulación
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY
        SET XACT_ABORT ON;

        -- 1. VALIDACIONES
        -- ¿Existe la venta? Guardamos su estado actual.
        SELECT @EstadoActual = Estado FROM Venta WHERE IdVenta = @IdVenta;

        IF @EstadoActual IS NULL
        BEGIN
            THROW 50010, 'La venta especificada no existe.', 1;
        END;

        -- ¿Ya está anulada?
        IF @EstadoActual = 'ANULADA'
        BEGIN
            THROW 50011, 'La venta ya se encuentra anulada.', 1;
        END;

        -- ¿El usuario existe? (Buena práctica)
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario)
        BEGIN
            THROW 50012, 'El usuario que anula la venta no existe.', 1;
        END;

        -- 2. TRANSACCIÓN
        BEGIN TRANSACTION;

        -- Paso A: Actualizar el estado de la venta
        UPDATE Venta 
        SET Estado = 'ANULADA' 
        WHERE IdVenta = @IdVenta;

        COMMIT TRANSACTION;

        -- 3. MENSAJE DE ÉXITO
        SELECT @IdVenta AS IdVentaAnulada, 'Venta anulada y stock devuelto exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO