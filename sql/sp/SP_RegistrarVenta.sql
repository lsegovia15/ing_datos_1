USE SIAM;
GO

-- registra una venta de una variante
-- el precio sale de VarianteProducto para que no se pueda cargar otro
-- los triggers descuentan el stock y calculan el total

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

        BEGIN TRANSACTION;

        -- numero siguiente
        SELECT @IdVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM Venta;

        -- cabecera (el total lo calcula el trigger)
        INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
        VALUES (@IdVenta, @IdCliente, @IdUsuario, GETDATE(), @MedioPago, 0, 'CONFIRMADA');

        -- detalle
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
