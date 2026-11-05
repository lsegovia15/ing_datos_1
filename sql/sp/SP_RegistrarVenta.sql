USE SIAM;
GO

CREATE OR ALTER PROCEDURE SP_RegistrarVenta
    @IdCliente      INT = NULL,
    @IdUsuario      INT,
    @MedioPago      VARCHAR(20),
    @Detalle        TipoDetalleVenta READONLY -- Acá recibimos la tabla
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdVenta INT;
    DECLARE @Total DECIMAL(12,2) = 0;
    DECLARE @ErrorMsg NVARCHAR(4000);

    BEGIN TRY
        SET XACT_ABORT ON;

        -- 1. VALIDACIONES BÁSICAS
        IF NOT EXISTS (SELECT 1 FROM @Detalle)
        BEGIN
            THROW 50001, 'El detalle de la venta está vacío.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50002, 'El usuario que registra la venta no existe o está inactivo.', 1;
        END;

        -- Regla de negocio: tanto el Administrador como el Vendedor pueden
        -- registrar ventas, pero deben estar activos y tener uno de esos roles.
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            INNER JOIN Rol r ON r.IdRol = u.IdRol
            WHERE u.IdUsuario = @IdUsuario
              AND u.Activo = 1
              AND r.Nombre IN ('Administrador', 'Vendedor')
        )
        BEGIN
            THROW 50007, 'El usuario debe estar activo y tener rol Administrador o Vendedor para registrar ventas.', 1;
        END;

        IF (@IdCliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente WHERE IdCliente = @IdCliente))
        BEGIN
            THROW 50003, 'El cliente especificado no existe.', 1;
        END;

        -- 2. VALIDAR STOCK Y VARIANTES
        -- Validar que no haya variantes duplicadas en el carrito
        IF EXISTS (SELECT IdVariante FROM @Detalle GROUP BY IdVariante HAVING COUNT(*) > 1)
        BEGIN
            THROW 50004, 'No se puede repetir la misma variante en la misma venta.', 1;
        END;

        -- Validar que las variantes existan
        IF EXISTS (
            SELECT 1 FROM @Detalle d 
            WHERE NOT EXISTS (SELECT 1 FROM VarianteProducto v WHERE v.IdVariante = d.IdVariante)
        )
        BEGIN
            THROW 50005, 'Una o más variantes especificadas no existen.', 1;
        END;

        -- Validar stock suficiente (atrapamos el primer error para mostrarlo)
        SELECT TOP 1 @ErrorMsg = 
            'Stock insuficiente para la variante: ' + v.SKU + 
            '. Solicitado: ' + CAST(d.Cantidad AS VARCHAR) + 
            '. Disponible: ' + CAST(v.StockActual AS VARCHAR)
        FROM @Detalle d
        INNER JOIN VarianteProducto v ON v.IdVariante = d.IdVariante
        WHERE v.StockActual < d.Cantidad;

        IF @ErrorMsg IS NOT NULL
        BEGIN
            THROW 50006, @ErrorMsg, 1;
        END;

        -- 3. TRANSACCIÓN
        BEGIN TRANSACTION;

        -- Calcular el total
        SELECT @Total = SUM(Cantidad * PrecioUnitario - Descuento) FROM @Detalle;

        -- Generar el ID (bloqueado hasta el COMMIT para que dos ventas
        -- simultáneas no obtengan el mismo IdVenta)
        SELECT @IdVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM Venta WITH (UPDLOCK, HOLDLOCK);

        -- Insertar Cabecera
        INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
        VALUES (@IdVenta, @IdCliente, @IdUsuario, GETDATE(), @MedioPago, @Total, 'CONFIRMADA');

        -- Insertar Detalle.
        -- Marca de sesion para este SP; se limpia siempre al salir.
        -- Los triggers TR_DescontarStockVenta y TR_CalcularTotalVenta
        -- descuentan el stock y recalculan el total.
        EXEC sp_set_session_context @key = N'PermitirDetalleVenta', @value = 1;

        INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
        SELECT 
            @IdVenta,
            ROW_NUMBER() OVER (ORDER BY IdVariante),
            IdVariante, Cantidad, PrecioUnitario, Descuento
        FROM @Detalle;

        EXEC sp_set_session_context @key = N'PermitirDetalleVenta', @value = NULL;

        COMMIT TRANSACTION;

        -- Devolver resultado
        SELECT @IdVenta AS IdVentaGenerada, @Total AS TotalVenta, 'Venta registrada exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- El session context no se revierte con ROLLBACK.
        EXEC sp_set_session_context @key = N'PermitirDetalleVenta', @value = NULL;

        THROW;
    END CATCH
END;
GO