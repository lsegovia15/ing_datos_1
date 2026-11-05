USE SIAM;
GO

-- SP_AjustarStock
-- Corrige el stock de una variante después de un recuento físico.
-- Recibe la cantidad contada, calcula la diferencia con el stock del
-- sistema y la registra como movimiento AJUSTE en MovimientoStock.
-- TR_AplicarAjusteStock aplica esa diferencia sobre StockActual.
-- Solo puede hacerlo un Administrador activo.
--
-- Ejemplo:
--   EXEC dbo.SP_AjustarStock @IdVariante = 1, @NuevaCantidad = 17,
--        @IdUsuario = 1, @Observacion = 'Recuento físico';

CREATE OR ALTER PROCEDURE dbo.SP_AjustarStock
    @IdVariante     INT,
    @NuevaCantidad  INT,
    @IdUsuario      INT,
    @Observacion    VARCHAR(200) = 'Ajuste manual de inventario'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StockActual  INT;
    DECLARE @Diferencia   INT;
    DECLARE @IdMovimiento INT;

    BEGIN TRY

        -- 1. VALIDACIONES
        IF (@NuevaCantidad IS NULL OR @NuevaCantidad < 0)
        BEGIN
            THROW 50020, 'La nueva cantidad de stock no puede ser negativa.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50021, 'El usuario que realiza el ajuste no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50023, 'Solo un usuario Administrador puede ajustar stock.', 1;
        END

        SELECT @StockActual = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF (@StockActual IS NULL)
        BEGIN
            THROW 50022, 'La variante especificada no existe.', 1;
        END

        SET @Diferencia = @NuevaCantidad - @StockActual;

        -- Si no hay diferencia no se registra nada
        IF (@Diferencia = 0)
        BEGIN
            SELECT @IdVariante  AS IdVariante,
                   @StockActual AS StockActual,
                   'No hubo diferencia. No se registró ajuste.' AS Mensaje;
            RETURN;
        END

        -- 2. TRANSACCIÓN
        BEGIN TRANSACTION;

        SELECT @IdMovimiento = ISNULL(MAX(IdMovimiento), 0) + 1 FROM MovimientoStock;

        -- Dispara TR_AplicarAjusteStock, que suma la diferencia (con signo)
        INSERT INTO MovimientoStock (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
        VALUES (@IdMovimiento, @IdVariante, @IdUsuario, GETDATE(), 'AJUSTE', @Diferencia, @Observacion);

        COMMIT TRANSACTION;

        SELECT @IdVariante    AS IdVariante,
               @StockActual   AS StockAnterior,
               @NuevaCantidad AS StockNuevo,
               @Diferencia    AS Diferencia,
               'Ajuste de stock registrado' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
