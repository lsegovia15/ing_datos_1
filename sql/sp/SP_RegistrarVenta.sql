USE SIAM;
GO

-- SP_RegistrarVenta
-- Registra la venta de un producto (una variante) en una transacción.
-- El precio unitario se toma de VarianteProducto.PrecioVenta, así el
-- vendedor no puede cargar un precio distinto al del catálogo.
-- Al insertar el detalle se disparan:
--   TR_DescontarStockVenta -> descuenta el stock.
--   TR_CalcularTotalVenta  -> calcula Venta.Total.
--
-- Ejemplo:
--   EXEC dbo.SP_RegistrarVenta @IdCliente = 1, @IdUsuario = 2,
--        @MedioPago = 'EFECTIVO', @IdVariante = 1, @Cantidad = 2;

CREATE OR ALTER PROCEDURE dbo.SP_RegistrarVenta
    @IdCliente      INT = NULL,
    @IdUsuario      INT,
    @MedioPago      VARCHAR(20),
    @IdVariante     INT,
    @Cantidad       INT,
    @Descuento      DECIMAL(12,2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdVenta        INT;
    DECLARE @PrecioUnitario DECIMAL(12,2);
    DECLARE @StockActual    INT;

    BEGIN TRY

        -- 1. VALIDACIONES
        IF (@Cantidad IS NULL OR @Cantidad <= 0)
        BEGIN
            THROW 50001, 'La cantidad a vender debe ser mayor a cero.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50002, 'El usuario que registra la venta no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre IN ('Administrador', 'Vendedor'))
        BEGIN
            THROW 50007, 'El usuario debe tener rol Administrador o Vendedor para registrar ventas.', 1;
        END

        IF (@IdCliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente WHERE IdCliente = @IdCliente))
        BEGIN
            THROW 50003, 'El cliente especificado no existe.', 1;
        END

        IF (@MedioPago IS NULL OR @MedioPago NOT IN ('EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA'))
        BEGIN
            THROW 50004, 'Medio de pago no válido. Use EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA.', 1;
        END

        SELECT @PrecioUnitario = PrecioVenta,
               @StockActual    = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF (@PrecioUnitario IS NULL)
        BEGIN
            THROW 50005, 'La variante especificada no existe.', 1;
        END

        IF (@StockActual < @Cantidad)
        BEGIN
            THROW 50006, 'Stock insuficiente para realizar la venta.', 1;
        END

        IF (@Descuento < 0 OR @Descuento > @Cantidad * @PrecioUnitario)
        BEGIN
            THROW 50008, 'El descuento no puede ser negativo ni mayor al importe de la venta.', 1;
        END

        -- 2. TRANSACCIÓN
        BEGIN TRANSACTION;

        -- Siguiente número de venta
        SELECT @IdVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM Venta;

        -- Cabecera: el total lo calcula TR_CalcularTotalVenta
        INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
        VALUES (@IdVenta, @IdCliente, @IdUsuario, GETDATE(), @MedioPago, 0, 'CONFIRMADA');

        -- Detalle: dispara TR_DescontarStockVenta y TR_CalcularTotalVenta
        INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
        VALUES (@IdVenta, 1, @IdVariante, @Cantidad, @PrecioUnitario, @Descuento);

        COMMIT TRANSACTION;

        SELECT IdVenta AS IdVentaGenerada,
               Total   AS TotalVenta,
               'Venta registrada exitosamente' AS Mensaje
        FROM Venta
        WHERE IdVenta = @IdVenta;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
