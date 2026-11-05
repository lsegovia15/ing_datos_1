

USE SIAM;
GO

-- 1. Al vender: descontar el stock
--    Si no alcanza el stock, se cancela la venta.
--    Se agrupa por variante: si en un mismo INSERT la misma variante
--    aparece en varias filas (por ejemplo, en dos ventas distintas),
--    se descuenta la suma de todas y no solo una de ellas.

CREATE TRIGGER TR_DescontarStockVenta
ON DetalleVenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- VALIDAR STOCK (contra el total pedido por variante)
    IF EXISTS (SELECT 1
               FROM (SELECT IdVariante, SUM(Cantidad) AS Cantidad
                     FROM inserted
                     GROUP BY IdVariante) i
               JOIN VarianteProducto v ON v.IdVariante = i.IdVariante
               WHERE v.StockActual < i.Cantidad)
    BEGIN
        THROW 50200, 'No hay stock suficiente para realizar la venta.', 1;
    END

    -- DESCONTAR STOCK
    UPDATE v
    SET v.StockActual = v.StockActual - i.Cantidad
    FROM VarianteProducto v
    JOIN (SELECT IdVariante, SUM(Cantidad) AS Cantidad
          FROM inserted
          GROUP BY IdVariante) i ON i.IdVariante = v.IdVariante;

    PRINT 'Stock descontado por la venta.';

END;
GO



-- 2. Al vender: recalcular el total de la venta

CREATE TRIGGER TR_CalcularTotalVenta
ON DetalleVenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Venta
    SET Total = (SELECT SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento)
                 FROM DetalleVenta dv
                 WHERE dv.IdVenta = Venta.IdVenta)
    WHERE IdVenta IN (SELECT IdVenta FROM inserted);

END;
GO


-- 3. Al anular una venta: devolver el stock
--    Unico cambio de estado permitido: CONFIRMADA -> ANULADA.
--    (Si una venta ANULADA volviera a CONFIRMADA, el stock no se
--    descontaria de nuevo y quedaria inconsistente.)

CREATE TRIGGER TR_DevolverStockAnulacion
ON Venta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- VALIDAR TRANSICION DE ESTADO
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdVenta = i.IdVenta
               WHERE i.Estado <> d.Estado
                 AND NOT (d.Estado = 'CONFIRMADA' AND i.Estado = 'ANULADA'))
    BEGIN
        THROW 50201, 'Cambio de estado de venta no permitido. Solo se puede pasar de CONFIRMADA a ANULADA.', 1;
    END

    -- Solo las ventas que pasaron de CONFIRMADA a ANULADA.
    -- Se agrupa por variante porque un mismo UPDATE puede anular
    -- varias ventas que contienen la misma variante.
    UPDATE v
    SET v.StockActual = v.StockActual + x.Cantidad
    FROM VarianteProducto v
    JOIN (SELECT dv.IdVariante, SUM(dv.Cantidad) AS Cantidad
          FROM DetalleVenta dv
          JOIN inserted i ON i.IdVenta = dv.IdVenta
          JOIN deleted d  ON d.IdVenta = i.IdVenta
          WHERE d.Estado = 'CONFIRMADA'
            AND i.Estado = 'ANULADA'
          GROUP BY dv.IdVariante) x ON x.IdVariante = v.IdVariante;

END;
GO



-- 4. Al recibir una compra: sumar el stock
--    Cambios de estado permitidos: PENDIENTE -> RECIBIDA y
--    PENDIENTE -> ANULADA. (Si una compra RECIBIDA volviera a
--    PENDIENTE y se recibiera otra vez, el stock se sumaria dos veces.)

CREATE TRIGGER TR_SumarStockCompra
ON Compra
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- VALIDAR TRANSICION DE ESTADO
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdCompra = i.IdCompra
               WHERE i.Estado <> d.Estado
                 AND NOT (d.Estado = 'PENDIENTE' AND i.Estado IN ('RECIBIDA', 'ANULADA')))
    BEGIN
        THROW 50202, 'Cambio de estado de compra no permitido. Solo se puede pasar de PENDIENTE a RECIBIDA o ANULADA.', 1;
    END

    -- Solo las compras que pasaron de PENDIENTE a RECIBIDA.
    -- Se agrupa por variante porque un mismo UPDATE puede recibir
    -- varias compras que contienen la misma variante.
    UPDATE v
    SET v.StockActual = v.StockActual + x.Cantidad
    FROM VarianteProducto v
    JOIN (SELECT dc.IdVariante, SUM(dc.Cantidad) AS Cantidad
          FROM DetalleCompra dc
          JOIN inserted i ON i.IdCompra = dc.IdCompra
          JOIN deleted d  ON d.IdCompra = i.IdCompra
          WHERE d.Estado = 'PENDIENTE'
            AND i.Estado = 'RECIBIDA'
          GROUP BY dc.IdVariante) x ON x.IdVariante = v.IdVariante;

END;
GO



-- 5. Alerta de stock bajo el minimo

CREATE TABLE AlertaStock (
    IdAlerta        INT      IDENTITY(1,1) NOT NULL,
    IdVariante      INT      NOT NULL,
    StockActual     INT      NOT NULL,
    StockMinimo     INT      NOT NULL,
    Fecha           DATETIME NOT NULL DEFAULT GETDATE(),
    Atendida        INT      NOT NULL DEFAULT 0,
    CONSTRAINT PK_AlertaStock PRIMARY KEY (IdAlerta),
    CONSTRAINT FK_Alerta_Variante FOREIGN KEY (IdVariante)
        REFERENCES VarianteProducto (IdVariante),
    CONSTRAINT CK_AlertaStock_Atendida CHECK (Atendida IN (0, 1))
);
GO

CREATE TRIGGER TR_AvisoStockMinimo
ON VarianteProducto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo las variantes que recien bajaron al minimo
    -- (antes estaban por encima y ahora quedaron igual o por debajo)
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdVariante = i.IdVariante
               WHERE i.StockActual <= i.StockMinimo
                 AND d.StockActual >  d.StockMinimo)
    BEGIN
        INSERT INTO AlertaStock (IdVariante, StockActual, StockMinimo)
        SELECT i.IdVariante, i.StockActual, i.StockMinimo
        FROM inserted i
        JOIN deleted d ON d.IdVariante = i.IdVariante
        WHERE i.StockActual <= i.StockMinimo
          AND d.StockActual >  d.StockMinimo;

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
    SET NOCOUNT ON;

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
    SET NOCOUNT ON;

    -- INSTEAD OF: el DELETE nunca se ejecuta. Se lanza un error
    -- (en lugar de un PRINT) para que quien intento borrar se entere
    -- de que la operacion no se realizo.
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        THROW 50203, 'Las ventas no se pueden borrar. Use SP_AnularVenta para anularla.', 1;
    END

END;
GO



-- 8. Ajustes de stock: aplicar el AJUSTE sobre el stock
--    SP_AjustarStock inserta el movimiento con la diferencia
--    (positiva o negativa) y este trigger la aplica.

CREATE TRIGGER TR_AplicarAjusteStock
ON MovimientoStock
AFTER INSERT
AS
BEGIN

    SET NOCOUNT ON;

    -- Agrupado por variante: un INSERT con varios ajustes de la
    -- misma variante aplica la suma de todos.
    UPDATE v
    SET v.StockActual = v.StockActual + i.Cantidad
    FROM VarianteProducto v
    JOIN (SELECT IdVariante, SUM(Cantidad) AS Cantidad
          FROM inserted
          WHERE TipoMovimiento = 'AJUSTE'
          GROUP BY IdVariante) i ON i.IdVariante = v.IdVariante;

END;
GO
