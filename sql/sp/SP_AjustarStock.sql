USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_AjustarStock
    @IdVariante     INT,
    @NuevaCantidad  INT,
    @IdUsuario      INT,
    @Observacion    VARCHAR(200) = 'Ajuste manual de inventario'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StockActual INT;
    DECLARE @Diferencia INT;
    DECLARE @IdMovimiento INT;

    BEGIN TRY
        SET XACT_ABORT ON;

        -- 1. VALIDACIONES BÁSICAS
        IF (@NuevaCantidad < 0)
        BEGIN
            THROW 50020, 'La nueva cantidad de stock no puede ser negativa.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario)
        BEGIN
            THROW 50021, 'El usuario que realiza el ajuste no existe.', 1;
        END;

        -- 2. TRANSACCIÓN
        -- El stock se lee DENTRO de la transacción y bloqueado: si se leyera antes,
        -- una venta concurrente podría cambiarlo y la diferencia calculada quedaría mal.
        BEGIN TRANSACTION;

        -- Generar el ID del movimiento. Se bloquea MovimientoStock primero (mismo orden
        -- que usan los triggers de venta/compra) para no chocar IDs ni generar deadlocks.
        SELECT @IdMovimiento = ISNULL(MAX(IdMovimiento), 0) + 1
        FROM MovimientoStock WITH (UPDLOCK, HOLDLOCK);

        -- Obtener el stock actual de la variante, bloqueando la fila hasta el COMMIT
        SELECT @StockActual = StockActual
        FROM VarianteProducto WITH (UPDLOCK, HOLDLOCK)
        WHERE IdVariante = @IdVariante;

        IF @StockActual IS NULL
        BEGIN
            THROW 50022, 'La variante especificada no existe.', 1;
        END;

        -- Calcular la diferencia (si da 0, no hay nada que ajustar)
        SET @Diferencia = @NuevaCantidad - @StockActual;

        IF @Diferencia = 0
        BEGIN
            COMMIT TRANSACTION;

            -- No es un error, pero avisamos que no se hizo nada
            SELECT @IdVariante AS IdVariante, @StockActual AS StockActual, 'No hubo diferencia. No se registró ajuste.' AS Mensaje;
            RETURN;
        END;

        -- Insertar el movimiento con la diferencia firmada:
        -- si la diferencia es negativa (faltaba stock), el trigger la resta.
        INSERT INTO MovimientoStock (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
        VALUES (@IdMovimiento, @IdVariante, @IdUsuario, GETDATE(), 'AJUSTE', @Diferencia, @Observacion);

        -- VarianteProducto.StockActual lo actualiza el trigger.

        COMMIT TRANSACTION;

        -- 3. MENSAJE DE ÉXITO
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
