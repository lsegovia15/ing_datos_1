/* SIAM - Pruebas
   Ejecutar después de 00_master.sql (base recién creada con el seed).
   Cada prueba que modifica datos abre una transacción y termina con
   ROLLBACK, así que el script no deja cambios.
   Cada caso imprime OK o FALLA. Si hay alguna FALLA, al final se lanza
   un error (útil con sqlcmd -b).

   Estado esperado después del seed:
   - Stock: variante 1 = 22, variante 3 = 0, variante 4 = 9, variante 10 = 2.
   - Ventas: 6 (1, 2, 4 y 5 CONFIRMADAS; 3 y 6 ANULADAS).
   - Compras: 4 (1 RECIBIDA, 2 PENDIENTE, 3 y 4 ANULADAS).
   - 1 movimiento de stock (ajuste) y 1 alerta (variante 10).
*/

USE SIAM;
GO

SET NOCOUNT ON;

DECLARE @Fallas INT = 0;
DECLARE @Caso   VARCHAR(150);
DECLARE @Ok     INT;
DECLARE @e      INT;
DECLARE @n      INT;
DECLARE @s      INT;
DECLARE @t      DECIMAL(12,2);
DECLARE @t2     DECIMAL(12,2);
DECLARE @txt    VARCHAR(20);


PRINT '=== 1. ESTADO DESPUÉS DEL SEED ===';

SET @Caso = 'Stock de la variante 1 = 22';
SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 1;
IF @s = 22 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Stock de la variante 10 = 2 (llegó al mínimo)';
SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 10;
IF @s = 2 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = '4 ventas CONFIRMADAS y 2 ANULADAS';
SELECT @n = COUNT(*) FROM Venta WHERE Estado = 'CONFIRMADA';
SELECT @s = COUNT(*) FROM Venta WHERE Estado = 'ANULADA';
IF @n = 4 AND @s = 2 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = '1 alerta de stock (variante 10) y 1 movimiento de ajuste';
SELECT @n = COUNT(*) FROM AlertaStock WHERE IdVariante = 10;
SELECT @s = COUNT(*) FROM MovimientoStock WHERE TipoMovimiento = 'AJUSTE';
IF @n = 1 AND @s = 1 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 2. FUNCIONES ===';

SET @Caso = 'fn_EstadoStock: variante 3 = SIN STOCK';
IF dbo.fn_EstadoStock(3) = 'SIN STOCK' PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'fn_EstadoStock: variante 10 = BAJO STOCK';
IF dbo.fn_EstadoStock(10) = 'BAJO STOCK' PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'fn_EstadoStock: variante 1 = STOCK SUFICIENTE';
IF dbo.fn_EstadoStock(1) = 'STOCK SUFICIENTE' PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'fn_ResumenVentasPorUsuario: vendedor1 = 3 ventas por $162000 (sin anuladas)';
SELECT @n = CantidadVentas, @t = TotalVendido
FROM dbo.fn_ResumenVentasPorUsuario('2000-01-01', '2100-12-31')
WHERE NombreUsuario = 'vendedor1';
IF @n = 3 AND @t = 162000 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 3. VISTAS ===';

SET @Caso = 'vw_StockVariante muestra las 12 variantes';
SELECT @n = COUNT(*) FROM vw_StockVariante;
IF @n = 12 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'vw_VentasDetalladas muestra las 6 ventas';
SELECT @n = COUNT(*) FROM vw_VentasDetalladas;
IF @n = 6 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'vw_ProductosPremium devuelve productos';
SELECT @n = COUNT(*) FROM vw_ProductosPremium;
IF @n > 0 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'vw_CategoriasMasVendidasPorSegmento: Hombre = Remeras, Unisex = Camperas';
SELECT @n = COUNT(*) FROM vw_CategoriasMasVendidasPorSegmento
WHERE (Segmento = 'Hombre' AND Categoria = 'Remeras')
   OR (Segmento = 'Unisex' AND Categoria = 'Camperas');
IF @n = 2 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 4. SP_RegistrarVenta ===';

SET @Caso = 'Venta exitosa: descuenta stock y calcula el total';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RegistrarVenta @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO',
                               @IdVariante = 1, @Cantidad = 2;
    SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 1;
    SELECT @t = Total FROM Venta WHERE IdVenta = (SELECT MAX(IdVenta) FROM Venta);
    ROLLBACK TRANSACTION;
    IF @s = 20 AND @t = 36000 PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'Cantidad 0 -> 50001';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'EFECTIVO', @IdVariante = 1, @Cantidad = 0;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50001 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Usuario inactivo -> 50002';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 4, @MedioPago = 'EFECTIVO', @IdVariante = 1, @Cantidad = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50002 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Cliente inexistente -> 50003';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdCliente = 99, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @IdVariante = 1, @Cantidad = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50003 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Medio de pago inválido -> 50004';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'CHEQUE', @IdVariante = 1, @Cantidad = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50004 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Variante inexistente -> 50005';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'EFECTIVO', @IdVariante = 99, @Cantidad = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50005 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Stock insuficiente -> 50006';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'EFECTIVO', @IdVariante = 3, @Cantidad = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50006 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Descuento mayor al importe -> 50008';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'EFECTIVO', @IdVariante = 1, @Cantidad = 1,
                               @Descuento = 50000;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50008 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 5. SP_AnularVenta ===';

SET @Caso = 'Anulación exitosa: devuelve el stock';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 1;
    SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 1;
    SELECT @txt = Estado FROM Venta WHERE IdVenta = 1;
    ROLLBACK TRANSACTION;
    IF @s = 24 AND @txt = 'ANULADA' PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'Venta inexistente -> 50010';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 99, @IdUsuario = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50010 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Venta ya anulada -> 50011';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50011 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Vendedor no puede anular -> 50013';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50013 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 6. SP_AjustarStock ===';

SET @Caso = 'Ajuste exitoso: variante 2 de 3 a 10 y registra el movimiento';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AjustarStock @IdVariante = 2, @NuevaCantidad = 10, @IdUsuario = 1;
    SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 2;
    SELECT @n = COUNT(*) FROM MovimientoStock WHERE IdVariante = 2 AND Cantidad = 7;
    ROLLBACK TRANSACTION;
    IF @s = 10 AND @n = 1 PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'Cantidad negativa -> 50020';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_AjustarStock @IdVariante = 1, @NuevaCantidad = -1, @IdUsuario = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50020 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Vendedor no puede ajustar -> 50023';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_AjustarStock @IdVariante = 1, @NuevaCantidad = 10, @IdUsuario = 2;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50023 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 7. SP_RegistrarCompra y SP_RecibirCompra ===';

SET @Caso = 'Compra registrada y recibida: variante 5 de 2 a 5';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1,
                                @IdVariante = 5, @Cantidad = 3, @CostoUnitario = 15000;
    SELECT @n = MAX(IdCompra) FROM Compra;
    SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 5;  -- sigue en 2 (PENDIENTE)
    EXEC dbo.SP_RecibirCompra @IdCompra = @n, @IdUsuario = 1;
    SELECT @e = StockActual FROM VarianteProducto WHERE IdVariante = 5;  -- 5 después de recibir
    ROLLBACK TRANSACTION;
    IF @s = 2 AND @e = 5 PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'Proveedor inexistente -> 50101';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 99, @IdUsuario = 1, @IdVariante = 1, @Cantidad = 1, @CostoUnitario = 100;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50101 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Costo negativo -> 50105';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @IdVariante = 1, @Cantidad = 1, @CostoUnitario = -1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50105 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Recibir una compra ya RECIBIDA -> 50112';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RecibirCompra @IdCompra = 1, @IdUsuario = 1;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50112 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'Vendedor no puede recibir compras -> 50114';
SET @e = 0;
BEGIN TRY
    EXEC dbo.SP_RecibirCompra @IdCompra = 2, @IdUsuario = 2;
END TRY
BEGIN CATCH
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50114 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 8. TRIGGERS ===';

-- Varias filas con la misma variante en un solo INSERT y en un solo UPDATE:
-- el stock tiene que moverse por la suma de todas.
SET @Caso = 'Operaciones de varias filas: descuenta 5, calcula totales y devuelve 5';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
    VALUES (101, NULL, 1, GETDATE(), 'EFECTIVO', 0, 'CONFIRMADA'),
           (102, NULL, 1, GETDATE(), 'EFECTIVO', 0, 'CONFIRMADA');
    INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
    VALUES (101, 1, 1, 2, 18000, 0),
           (102, 1, 1, 3, 18000, 0);
    SELECT @s = StockActual FROM VarianteProducto WHERE IdVariante = 1;   -- 22 - 5 = 17
    SELECT @t = Total FROM Venta WHERE IdVenta = 101;                    -- 36000
    SELECT @t2 = Total FROM Venta WHERE IdVenta = 102;                   -- 54000
    UPDATE Venta SET Estado = 'ANULADA' WHERE IdVenta IN (101, 102);
    SELECT @n = StockActual FROM VarianteProducto WHERE IdVariante = 1;   -- vuelve a 22
    ROLLBACK TRANSACTION;
    IF @s = 17 AND @t = 36000 AND @t2 = 54000 AND @n = 22 PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'TR_AvisoStockMinimo: vender hasta el mínimo genera una alerta';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RegistrarVenta @IdUsuario = 2, @MedioPago = 'EFECTIVO', @IdVariante = 4, @Cantidad = 5;
    SELECT @n = COUNT(*) FROM AlertaStock WHERE IdVariante = 4 AND Atendida = 0;
    ROLLBACK TRANSACTION;
    IF @n = 1 PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'TR_HistorialPrecio: un cambio de precio queda registrado';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE VarianteProducto SET PrecioVenta = 19000 WHERE IdVariante = 1;
    SELECT @n = COUNT(*) FROM HistorialPrecio
    WHERE IdVariante = 1 AND PrecioAnterior = 18000 AND PrecioNuevo = 19000;
    ROLLBACK TRANSACTION;
    IF @n = 1 PRINT 'OK    - ' + @Caso;
    ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;

SET @Caso = 'TR_NoBorrarVenta: borrar una venta -> 50203';
SET @e = 0;
BEGIN TRY
    DELETE FROM Venta WHERE IdVenta = 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SET @e = ERROR_NUMBER();
END CATCH;
SELECT @n = COUNT(*) FROM Venta WHERE IdVenta = 1;
IF @e = 50203 AND @n = 1 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'TR_DevolverStockAnulacion: reactivar una venta anulada -> 50201';
SET @e = 0;
BEGIN TRY
    UPDATE Venta SET Estado = 'CONFIRMADA' WHERE IdVenta = 3;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50201 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'TR_SumarStockCompra: volver una compra RECIBIDA a PENDIENTE -> 50202';
SET @e = 0;
BEGIN TRY
    UPDATE Compra SET Estado = 'PENDIENTE' WHERE IdCompra = 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SET @e = ERROR_NUMBER();
END CATCH;
IF @e = 50202 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT '=== 9. CURSOR ===';

SET @Caso = 'SP_InformeReposicionStock se ejecuta sin error';
BEGIN TRY
    EXEC dbo.SP_InformeReposicionStock;
    PRINT 'OK    - ' + @Caso;
END TRY
BEGIN CATCH
    PRINT 'FALLA - ' + @Caso + ' -> ' + ERROR_MESSAGE();
    SET @Fallas = @Fallas + 1;
END CATCH;


PRINT '';
PRINT '=== 10. INTEGRIDAD ===';

SET @Caso = 'El total de cada venta coincide con su detalle';
SELECT @n = COUNT(*)
FROM Venta v
WHERE v.Total <> (SELECT ISNULL(SUM(d.Cantidad * d.PrecioUnitario - d.Descuento), 0)
                  FROM DetalleVenta d
                  WHERE d.IdVenta = v.IdVenta);
IF @n = 0 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'El total de cada compra coincide con su detalle';
SELECT @n = COUNT(*)
FROM Compra c
WHERE c.Total <> (SELECT ISNULL(SUM(d.Cantidad * d.CostoUnitario), 0)
                  FROM DetalleCompra d
                  WHERE d.IdCompra = c.IdCompra);
IF @n = 0 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END

SET @Caso = 'No hay stock negativo';
SELECT @n = COUNT(*) FROM VarianteProducto WHERE StockActual < 0;
IF @n = 0 PRINT 'OK    - ' + @Caso;
ELSE BEGIN PRINT 'FALLA - ' + @Caso; SET @Fallas = @Fallas + 1; END


PRINT '';
PRINT CONCAT('=== RESULTADO: ', @Fallas, ' prueba(s) con FALLA ===');

IF @Fallas > 0
BEGIN
    THROW 59000, 'Hay pruebas con FALLA. Revisar la salida.', 1;
END
GO
