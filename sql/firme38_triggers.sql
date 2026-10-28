

USE SIAM;
GO

ALTER TABLE MovimientoStock DROP CONSTRAINT IF EXISTS CK_Mov_Cantidad;
ALTER TABLE MovimientoStock ADD CONSTRAINT CK_Mov_Cantidad CHECK (
       (TipoMovimiento =  'AJUSTE' AND Cantidad <> 0)
    OR (TipoMovimiento <> 'AJUSTE' AND Cantidad >  0)
);
GO

-- Tablas auxiliares que alimentan los triggers 6 y 7
DROP TABLE IF EXISTS HistorialPrecio;
DROP TABLE IF EXISTS AlertaStock;
GO

CREATE TABLE HistorialPrecio (
    IdHistorial     INT           IDENTITY(1,1) NOT NULL,
    IdVariante      INT           NOT NULL,
    PrecioAnterior  DECIMAL(12,2) NOT NULL,
    PrecioNuevo     DECIMAL(12,2) NOT NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    UsuarioBD       VARCHAR(128)  NOT NULL DEFAULT SUSER_SNAME(),
    CONSTRAINT PK_HistorialPrecio PRIMARY KEY (IdHistorial),
    CONSTRAINT FK_Historial_Variante FOREIGN KEY (IdVariante)
        REFERENCES VarianteProducto (IdVariante)
);

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



-- 1. MovimientoStock: aplica el stock


CREATE OR ALTER TRIGGER TR_MovimientoStock_AplicarStock
ON MovimientoStock
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Delta TABLE (IdVariante INT PRIMARY KEY, Cant INT NOT NULL);

    INSERT INTO @Delta (IdVariante, Cant)
    SELECT IdVariante,
           SUM(CASE WHEN TipoMovimiento = 'SALIDA' THEN -Cantidad ELSE Cantidad END)
    FROM inserted
    GROUP BY IdVariante;

    IF EXISTS (SELECT 1
               FROM @Delta d
               JOIN VarianteProducto v ON v.IdVariante = d.IdVariante
               WHERE v.StockActual + d.Cant < 0)
        THROW 50002, 'Stock insuficiente para registrar el movimiento.', 1;

    UPDATE v
    SET    v.StockActual = v.StockActual + d.Cant
    FROM   VarianteProducto v
    JOIN   @Delta d ON d.IdVariante = v.IdVariante;
END;
GO

-- 1b. Los movimientos son un registro historico: no se editan ni borran.
--     Tambien frena los ON DELETE SET NULL de FK_Mov_Compra / FK_Mov_Venta.
CREATE OR ALTER TRIGGER TR_MovimientoStock_Inmutable
ON MovimientoStock
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50003, 'Los movimientos de stock no se modifican: registre un AJUSTE.', 1;
END;
GO



-- 2. Venta y Compra: solo usuarios activos pueden registrarlas

CREATE OR ALTER TRIGGER TR_Venta_UsuarioActivo
ON Venta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Usuario u ON u.IdUsuario = i.IdUsuario
               WHERE u.Activo = 0)
        THROW 50004, 'Un usuario inactivo no puede registrar ventas.', 1;
END;
GO

CREATE OR ALTER TRIGGER TR_Compra_UsuarioActivo
ON Compra
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Usuario u ON u.IdUsuario = i.IdUsuario
               WHERE u.Activo = 0)
        THROW 50005, 'Un usuario inactivo no puede registrar compras.', 1;
END;
GO



-- 3. DetalleVenta (INSERT): valida, genera SALIDA y recalcula Total

CREATE OR ALTER TRIGGER TR_DetalleVenta_Insert
ON DetalleVenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Venta v ON v.IdVenta = i.IdVenta
               WHERE v.Estado <> 'CONFIRMADA')
        THROW 50010, 'Solo se agregan lineas a una venta CONFIRMADA.', 1;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN VarianteProducto vp ON vp.IdVariante = i.IdVariante
               JOIN Producto p          ON p.IdProducto  = vp.IdProducto
               WHERE p.Activo = 0)
        THROW 50011, 'No se puede vender una variante de un producto inactivo.', 1;


    DECLARE @base INT = (SELECT ISNULL(MAX(IdMovimiento), 0)
                         FROM MovimientoStock WITH (UPDLOCK, HOLDLOCK));

    INSERT INTO MovimientoStock
           (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, IdVenta, Observacion)
    SELECT @base + ROW_NUMBER() OVER (ORDER BY i.IdVenta, i.NroLinea),
           i.IdVariante, v.IdUsuario, GETDATE(), 'SALIDA', i.Cantidad, i.IdVenta,
           CONCAT('Venta ', i.IdVenta, ' linea ', i.NroLinea)
    FROM inserted i
    JOIN Venta v ON v.IdVenta = i.IdVenta;
    -- si falta stock, TR_MovimientoStock_AplicarStock lanza 50002 y se revierte todo

    UPDATE v
    SET    v.Total = t.Total
    FROM   Venta v
    JOIN  (SELECT dv.IdVenta,
                  SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento) AS Total
           FROM DetalleVenta dv
           WHERE dv.IdVenta IN (SELECT IdVenta FROM inserted)
           GROUP BY dv.IdVenta) t ON t.IdVenta = v.IdVenta;
END;
GO

-- 3b. Una venta confirmada no se edita linea por linea: se anula
CREATE OR ALTER TRIGGER TR_DetalleVenta_Inmutable
ON DetalleVenta
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50012, 'Las lineas de venta no se modifican ni borran: anule la venta.', 1;
END;
GO


-- 4. Venta (UPDATE Estado): CONFIRMADA -> ANULADA devuelve el stock

CREATE OR ALTER TRIGGER TR_Venta_CambioEstado
ON Venta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Estado) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdVenta = i.IdVenta
               WHERE d.Estado = 'ANULADA' AND i.Estado <> 'ANULADA')
        THROW 50020, 'Una venta anulada no puede volver a confirmarse.', 1;

    DECLARE @base INT = (SELECT ISNULL(MAX(IdMovimiento), 0)
                         FROM MovimientoStock WITH (UPDLOCK, HOLDLOCK));

    INSERT INTO MovimientoStock
           (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, IdVenta, Observacion)
    SELECT @base + ROW_NUMBER() OVER (ORDER BY dv.IdVenta, dv.NroLinea),
           dv.IdVariante, i.IdUsuario, GETDATE(), 'DEVOLUCION', dv.Cantidad, dv.IdVenta,
           CONCAT('Anulacion venta ', dv.IdVenta)
    FROM inserted i
    JOIN deleted d       ON d.IdVenta  = i.IdVenta
    JOIN DetalleVenta dv ON dv.IdVenta = i.IdVenta
    WHERE d.Estado = 'CONFIRMADA' AND i.Estado = 'ANULADA';
END;
GO


-- 5. Compra (UPDATE Estado): PENDIENTE -> RECIBIDA ingresa el stock
--    Transiciones validas: PENDIENTE -> RECIBIDA, PENDIENTE -> ANULADA

CREATE OR ALTER TRIGGER TR_Compra_CambioEstado
ON Compra
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Estado) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdCompra = i.IdCompra
               WHERE d.Estado <> i.Estado AND d.Estado <> 'PENDIENTE')
        THROW 50030, 'Solo una compra PENDIENTE puede cambiar de estado.', 1;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdCompra = i.IdCompra
               WHERE d.Estado = 'PENDIENTE' AND i.Estado = 'RECIBIDA'
                 AND NOT EXISTS (SELECT 1 FROM DetalleCompra dc WHERE dc.IdCompra = i.IdCompra))
        THROW 50031, 'No se puede recibir una compra sin lineas.', 1;

    DECLARE @base INT = (SELECT ISNULL(MAX(IdMovimiento), 0)
                         FROM MovimientoStock WITH (UPDLOCK, HOLDLOCK));

    INSERT INTO MovimientoStock
           (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, IdCompra, Observacion)
    SELECT @base + ROW_NUMBER() OVER (ORDER BY dc.IdCompra, dc.NroLinea),
           dc.IdVariante, i.IdUsuario, GETDATE(), 'ENTRADA', dc.Cantidad, dc.IdCompra,
           CONCAT('Recepcion compra ', dc.IdCompra)
    FROM inserted i
    JOIN deleted d        ON d.IdCompra  = i.IdCompra
    JOIN DetalleCompra dc ON dc.IdCompra = i.IdCompra
    WHERE d.Estado = 'PENDIENTE' AND i.Estado = 'RECIBIDA';
END;
GO


-- 6. DetalleCompra: solo editable con la compra PENDIENTE, recalcula Total

CREATE OR ALTER TRIGGER TR_DetalleCompra_Control
ON DetalleCompra
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Compras TABLE (IdCompra INT PRIMARY KEY);
    INSERT INTO @Compras (IdCompra)
    SELECT IdCompra FROM inserted
    UNION
    SELECT IdCompra FROM deleted;

    IF EXISTS (SELECT 1
               FROM @Compras x
               JOIN Compra c ON c.IdCompra = x.IdCompra
               WHERE c.Estado <> 'PENDIENTE')
        THROW 50040, 'Solo se modifican lineas de una compra PENDIENTE.', 1;

    UPDATE c
    SET    c.Total = ISNULL(t.Total, 0)
    FROM   Compra c
    JOIN   @Compras x ON x.IdCompra = c.IdCompra
    OUTER APPLY (SELECT SUM(dc.Cantidad * dc.CostoUnitario) AS Total
                 FROM DetalleCompra dc
                 WHERE dc.IdCompra = c.IdCompra) t;
END;
GO



-- 7. VarianteProducto: historial de precios

CREATE OR ALTER TRIGGER TR_Variante_HistorialPrecio
ON VarianteProducto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(PrecioVenta) RETURN;

    INSERT INTO HistorialPrecio (IdVariante, PrecioAnterior, PrecioNuevo)
    SELECT i.IdVariante, d.PrecioVenta, i.PrecioVenta
    FROM inserted i
    JOIN deleted d ON d.IdVariante = i.IdVariante
    WHERE i.PrecioVenta <> d.PrecioVenta;
END;
GO



-- 8. VarianteProducto: alerta cuando el stock cruza el minimo
--    (solo al cruzar, no en cada venta posterior)

CREATE OR ALTER TRIGGER TR_Variante_AlertaStock
ON VarianteProducto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(StockActual) RETURN;

    INSERT INTO AlertaStock (IdVariante, StockActual, StockMinimo)
    SELECT i.IdVariante, i.StockActual, i.StockMinimo
    FROM inserted i
    JOIN deleted d ON d.IdVariante = i.IdVariante
    WHERE i.StockActual <= i.StockMinimo
      AND d.StockActual >  d.StockMinimo;
END;
GO


-- 9. Baja logica: ventas y compras no se borran, se anulan.
--    INSTEAD OF corta el DELETE antes de que corran los ON DELETE CASCADE
--    hacia DetalleVenta / DetalleCompra y los SET NULL de MovimientoStock.

CREATE OR ALTER TRIGGER TR_Venta_NoBorrar
ON Venta
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50050, 'Las ventas no se borran: cambie Estado a ANULADA.', 1;
END;
GO

CREATE OR ALTER TRIGGER TR_Compra_NoBorrar
ON Compra
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50051, 'Las compras no se borran: cambie Estado a ANULADA.', 1;
END;
GO
