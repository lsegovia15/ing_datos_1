USE SIAM;
GO

CREATE PROCEDURE SP_RegistrarVenta
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
    DECLARE @Total DECIMAL(12,2);
    DECLARE @StockDisponible INT;

    BEGIN TRY
        -- 1. VALIDACIONES 
        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            PRINT 'Error: El usuario que registra la venta no existe o está inactivo.';
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

        -- Validar stock suficiente
        SELECT @StockDisponible = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF (@StockDisponible < @Cantidad)
        BEGIN
            PRINT 'Error: Stock insuficiente para realizar la venta.';
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Cálculo del total
        SET @Total = (@Cantidad * @PrecioUnitario) - @Descuento;

        -- Generación de clave primaria con MAX e ISNULL
        SELECT @IdVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM Venta;

        -- Inserción de Cabecera
        INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
        VALUES (@IdVenta, @IdCliente, @IdUsuario, GETDATE(), @MedioPago, @Total, 'CONFIRMADA');

        -- Inserción de Detalle (NroLinea fijo = 1 para la línea vendida)
        INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
        VALUES (@IdVenta, 1, @IdVariante, @Cantidad, @PrecioUnitario, @Descuento);

        COMMIT TRANSACTION;

        -- Resultado de salida
        SELECT @IdVenta AS IdVentaGenerada, @Total AS TotalVenta, 'Venta registrada exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO