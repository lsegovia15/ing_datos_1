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

        -- 1. VALIDACIONES DE USUARIO Y ROL
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario)
        BEGIN
            THROW 50012, 'El usuario que anula la venta no existe.', 1;
        END;

        -- Regla de negocio: solo un Administrador activo puede anular ventas.
        -- Un Vendedor puede registrar ventas, pero no anularlas.
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            INNER JOIN Rol r ON r.IdRol = u.IdRol
            WHERE u.IdUsuario = @IdUsuario
              AND u.Activo = 1
              AND r.Nombre = 'Administrador'
        )
        BEGIN
            THROW 50013, 'Solo un usuario Administrador activo puede anular ventas.', 1;
        END;

        -- 2. TRANSACCIÓN
        -- El estado se lee con UPDLOCK/HOLDLOCK para que dos anulaciones
        -- concurrentes no procesen dos veces la devolución de stock.
        BEGIN TRANSACTION;

        SELECT @EstadoActual = Estado
        FROM Venta WITH (UPDLOCK, HOLDLOCK)
        WHERE IdVenta = @IdVenta;

        IF @EstadoActual IS NULL
        BEGIN
            THROW 50010, 'La venta especificada no existe.', 1;
        END;

        IF @EstadoActual = 'ANULADA'
        BEGIN
            THROW 50011, 'La venta ya se encuentra anulada.', 1;
        END;

        IF @EstadoActual <> 'CONFIRMADA'
        BEGIN
            THROW 50011, 'La venta no se encuentra en un estado que permita anularla.', 1;
        END;

        -- Paso A: guardar quién anula en el contexto de sesión.
        EXEC sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        -- Paso B: Actualizar el estado de la venta (TR_DevolverStockAnulacion devuelve el stock).
        -- El WHERE sobre Estado evita que una anulación concurrente vuelva a
        -- ejecutar la devolución si otra sesión ganó la carrera.
        UPDATE Venta
        SET Estado = 'ANULADA'
        WHERE IdVenta = @IdVenta
          AND Estado = 'CONFIRMADA';

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50011, 'La venta ya fue anulada por otra operación.', 1;
        END;

        EXEC sp_set_session_context @key = N'IdUsuarioOperacion', @value = NULL;

        COMMIT TRANSACTION;

        -- 3. MENSAJE DE ÉXITO
        SELECT @IdVenta AS IdVentaAnulada, 'Venta anulada y stock devuelto exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- El session context no se revierte con el ROLLBACK: lo limpiamos a mano
        EXEC sp_set_session_context @key = N'IdUsuarioOperacion', @value = NULL;

        THROW;
    END CATCH
END;
GO
