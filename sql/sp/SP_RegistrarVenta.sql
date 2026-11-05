USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_RegistrarVenta
    @IdCliente      INT = NULL,
    @IdUsuario      INT,
    @MedioPago      VARCHAR(20),
    @IdVariante     INT,
    @Cantidad       INT,
    @PrecioUnitario DECIMAL(12,2),
    @Descuento      DECIMAL(12,2) = 0
AS
BEGIN
    DECLARE @IdVenta INT;
    DECLARE @TotalVenta DECIMAL(12,2);

    BEGIN TRY
        -- 1. VALIDACIONES
        IF (@Cantidad <= 0)
        BEGIN
            PRINT 'Error: La cantidad a vender debe ser mayor a cero.';
            RETURN;
        END

        IF (@PrecioUnitario < 0 OR @Descuento < 0)
        BEGIN
            PRINT 'Error: Los valores de precio o descuento no pueden ser negativos.';
            RETURN;
        END

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
              AND r.Nombre IN ('Administrador', 'Vendedor')
        )
        BEGIN
            PRINT 'Error: El usuario debe tener rol Administrador o Vendedor.';
            RETURN;
        END

        IF (@IdCliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente WHERE IdCliente = @IdCliente))
        BEGIN
            PRINT 'Error: El cliente especificado no existe.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM VarianteProducto WHERE IdVariante = @IdVariante)
        BEGIN
            PRINT 'Error: La variante especificada no existe.';
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Datos de sesión para triggers
        EXEC sys.sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        SELECT @IdVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM Venta;

        -- Inserción de cabecera 
        INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
        VALUES (@IdVenta, @IdCliente, @IdUsuario, GETDATE(), @MedioPago, 0, 'CONFIRMADA');

        -- Inserción de Detalle: dispara TR_DescontarStockVenta y TR_CalcularTotalVenta
        INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
        VALUES (@IdVenta, 1, @IdVariante, @Cantidad, @PrecioUnitario, @Descuento);

        COMMIT TRANSACTION;

        SELECT @TotalVenta = Total FROM Venta WHERE IdVenta = @IdVenta;

        SELECT @IdVenta AS IdVentaGenerada, @TotalVenta AS TotalVenta, 'Venta registrada exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO