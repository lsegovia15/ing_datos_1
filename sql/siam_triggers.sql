

USE SIAM;
GO

-- 1. Al vender: descontar el stock
--    Si no alcanza el stock, se cancela la venta.

CREATE TRIGGER TR_DescontarStockVenta
ON DetalleVenta
AFTER INSERT
AS
BEGIN

    -- VALIDAR STOCK
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN VarianteProducto v ON v.IdVariante = i.IdVariante
               WHERE v.StockActual < i.Cantidad)
    BEGIN
        THROW 50001, 'No hay stock suficiente para realizar la venta.', 1;
    END

    -- DESCONTAR STOCK
    UPDATE v
    SET v.StockActual = v.StockActual - i.Cantidad
    FROM VarianteProducto v
    JOIN inserted i ON i.IdVariante = v.IdVariante;

    PRINT 'Stock descontado por la venta.';

END;
GO



-- 2. Al vender: recalcular el total de la venta

CREATE TRIGGER TR_CalcularTotalVenta
ON DetalleVenta
AFTER INSERT
AS
BEGIN

    UPDATE Venta
    SET Total = (SELECT SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento)
                 FROM DetalleVenta dv
                 WHERE dv.IdVenta = Venta.IdVenta)
    WHERE IdVenta IN (SELECT IdVenta FROM inserted);

END;
GO


-- 3. Al anular una venta: devolver el stock

CREATE TRIGGER TR_DevolverStockAnulacion
ON Venta
AFTER UPDATE
AS
BEGIN

    -- Solo las ventas que pasaron de CONFIRMADA a ANULADA
    UPDATE v
    SET v.StockActual = v.StockActual + dv.Cantidad
    FROM VarianteProducto v
    JOIN DetalleVenta dv ON dv.IdVariante = v.IdVariante
    JOIN inserted i      ON i.IdVenta     = dv.IdVenta
    JOIN deleted d       ON d.IdVenta     = i.IdVenta
    WHERE d.Estado = 'CONFIRMADA'
      AND i.Estado = 'ANULADA';

END;
GO



-- 4. Al recibir una compra: sumar el stock

CREATE TRIGGER TR_SumarStockCompra
ON Compra
AFTER UPDATE
AS
BEGIN

    -- Solo las compras que pasaron de PENDIENTE a RECIBIDA
    UPDATE v
    SET v.StockActual = v.StockActual + dc.Cantidad
    FROM VarianteProducto v
    JOIN DetalleCompra dc ON dc.IdVariante = v.IdVariante
    JOIN inserted i       ON i.IdCompra    = dc.IdCompra
    JOIN deleted d        ON d.IdCompra    = i.IdCompra
    WHERE d.Estado = 'PENDIENTE'
      AND i.Estado = 'RECIBIDA';

END;
GO



-- 5. Aviso de stock bajo el minimo

CREATE TRIGGER TR_AvisoStockMinimo
ON VarianteProducto
AFTER UPDATE
AS
BEGIN

    IF EXISTS (SELECT 1
               FROM inserted
               WHERE StockActual <= StockMinimo)
    BEGIN
        PRINT 'ATENCION: hay variantes con stock igual o menor al minimo.';
    END

END;
GO



-- 6. Auditoria: historial de cambios de precio

CREATE TABLE HistorialPrecio (
    IdHistorial     INT           IDENTITY(1,1) NOT NULL,
    IdVariante      INT           NOT NULL,
    PrecioAnterior  DECIMAL(12,2) NOT NULL,
    PrecioNuevo     DECIMAL(12,2) NOT NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_HistorialPrecio PRIMARY KEY (IdHistorial),
    CONSTRAINT FK_Historial_Variante FOREIGN KEY (IdVariante)
        REFERENCES VarianteProducto (IdVariante)
);
GO

CREATE TRIGGER TR_HistorialPrecio
ON VarianteProducto
AFTER UPDATE
AS
BEGIN

    -- deleted = precio viejo, inserted = precio nuevo
    INSERT INTO HistorialPrecio (IdVariante, PrecioAnterior, PrecioNuevo)
    SELECT i.IdVariante, d.PrecioVenta, i.PrecioVenta
    FROM inserted i
    JOIN deleted d ON d.IdVariante = i.IdVariante
    WHERE i.PrecioVenta <> d.PrecioVenta;

END;
GO



-- 7. Las ventas no se borran, se anulan

CREATE TRIGGER TR_NoBorrarVenta
ON Venta
INSTEAD OF DELETE
AS
BEGIN

    PRINT 'Las ventas no se pueden borrar. Cambie el Estado a ANULADA.';

END;
GO
