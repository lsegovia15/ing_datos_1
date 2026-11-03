USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_RegistrarCompra
    @IdProveedor    INT,
    @IdUsuario      INT,
    @NroComprobante VARCHAR(30) = NULL,
    @Detalle        TipoDetalleCompra READONLY
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdCompra INT;
    DECLARE @Total DECIMAL(12,2) = 0;

    BEGIN TRY
        SET XACT_ABORT ON;

        -- 1. VALIDACIONES BÁSICAS
        IF NOT EXISTS (SELECT 1 FROM @Detalle)
        BEGIN
            THROW 50100, 'El detalle de la compra está vacío.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM Proveedor WHERE IdProveedor = @IdProveedor)
        BEGIN
            THROW 50101, 'El proveedor especificado no existe.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50102, 'El usuario que registra la compra no existe o está inactivo.', 1;
        END;

        -- Defensa en profundidad: la regla de negocio se valida también en el
        -- SP, sin depender únicamente de los permisos EXECUTE del motor.
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            INNER JOIN Rol r ON r.IdRol = u.IdRol
            WHERE u.IdUsuario = @IdUsuario
              AND u.Activo = 1
              AND r.Nombre = 'Administrador'
        )
        BEGIN
            THROW 50107, 'Solo un usuario Administrador activo puede registrar compras.', 1;
        END;

        IF EXISTS (SELECT IdVariante FROM @Detalle GROUP BY IdVariante HAVING COUNT(*) > 1)
        BEGIN
            THROW 50103, 'No se puede repetir la misma variante en la misma compra.', 1;
        END;

        IF EXISTS (SELECT 1 FROM @Detalle WHERE Cantidad <= 0)
        BEGIN
            THROW 50104, 'Todas las cantidades deben ser mayores a cero.', 1;
        END;

        IF EXISTS (SELECT 1 FROM @Detalle WHERE CostoUnitario < 0)
        BEGIN
            THROW 50105, 'El costo unitario no puede ser negativo.', 1;
        END;

        IF EXISTS (
            SELECT 1
            FROM @Detalle d
            WHERE NOT EXISTS (SELECT 1 FROM VarianteProducto v WHERE v.IdVariante = d.IdVariante)
        )
        BEGIN
            THROW 50106, 'Una o más variantes especificadas no existen.', 1;
        END;

        -- 2. TOTAL Y TRANSACCIÓN
        SELECT @Total = SUM(Cantidad * CostoUnitario) FROM @Detalle;

        BEGIN TRANSACTION;

        -- Bloqueo de rango para que dos compras simultáneas no generen el mismo ID.
        SELECT @IdCompra = ISNULL(MAX(IdCompra), 0) + 1
        FROM Compra WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO Compra (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
        VALUES (@IdCompra, @IdProveedor, @IdUsuario, GETDATE(), @NroComprobante, @Total, 'PENDIENTE');

        INSERT INTO DetalleCompra (IdCompra, NroLinea, IdVariante, Cantidad, CostoUnitario)
        SELECT @IdCompra,
               ROW_NUMBER() OVER (ORDER BY IdVariante),
               IdVariante, Cantidad, CostoUnitario
        FROM @Detalle;

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
