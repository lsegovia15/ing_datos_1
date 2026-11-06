USE SIAM;
GO

-- registra una compra a un proveedor (solo administrador)
-- queda PENDIENTE, el stock se suma recien al recibirla

CREATE OR ALTER PROCEDURE dbo.SP_RegistrarCompra
    @IdProveedor    INT,
    @IdUsuario      INT,
    @IdVariante     INT,
    @Cantidad       INT,
    @CostoUnitario  DECIMAL(12,2),
    @NroComprobante VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdCompra INT;
    DECLARE @Total    DECIMAL(12,2);

    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE IdProveedor = @IdProveedor)
        BEGIN
            THROW 50101, 'El proveedor especificado no existe.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50102, 'El usuario que registra la compra no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50107, 'Solo un usuario Administrador puede registrar compras.', 1;
        END

        IF (@Cantidad IS NULL OR @Cantidad <= 0)
        BEGIN
            THROW 50104, 'La cantidad comprada debe ser mayor a cero.', 1;
        END

        IF (@CostoUnitario IS NULL OR @CostoUnitario < 0)
        BEGIN
            THROW 50105, 'El costo unitario no puede ser negativo.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM VarianteProducto WHERE IdVariante = @IdVariante)
        BEGIN
            THROW 50106, 'La variante especificada no existe.', 1;
        END

        SET @Total = @Cantidad * @CostoUnitario;

        BEGIN TRANSACTION;

        -- numero siguiente
        SELECT @IdCompra = ISNULL(MAX(IdCompra), 0) + 1 FROM Compra;

        INSERT INTO Compra (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
        VALUES (@IdCompra, @IdProveedor, @IdUsuario, GETDATE(), @NroComprobante, @Total, 'PENDIENTE');

        INSERT INTO DetalleCompra (IdCompra, NroLinea, IdVariante, Cantidad, CostoUnitario)
        VALUES (@IdCompra, 1, @IdVariante, @Cantidad, @CostoUnitario);

        COMMIT TRANSACTION;

        SELECT @IdCompra AS IdCompraGenerada,
               @Total    AS TotalCompra,
               'Compra registrada en estado PENDIENTE' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
