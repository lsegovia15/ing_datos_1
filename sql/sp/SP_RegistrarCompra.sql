USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_RegistrarCompra
    @IdProveedor    INT,
    @IdUsuario      INT,
    @IdVariante     INT,
    @Cantidad       INT,
    @CostoUnitario  DECIMAL(12,2),
    @NroComprobante VARCHAR(30) = NULL
AS
BEGIN
    DECLARE @IdCompra INT;
    DECLARE @Total DECIMAL(12,2);

    BEGIN TRY
        -- 1. VALIDACIONES
        IF (@Cantidad <= 0)
        BEGIN
            PRINT 'Error: La cantidad debe ser mayor a cero.';
            RETURN;
        END

        IF (@CostoUnitario < 0)
        BEGIN
            PRINT 'Error: El costo unitario no puede ser negativo.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE IdProveedor = @IdProveedor)
        BEGIN
            PRINT 'Error: El proveedor especificado no existe.';
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
              AND r.Nombre = 'Administrador'
        )
        BEGIN
            PRINT 'Error: Solo un usuario Administrador activo puede registrar compras.';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM VarianteProducto WHERE IdVariante = @IdVariante)
        BEGIN
            PRINT 'Error: La variante especificada no existe.';
            RETURN;
        END

        -- 2. TRANSACCIÓN ATÓMICA
        BEGIN TRANSACTION;

        -- Guardar datos de sesión para triggers
        EXEC sys.sp_set_session_context @key = N'IdUsuarioOperacion', @value = @IdUsuario;

        SET @Total = @Cantidad * @CostoUnitario;

        SELECT @IdCompra = ISNULL(MAX(IdCompra), 0) + 1 FROM Compra;

        -- Inserción de cabecera en estado PENDIENTE
        INSERT INTO Compra (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
        VALUES (@IdCompra, @IdProveedor, @IdUsuario, GETDATE(), @NroComprobante, @Total, 'PENDIENTE');

        -- Inserción de Detalle
        INSERT INTO DetalleCompra (IdCompra, NroLinea, IdVariante, Cantidad, CostoUnitario)
        VALUES (@IdCompra, 1, @IdVariante, @Cantidad, @CostoUnitario);

        COMMIT TRANSACTION;

        SELECT @IdCompra AS IdCompraGenerada, @Total AS TotalCompra,
               'Compra registrada exitosamente en estado PENDIENTE' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO