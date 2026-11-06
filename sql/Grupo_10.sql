-- SIAM - Grupo 10
-- script completo: base, tablas, triggers, funciones, vistas, SP, datos y seguridad
-- ojo que borra y vuelve a crear la base SIAM

-- ===== init_db.sql =====

USE master;
GO

-- borra la base si ya existe (cerrar otras conexiones a SIAM antes)
DROP DATABASE IF EXISTS SIAM;
GO

CREATE DATABASE SIAM;
GO

USE SIAM;
GO


-- tablas

CREATE TABLE Rol (
    IdRol           INT          NOT NULL,
    Nombre          VARCHAR(50)  NOT NULL,
    Descripcion     VARCHAR(200) NULL,
    CONSTRAINT PK_Rol PRIMARY KEY (IdRol),
    CONSTRAINT UQ_Rol_Nombre UNIQUE (Nombre)
);

CREATE TABLE Usuario (
    IdUsuario       INT          NOT NULL,
    IdRol           INT          NOT NULL,
    NombreUsuario   VARCHAR(50)  NOT NULL,
    Email           VARCHAR(100) NOT NULL,
    Contrasena      VARCHAR(255) NOT NULL,
    Nombre          VARCHAR(50)  NOT NULL,
    Apellido        VARCHAR(50)  NOT NULL,
    Activo          INT          NOT NULL DEFAULT 1,
    FechaAlta       DATETIME     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_Usuario PRIMARY KEY (IdUsuario),
    CONSTRAINT UQ_Usuario_NombreUsuario UNIQUE (NombreUsuario),
    CONSTRAINT UQ_Usuario_Email UNIQUE (Email),
    CONSTRAINT CK_Usuario_Activo CHECK (Activo IN (0, 1))
);

CREATE TABLE Categoria (
    IdCategoria     INT          NOT NULL,
    Nombre          VARCHAR(50)  NOT NULL,
    Descripcion     VARCHAR(200) NULL,
    CONSTRAINT PK_Categoria PRIMARY KEY (IdCategoria),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre)
);

-- segmento: hombre, mujer, niño, niña, unisex
CREATE TABLE Segmento (
    IdSegmento      INT         NOT NULL,
    Nombre          VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Segmento PRIMARY KEY (IdSegmento),
    CONSTRAINT UQ_Segmento_Nombre UNIQUE (Nombre)
);

CREATE TABLE Marca (
    IdMarca         INT         NOT NULL,
    Nombre          VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Marca PRIMARY KEY (IdMarca),
    CONSTRAINT UQ_Marca_Nombre UNIQUE (Nombre)
);

CREATE TABLE Talle (
    IdTalle         INT         NOT NULL,
    Descripcion     VARCHAR(10) NOT NULL,
    CONSTRAINT PK_Talle PRIMARY KEY (IdTalle),
    CONSTRAINT UQ_Talle_Descripcion UNIQUE (Descripcion)
);

CREATE TABLE Color (
    IdColor         INT         NOT NULL,
    Nombre          VARCHAR(30) NOT NULL,
    CONSTRAINT PK_Color PRIMARY KEY (IdColor),
    CONSTRAINT UQ_Color_Nombre UNIQUE (Nombre)
);

CREATE TABLE Producto (
    IdProducto      INT           NOT NULL,
    IdCategoria     INT           NOT NULL,
    IdMarca         INT           NOT NULL,
    Nombre          VARCHAR(100)  NOT NULL,
    Descripcion     VARCHAR(500)  NULL,
    PrecioBase      DECIMAL(12,2) NOT NULL,
    Activo          INT           NOT NULL DEFAULT 1,
    CONSTRAINT PK_Producto PRIMARY KEY (IdProducto),
    CONSTRAINT CK_Producto_Precio CHECK (PrecioBase >= 0),
    CONSTRAINT CK_Producto_Activo CHECK (Activo IN (0, 1))
);

CREATE TABLE VarianteProducto (
    IdVariante      INT           NOT NULL,
    IdProducto      INT           NOT NULL,
    IdSegmento      INT           NOT NULL,
    IdTalle         INT           NOT NULL,
    IdColor         INT           NOT NULL,
    SKU             VARCHAR(30)   NOT NULL,
    PrecioVenta     DECIMAL(12,2) NOT NULL,
    StockActual     INT           NOT NULL DEFAULT 0,
    StockMinimo     INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_VarianteProducto PRIMARY KEY (IdVariante),
    CONSTRAINT UQ_Variante_SKU UNIQUE (SKU),
    CONSTRAINT UQ_Variante_Combinacion UNIQUE (IdProducto, IdSegmento, IdTalle, IdColor),
    CONSTRAINT CK_Variante_Precio CHECK (PrecioVenta >= 0),
    CONSTRAINT CK_Variante_Stock CHECK (StockActual >= 0 AND StockMinimo >= 0)
);

CREATE TABLE Proveedor (
    IdProveedor     INT          NOT NULL,
    RazonSocial     VARCHAR(100) NOT NULL,
    CUIT            VARCHAR(13)  NOT NULL,
    Telefono        VARCHAR(20)  NULL,
    Email           VARCHAR(100) NULL,
    Direccion       VARCHAR(150) NULL,
    CONSTRAINT PK_Proveedor PRIMARY KEY (IdProveedor),
    CONSTRAINT UQ_Proveedor_CUIT UNIQUE (CUIT)
);

CREATE TABLE Compra (
    IdCompra        INT           NOT NULL,
    IdProveedor     INT           NOT NULL,
    IdUsuario       INT           NOT NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    NroComprobante  VARCHAR(30)   NULL,
    Total           DECIMAL(12,2) NOT NULL DEFAULT 0,
    Estado          VARCHAR(20)   NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT PK_Compra PRIMARY KEY (IdCompra),
    CONSTRAINT CK_Compra_Total CHECK (Total >= 0),
    CONSTRAINT CK_Compra_Estado CHECK (Estado IN ('PENDIENTE', 'RECIBIDA', 'ANULADA'))
);

CREATE TABLE DetalleCompra (
    IdCompra        INT           NOT NULL,
    NroLinea        INT           NOT NULL,
    IdVariante      INT           NOT NULL,
    Cantidad        INT           NOT NULL,
    CostoUnitario   DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_DetalleCompra PRIMARY KEY (IdCompra, NroLinea),
    CONSTRAINT UQ_DetalleCompra UNIQUE (IdCompra, IdVariante),
    CONSTRAINT CK_DetalleCompra_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetalleCompra_Costo CHECK (CostoUnitario >= 0)
);

CREATE TABLE Cliente (
    IdCliente       INT          NOT NULL,
    Nombre          VARCHAR(50)  NOT NULL,
    Apellido        VARCHAR(50)  NOT NULL,
    DNI             VARCHAR(10)  NOT NULL,
    Email           VARCHAR(100) NULL,
    Telefono        VARCHAR(20)  NULL,
    Direccion       VARCHAR(150) NULL,
    CONSTRAINT PK_Cliente PRIMARY KEY (IdCliente),
    CONSTRAINT UQ_Cliente_DNI UNIQUE (DNI)
);

CREATE TABLE Venta (
    IdVenta         INT           NOT NULL,
    IdCliente       INT           NULL,
    IdUsuario       INT           NOT NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    MedioPago       VARCHAR(20)   NOT NULL,
    Total           DECIMAL(12,2) NOT NULL DEFAULT 0,
    Estado          VARCHAR(20)   NOT NULL DEFAULT 'CONFIRMADA',
    CONSTRAINT PK_Venta PRIMARY KEY (IdVenta),
    CONSTRAINT CK_Venta_MedioPago CHECK (MedioPago IN ('EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA')),
    CONSTRAINT CK_Venta_Total CHECK (Total >= 0),
    CONSTRAINT CK_Venta_Estado CHECK (Estado IN ('CONFIRMADA', 'ANULADA'))
);

CREATE TABLE DetalleVenta (
    IdVenta         INT           NOT NULL,
    NroLinea        INT           NOT NULL,
    IdVariante      INT           NOT NULL,
    Cantidad        INT           NOT NULL,
    PrecioUnitario  DECIMAL(12,2) NOT NULL,
    Descuento       DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT PK_DetalleVenta PRIMARY KEY (IdVenta, NroLinea),
    CONSTRAINT UQ_DetalleVenta UNIQUE (IdVenta, IdVariante),
    CONSTRAINT CK_DetalleVenta_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetalleVenta_Precio CHECK (PrecioUnitario >= 0),
    CONSTRAINT CK_DetalleVenta_Descuento CHECK (Descuento >= 0 AND Descuento <= Cantidad * PrecioUnitario)
);

CREATE TABLE MovimientoStock (
    IdMovimiento    INT          NOT NULL,
    IdVariante      INT          NOT NULL,
    IdUsuario       INT          NOT NULL,
    Fecha           DATETIME     NOT NULL DEFAULT GETDATE(),
    TipoMovimiento  VARCHAR(20)  NOT NULL,
    Cantidad        INT          NOT NULL,
    IdCompra        INT          NULL,
    IdVenta         INT          NULL,
    Observacion     VARCHAR(200) NULL,
    CONSTRAINT PK_MovimientoStock PRIMARY KEY (IdMovimiento),
    CONSTRAINT CK_Mov_Tipo CHECK (TipoMovimiento IN ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION')),
    CONSTRAINT CK_Mov_Cantidad CHECK (
        (TipoMovimiento =  'AJUSTE' AND Cantidad <> 0)
     OR (TipoMovimiento <> 'AJUSTE' AND Cantidad >  0)
    ),
    CONSTRAINT CK_Mov_Origen CHECK (NOT (IdCompra IS NOT NULL AND IdVenta IS NOT NULL))
);
GO


-- foreign keys


ALTER TABLE Usuario ADD CONSTRAINT FK_Usuario_Rol
    FOREIGN KEY (IdRol) REFERENCES Rol (IdRol);

ALTER TABLE Producto ADD CONSTRAINT FK_Producto_Categoria
    FOREIGN KEY (IdCategoria) REFERENCES Categoria (IdCategoria);

ALTER TABLE Producto ADD CONSTRAINT FK_Producto_Marca
    FOREIGN KEY (IdMarca) REFERENCES Marca (IdMarca);

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Producto
    FOREIGN KEY (IdProducto) REFERENCES Producto (IdProducto);

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Segmento
    FOREIGN KEY (IdSegmento) REFERENCES Segmento (IdSegmento);

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Talle
    FOREIGN KEY (IdTalle) REFERENCES Talle (IdTalle);

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Color
    FOREIGN KEY (IdColor) REFERENCES Color (IdColor);

ALTER TABLE Compra ADD CONSTRAINT FK_Compra_Proveedor
    FOREIGN KEY (IdProveedor) REFERENCES Proveedor (IdProveedor);

ALTER TABLE Compra ADD CONSTRAINT FK_Compra_Usuario
    FOREIGN KEY (IdUsuario) REFERENCES Usuario (IdUsuario);

ALTER TABLE DetalleCompra ADD CONSTRAINT FK_DetalleCompra_Compra
    FOREIGN KEY (IdCompra) REFERENCES Compra (IdCompra);

ALTER TABLE DetalleCompra ADD CONSTRAINT FK_DetalleCompra_Variante
    FOREIGN KEY (IdVariante) REFERENCES VarianteProducto (IdVariante);

ALTER TABLE Venta ADD CONSTRAINT FK_Venta_Cliente
    FOREIGN KEY (IdCliente) REFERENCES Cliente (IdCliente);

ALTER TABLE Venta ADD CONSTRAINT FK_Venta_Usuario
    FOREIGN KEY (IdUsuario) REFERENCES Usuario (IdUsuario);

ALTER TABLE DetalleVenta ADD CONSTRAINT FK_DetalleVenta_Venta
    FOREIGN KEY (IdVenta) REFERENCES Venta (IdVenta);

ALTER TABLE DetalleVenta ADD CONSTRAINT FK_DetalleVenta_Variante
    FOREIGN KEY (IdVariante) REFERENCES VarianteProducto (IdVariante);

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Variante
    FOREIGN KEY (IdVariante) REFERENCES VarianteProducto (IdVariante);

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Usuario
    FOREIGN KEY (IdUsuario) REFERENCES Usuario (IdUsuario);

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Compra
    FOREIGN KEY (IdCompra) REFERENCES Compra (IdCompra);

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Venta
    FOREIGN KEY (IdVenta) REFERENCES Venta (IdVenta);
GO

-- indices

CREATE INDEX IX_Usuario_IdRol                 ON Usuario (IdRol);
CREATE INDEX IX_Producto_IdCategoria          ON Producto (IdCategoria);
CREATE INDEX IX_Producto_IdMarca              ON Producto (IdMarca);
CREATE INDEX IX_Variante_IdSegmento           ON VarianteProducto (IdSegmento);
CREATE INDEX IX_Variante_IdTalle              ON VarianteProducto (IdTalle);
CREATE INDEX IX_Variante_IdColor              ON VarianteProducto (IdColor);
CREATE INDEX IX_Compra_IdProveedor            ON Compra (IdProveedor);
CREATE INDEX IX_Compra_IdUsuario              ON Compra (IdUsuario);
CREATE INDEX IX_DetalleCompra_IdVariante      ON DetalleCompra (IdVariante);
CREATE INDEX IX_Venta_IdCliente               ON Venta (IdCliente);
CREATE INDEX IX_Venta_IdUsuario               ON Venta (IdUsuario);
CREATE INDEX IX_DetalleVenta_IdVariante       ON DetalleVenta (IdVariante);
CREATE INDEX IX_Mov_IdVariante                ON MovimientoStock (IdVariante);
CREATE INDEX IX_Mov_IdUsuario                 ON MovimientoStock (IdUsuario);
CREATE INDEX IX_Mov_IdCompra                  ON MovimientoStock (IdCompra);
CREATE INDEX IX_Mov_IdVenta                   ON MovimientoStock (IdVenta);

CREATE INDEX IX_Producto_Nombre               ON Producto (Nombre);
CREATE INDEX IX_Cliente_Apellido_Nombre       ON Cliente (Apellido, Nombre);
CREATE INDEX IX_Compra_Fecha                  ON Compra (Fecha);
CREATE INDEX IX_Venta_Fecha                   ON Venta (Fecha);
CREATE INDEX IX_Mov_Fecha                     ON MovimientoStock (Fecha);
GO

-- ===== siam_triggers.sql =====

USE SIAM;
GO

-- 1. al vender descuenta el stock (si no alcanza tira error)
-- agrupo por variante por si viene repetida en el mismo insert

CREATE TRIGGER TR_DescontarStockVenta
ON DetalleVenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- valida stock
    IF EXISTS (SELECT 1
               FROM (SELECT IdVariante, SUM(Cantidad) AS Cantidad
                     FROM inserted
                     GROUP BY IdVariante) i
               JOIN VarianteProducto v ON v.IdVariante = i.IdVariante
               WHERE v.StockActual < i.Cantidad)
    BEGIN
        THROW 50200, 'No hay stock suficiente para realizar la venta.', 1;
    END

    UPDATE v
    SET v.StockActual = v.StockActual - i.Cantidad
    FROM VarianteProducto v
    JOIN (SELECT IdVariante, SUM(Cantidad) AS Cantidad
          FROM inserted
          GROUP BY IdVariante) i ON i.IdVariante = v.IdVariante;

    PRINT 'Stock descontado por la venta.';

END;
GO



-- 2. recalcula el total de la venta

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


-- 3. al anular una venta devuelve el stock
-- solo deja pasar de CONFIRMADA a ANULADA, sino el stock quedaba mal

CREATE TRIGGER TR_DevolverStockAnulacion
ON Venta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdVenta = i.IdVenta
               WHERE i.Estado <> d.Estado
                 AND NOT (d.Estado = 'CONFIRMADA' AND i.Estado = 'ANULADA'))
    BEGIN
        THROW 50201, 'Cambio de estado de venta no permitido. Solo se puede pasar de CONFIRMADA a ANULADA.', 1;
    END

    -- solo las que pasaron de CONFIRMADA a ANULADA
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



-- 4. al recibir una compra suma el stock
-- solo permite PENDIENTE -> RECIBIDA o ANULADA, si no se podria sumar dos veces

CREATE TRIGGER TR_SumarStockCompra
ON Compra
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d ON d.IdCompra = i.IdCompra
               WHERE i.Estado <> d.Estado
                 AND NOT (d.Estado = 'PENDIENTE' AND i.Estado IN ('RECIBIDA', 'ANULADA')))
    BEGIN
        THROW 50202, 'Cambio de estado de compra no permitido. Solo se puede pasar de PENDIENTE a RECIBIDA o ANULADA.', 1;
    END

    -- solo las que pasaron de PENDIENTE a RECIBIDA
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



-- 5. alerta cuando el stock llega al minimo

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

    -- solo las que recien bajaron al minimo (antes estaban por encima)
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



-- 6. guarda el historial de cambios de precio

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

    -- deleted es el precio viejo e inserted el nuevo
    INSERT INTO HistorialPrecio (IdVariante, PrecioAnterior, PrecioNuevo)
    SELECT i.IdVariante, d.PrecioVenta, i.PrecioVenta
    FROM inserted i
    JOIN deleted d ON d.IdVariante = i.IdVariante
    WHERE i.PrecioVenta <> d.PrecioVenta;

END;
GO



-- 7. las ventas no se borran, se anulan

CREATE TRIGGER TR_NoBorrarVenta
ON Venta
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- el delete nunca se hace, tira error para que se entere
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        THROW 50203, 'Las ventas no se pueden borrar. Use SP_AnularVenta para anularla.', 1;
    END

END;
GO



-- 8. aplica los ajustes de stock
-- SP_AjustarStock inserta la diferencia y este trigger la suma al stock

CREATE TRIGGER TR_AplicarAjusteStock
ON MovimientoStock
AFTER INSERT
AS
BEGIN

    SET NOCOUNT ON;

    UPDATE v
    SET v.StockActual = v.StockActual + i.Cantidad
    FROM VarianteProducto v
    JOIN (SELECT IdVariante, SUM(Cantidad) AS Cantidad
          FROM inserted
          WHERE TipoMovimiento = 'AJUSTE'
          GROUP BY IdVariante) i ON i.IdVariante = v.IdVariante;

END;
GO

-- ===== funciones.sql =====

USE SIAM;
GO

-- devuelve el estado del stock de una variante
-- SELECT dbo.fn_EstadoStock(1);

CREATE OR ALTER FUNCTION dbo.fn_EstadoStock
(
    @IdVariante INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Estado VARCHAR(20);

    -- primero miro si el producto esta inactivo y despues el stock
    SELECT @Estado =
        CASE
            WHEN p.Activo = 0                     THEN 'INACTIVO'
            WHEN v.StockActual = 0                THEN 'SIN STOCK'
            WHEN v.StockActual <= v.StockMinimo   THEN 'BAJO STOCK'
            ELSE 'STOCK SUFICIENTE'
        END
    FROM dbo.VarianteProducto AS v
    INNER JOIN dbo.Producto AS p ON p.IdProducto = v.IdProducto
    WHERE v.IdVariante = @IdVariante;

    -- si la variante no existe devuelve NULL
    RETURN @Estado;
END;
GO


-- cantidad de ventas y total vendido por usuario en un periodo
-- SELECT * FROM dbo.fn_ResumenVentasPorUsuario('2026-01-01', '2026-12-31');
CREATE OR ALTER FUNCTION dbo.fn_ResumenVentasPorUsuario
(
    @FechaDesde DATE,
    @FechaHasta DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        u.IdUsuario,
        u.NombreUsuario,
        COUNT(*) AS CantidadVentas,
        CAST(SUM(v.Total) AS DECIMAL(18, 2)) AS TotalVendido
    FROM dbo.Venta AS v
    INNER JOIN dbo.Usuario AS u ON u.IdUsuario = v.IdUsuario
    -- solo confirmadas; el < dia siguiente es para que entre todo el ultimo dia
    WHERE v.Estado = 'CONFIRMADA'
      AND v.Fecha >= @FechaDesde
      AND v.Fecha < DATEADD(DAY, 1, @FechaHasta)
    GROUP BY u.IdUsuario, u.NombreUsuario
);
GO

-- ===== vistas.sql =====

USE SIAM;
GO

-- Vista 1: stock por variante

CREATE OR ALTER VIEW vw_StockVariante AS
SELECT 
    v.IdVariante,
    p.Nombre        AS Producto,
    m.Nombre        AS Marca,
    c.Nombre        AS Categoria,
    s.Nombre        AS Segmento,
    t.Descripcion   AS Talle,
    col.Nombre      AS Color,
    v.SKU,
    v.PrecioVenta,
    v.StockActual,
    v.StockMinimo,
    CASE 
        WHEN v.StockActual = 0              THEN 'SIN STOCK'
        WHEN v.StockActual <= v.StockMinimo THEN 'BAJO STOCK'
        ELSE 'STOCK SUFICIENTE'
    END AS EstadoStock 
FROM VarianteProducto v
INNER JOIN Producto  p   ON v.IdProducto  = p.IdProducto
INNER JOIN Marca     m   ON p.IdMarca     = m.IdMarca
INNER JOIN Categoria c   ON p.IdCategoria = c.IdCategoria
INNER JOIN Segmento  s   ON v.IdSegmento  = s.IdSegmento
INNER JOIN Talle     t   ON v.IdTalle     = t.IdTalle
INNER JOIN Color     col ON v.IdColor     = col.IdColor
WHERE p.Activo = 1;
GO



-- Vista 2: Ventas detalladas

CREATE OR ALTER VIEW vw_VentasDetalladas AS
SELECT
    v.IdVenta,
    v.Fecha,
    CASE 
        WHEN cl.IdCliente IS NULL THEN 'Consumidor Final'
        ELSE CONCAT(cl.Nombre, ' ', cl.Apellido)
    END                                              AS Cliente,
    ISNULL(u.NombreUsuario, 'Sin asignar')           AS Vendedor,
    v.MedioPago,
    v.Estado,
    v.Total
FROM Venta v
LEFT JOIN Cliente cl ON v.IdCliente = cl.IdCliente
LEFT JOIN Usuario u  ON v.IdUsuario = u.IdUsuario;
GO



-- Vista 3: Productos con precio superior al promedio (activos)

CREATE OR ALTER VIEW vw_ProductosPremium AS
SELECT 
    p.Nombre, 
    p.PrecioBase, 
    m.Nombre AS Marca
FROM Producto p
INNER JOIN Marca m ON p.IdMarca = m.IdMarca
WHERE p.Activo = 1 AND p.PrecioBase > (
    SELECT AVG(p2.PrecioBase)
    FROM Producto p2
    WHERE p2.Activo = 1
);
GO

-- Vista 4: Categorías más vendidas por segmento
-- Justifica la entidad Segmento a nivel VarianteProducto.

CREATE OR ALTER VIEW vw_CategoriasMasVendidasPorSegmento AS
SELECT
    s.IdSegmento,
    s.Nombre          AS Segmento,
    c.IdCategoria,
    c.Nombre          AS Categoria,
    SUM(dv.Cantidad)  AS UnidadesVendidas,
    SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento) AS TotalVendido,
    1                 AS Posicion
FROM DetalleVenta dv
INNER JOIN Venta v             ON v.IdVenta = dv.IdVenta
INNER JOIN VarianteProducto vp ON vp.IdVariante = dv.IdVariante
INNER JOIN Producto p          ON p.IdProducto = vp.IdProducto
INNER JOIN Categoria c         ON c.IdCategoria = p.IdCategoria
INNER JOIN Segmento s          ON s.IdSegmento = vp.IdSegmento
WHERE v.Estado = 'CONFIRMADA'
GROUP BY s.IdSegmento, s.Nombre, c.IdCategoria, c.Nombre
HAVING SUM(dv.Cantidad) = (
    -- maximo vendido de ese segmento
    SELECT MAX(Totales.UnidadesPorCat)
    FROM (
        SELECT 
            vp2.IdSegmento,
            p2.IdCategoria,
            SUM(dv2.Cantidad) AS UnidadesPorCat
        FROM DetalleVenta dv2
        INNER JOIN Venta v2             ON v2.IdVenta = dv2.IdVenta
        INNER JOIN VarianteProducto vp2 ON vp2.IdVariante = dv2.IdVariante
        INNER JOIN Producto p2          ON p2.IdProducto = vp2.IdProducto
        WHERE v2.Estado = 'CONFIRMADA'
        GROUP BY vp2.IdSegmento, p2.IdCategoria
    ) AS Totales
    WHERE Totales.IdSegmento = s.IdSegmento
);
GO

-- ===== sp/SP_RegistrarVenta.sql =====

USE SIAM;
GO

-- registra una venta de una variante
-- el precio sale de VarianteProducto para que no se pueda cargar otro
-- los triggers descuentan el stock y calculan el total

CREATE OR ALTER PROCEDURE dbo.SP_RegistrarVenta
    @IdCliente      INT = NULL,
    @IdUsuario      INT,
    @MedioPago      VARCHAR(20),
    @IdVariante     INT,
    @Cantidad       INT,
    @Descuento      DECIMAL(12,2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdVenta        INT;
    DECLARE @PrecioUnitario DECIMAL(12,2);
    DECLARE @StockActual    INT;

    BEGIN TRY

        IF (@Cantidad IS NULL OR @Cantidad <= 0)
        BEGIN
            THROW 50001, 'La cantidad a vender debe ser mayor a cero.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50002, 'El usuario que registra la venta no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre IN ('Administrador', 'Vendedor'))
        BEGIN
            THROW 50007, 'El usuario debe tener rol Administrador o Vendedor para registrar ventas.', 1;
        END

        IF (@IdCliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cliente WHERE IdCliente = @IdCliente))
        BEGIN
            THROW 50003, 'El cliente especificado no existe.', 1;
        END

        IF (@MedioPago IS NULL OR @MedioPago NOT IN ('EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA'))
        BEGIN
            THROW 50004, 'Medio de pago no válido. Use EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA.', 1;
        END

        SELECT @PrecioUnitario = PrecioVenta,
               @StockActual    = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF (@PrecioUnitario IS NULL)
        BEGIN
            THROW 50005, 'La variante especificada no existe.', 1;
        END

        IF (@StockActual < @Cantidad)
        BEGIN
            THROW 50006, 'Stock insuficiente para realizar la venta.', 1;
        END

        IF (@Descuento < 0 OR @Descuento > @Cantidad * @PrecioUnitario)
        BEGIN
            THROW 50008, 'El descuento no puede ser negativo ni mayor al importe de la venta.', 1;
        END

        BEGIN TRANSACTION;

        -- numero siguiente
        SELECT @IdVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM Venta;

        -- cabecera (el total lo calcula el trigger)
        INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
        VALUES (@IdVenta, @IdCliente, @IdUsuario, GETDATE(), @MedioPago, 0, 'CONFIRMADA');

        -- detalle
        INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
        VALUES (@IdVenta, 1, @IdVariante, @Cantidad, @PrecioUnitario, @Descuento);

        COMMIT TRANSACTION;

        SELECT IdVenta AS IdVentaGenerada,
               Total   AS TotalVenta,
               'Venta registrada exitosamente' AS Mensaje
        FROM Venta
        WHERE IdVenta = @IdVenta;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

-- ===== sp/SP_AnularVenta.sql =====

USE SIAM;
GO

-- anula una venta CONFIRMADA (solo administrador)
-- el trigger TR_DevolverStockAnulacion devuelve el stock

CREATE OR ALTER PROCEDURE dbo.SP_AnularVenta
    @IdVenta   INT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50012, 'El usuario que anula la venta no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50013, 'Solo un usuario Administrador puede anular ventas.', 1;
        END

        SELECT @EstadoActual = Estado
        FROM Venta
        WHERE IdVenta = @IdVenta;

        IF (@EstadoActual IS NULL)
        BEGIN
            THROW 50010, 'La venta especificada no existe.', 1;
        END

        IF (@EstadoActual <> 'CONFIRMADA')
        BEGIN
            THROW 50011, 'La venta ya se encuentra anulada.', 1;
        END

        BEGIN TRANSACTION;

        UPDATE Venta
        SET Estado = 'ANULADA'
        WHERE IdVenta = @IdVenta
          AND Estado = 'CONFIRMADA';

        COMMIT TRANSACTION;

        SELECT @IdVenta AS IdVentaAnulada,
               'Venta anulada y stock devuelto' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

-- ===== sp/SP_AjustarStock.sql =====

USE SIAM;
GO

-- ajusta el stock de una variante despues de contar fisicamente
-- guarda la diferencia como AJUSTE y el trigger la aplica
-- solo administrador

CREATE OR ALTER PROCEDURE dbo.SP_AjustarStock
    @IdVariante     INT,
    @NuevaCantidad  INT,
    @IdUsuario      INT,
    @Observacion    VARCHAR(200) = 'Ajuste manual de inventario'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StockActual  INT;
    DECLARE @Diferencia   INT;
    DECLARE @IdMovimiento INT;

    BEGIN TRY

        IF (@NuevaCantidad IS NULL OR @NuevaCantidad < 0)
        BEGIN
            THROW 50020, 'La nueva cantidad de stock no puede ser negativa.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50021, 'El usuario que realiza el ajuste no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50023, 'Solo un usuario Administrador puede ajustar stock.', 1;
        END

        SELECT @StockActual = StockActual
        FROM VarianteProducto
        WHERE IdVariante = @IdVariante;

        IF (@StockActual IS NULL)
        BEGIN
            THROW 50022, 'La variante especificada no existe.', 1;
        END

        SET @Diferencia = @NuevaCantidad - @StockActual;

        -- si no hay diferencia no hace nada
        IF (@Diferencia = 0)
        BEGIN
            SELECT @IdVariante  AS IdVariante,
                   @StockActual AS StockActual,
                   'No hubo diferencia. No se registró ajuste.' AS Mensaje;
            RETURN;
        END

        BEGIN TRANSACTION;

        SELECT @IdMovimiento = ISNULL(MAX(IdMovimiento), 0) + 1 FROM MovimientoStock;

        -- dispara TR_AplicarAjusteStock
        INSERT INTO MovimientoStock (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
        VALUES (@IdMovimiento, @IdVariante, @IdUsuario, GETDATE(), 'AJUSTE', @Diferencia, @Observacion);

        COMMIT TRANSACTION;

        SELECT @IdVariante    AS IdVariante,
               @StockActual   AS StockAnterior,
               @NuevaCantidad AS StockNuevo,
               @Diferencia    AS Diferencia,
               'Ajuste de stock registrado' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

-- ===== sp/SP_RegistrarCompra.sql =====

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

-- ===== sp/SP_RecibirCompra.sql =====

USE SIAM;
GO

-- pasa una compra de PENDIENTE a RECIBIDA (solo administrador)
-- el trigger TR_SumarStockCompra suma el stock

CREATE OR ALTER PROCEDURE dbo.SP_RecibirCompra
    @IdCompra  INT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoActual VARCHAR(20);

    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
        BEGIN
            THROW 50113, 'El usuario que recibe la compra no existe o está inactivo.', 1;
        END

        IF NOT EXISTS (SELECT 1
                       FROM Usuario u
                       INNER JOIN Rol r ON r.IdRol = u.IdRol
                       WHERE u.IdUsuario = @IdUsuario
                         AND r.Nombre = 'Administrador')
        BEGIN
            THROW 50114, 'Solo un usuario Administrador puede recibir compras.', 1;
        END

        SELECT @EstadoActual = Estado
        FROM Compra
        WHERE IdCompra = @IdCompra;

        IF (@EstadoActual IS NULL)
        BEGIN
            THROW 50110, 'La compra especificada no existe.', 1;
        END

        IF (@EstadoActual <> 'PENDIENTE')
        BEGIN
            THROW 50112, 'Solo una compra en estado PENDIENTE puede recibirse.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM DetalleCompra WHERE IdCompra = @IdCompra)
        BEGIN
            THROW 50111, 'No se puede recibir una compra sin líneas de detalle.', 1;
        END

        BEGIN TRANSACTION;

        UPDATE Compra
        SET Estado = 'RECIBIDA'
        WHERE IdCompra = @IdCompra
          AND Estado = 'PENDIENTE';

        COMMIT TRANSACTION;

        SELECT @IdCompra AS IdCompraRecibida,
               'Compra recibida y stock actualizado' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

-- ===== cursores.sql =====

USE SIAM;
GO

-- informe de reposicion: recorre con un cursor las variantes que quedaron
-- en el minimo o por debajo y calcula cuanto pedir de cada una
-- EXEC dbo.SP_InformeReposicionStock;

CREATE OR ALTER PROCEDURE dbo.SP_InformeReposicionStock
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SKU              VARCHAR(30);
    DECLARE @Producto         VARCHAR(100);
    DECLARE @StockActual      INT;
    DECLARE @StockMinimo      INT;
    DECLARE @Objetivo         INT;
    DECLARE @CantidadSugerida INT;
    DECLARE @Prioridad        VARCHAR(10);
    DECLARE @Cantidad         INT = 0;

    -- por si el cursor quedó abierto de antes
    IF CURSOR_STATUS('global', 'cursor_reposicion') >= 0
        CLOSE cursor_reposicion;
    IF CURSOR_STATUS('global', 'cursor_reposicion') >= -1
        DEALLOCATE cursor_reposicion;

    DECLARE cursor_reposicion CURSOR FOR
        SELECT v.SKU, p.Nombre, v.StockActual, v.StockMinimo
        FROM VarianteProducto v
        INNER JOIN Producto p ON p.IdProducto = v.IdProducto
        WHERE p.Activo = 1
          AND v.StockActual <= v.StockMinimo
        ORDER BY v.StockActual, v.IdVariante;

    OPEN cursor_reposicion;

    FETCH NEXT FROM cursor_reposicion
        INTO @SKU, @Producto, @StockActual, @StockMinimo;

    PRINT 'INFORME DE REPOSICIÓN DE STOCK';
    PRINT '------------------------------';

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- objetivo: el doble del minimo
        IF @StockMinimo = 0
            SET @Objetivo = 1;
        ELSE
            SET @Objetivo = @StockMinimo * 2;

        SET @CantidadSugerida = @Objetivo - @StockActual;

        IF @StockActual = 0
            SET @Prioridad = 'URGENTE';
        ELSE
            SET @Prioridad = 'NORMAL';

        PRINT CONCAT(@Prioridad, ' - ', @SKU, ' (', @Producto, ')');
        PRINT CONCAT('   Stock actual: ', @StockActual,
                     ' | Mínimo: ', @StockMinimo,
                     ' | Pedir: ', @CantidadSugerida, ' unidades');

        SET @Cantidad = @Cantidad + 1;

        FETCH NEXT FROM cursor_reposicion
            INTO @SKU, @Producto, @StockActual, @StockMinimo;
    END;

    PRINT '------------------------------';
    PRINT CONCAT('Variantes a reponer: ', @Cantidad);

    CLOSE cursor_reposicion;

    DEALLOCATE cursor_reposicion;
END;
GO

-- ===== seed_data.sql =====

USE SIAM;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM dbo.Rol)
BEGIN
    PRINT 'Seed ya aplicado: la tabla Rol contiene datos. No se vuelve a ejecutar.';
    RETURN;
END;


-- 1. roles y usuarios

INSERT INTO dbo.Rol (IdRol, Nombre, Descripcion) VALUES
    (1, 'Administrador', 'Acceso total: catálogo, compras, stock, ventas, anulaciones y seguridad.'),
    (2, 'Vendedor',      'Registra ventas y consulta catálogo, stock y reportes de reposición.');

INSERT INTO dbo.Usuario
    (IdUsuario, IdRol, NombreUsuario, Email, Contrasena, Nombre, Apellido, Activo)
VALUES
    -- las contraseñas se guardan hasheadas (SHA-256), no en texto plano
    (1, 1, 'admin',             'admin@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Admin123!'), 2),    'Ana',   'Administradora', 1),
    (2, 2, 'vendedor1',         'vendedor1@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Vendedor123!'), 2), 'Bruno', 'Vendedor',       1),
    (3, 2, 'vendedor2',         'vendedor2@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Vendedor123!'), 2), 'Carla', 'Vendedora',      1),
    (4, 2, 'vendedor_inactivo', 'inactivo@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Inactivo123!'), 2), 'Diego', 'Inactivo',       0);


-- 2. catalogos

INSERT INTO dbo.Categoria (IdCategoria, Nombre, Descripcion) VALUES
    (1, 'Remeras',   'Remeras manga corta y oversize'),
    (2, 'Buzos',     'Buzos y hoodies'),
    (3, 'Pantalones','Pantalones y cargos'),
    (4, 'Bermudas',  'Bermudas y shorts'),
    (5, 'Camperas',  'Camperas y abrigos');

INSERT INTO dbo.Marca (IdMarca, Nombre) VALUES
    (1, 'Nangallery'),
    (2, 'UrbanStyle'),
    (3, 'DenimCo'),
    (4, 'StreetWear');

INSERT INTO dbo.Segmento (IdSegmento, Nombre) VALUES
    (1, 'Hombre'),
    (2, 'Mujer'),
    (3, 'Niño'),
    (4, 'Niña'),
    (5, 'Unisex');

INSERT INTO dbo.Talle (IdTalle, Descripcion) VALUES
    (1, 'S'), (2, 'M'), (3, 'L'), (4, 'XL'),
    (5, '36'), (6, '38'), (7, '40'), (8, '42');

INSERT INTO dbo.Color (IdColor, Nombre) VALUES
    (1, 'Negro'), (2, 'Blanco'), (3, 'Gris'), (4, 'Azul'),
    (5, 'Celeste'), (6, 'Beige'), (7, 'Rojo');


-- 3. productos y variantes
-- Las variantes se cargan con un stock inicial (inventario de apertura).
-- Desde acá, el stock solo cambia por compras recibidas, ventas,
-- anulaciones y ajustes.

INSERT INTO dbo.Producto (IdProducto, IdCategoria, IdMarca, Nombre, Descripcion, PrecioBase, Activo) VALUES
    (1, 1, 1, 'Remera Oversize Graffiti', 'Remera de algodón con estampa',      15000.00, 1),
    (2, 2, 2, 'Buzo Hoodie Classic',      'Buzo con capucha y bolsillo canguro', 25000.00, 1),
    (3, 3, 3, 'Pantalón Cargo',           'Pantalón cargo con bolsillos laterales', 22000.00, 1),
    (4, 4, 4, 'Bermuda Baggy',            'Bermuda amplia de verano',            12000.00, 1),
    (5, 5, 1, 'Campera Puffer',           'Campera inflable impermeable',        40000.00, 1),
    (6, 1, 2, 'Remera Básica',            'Remera lisa para niño/a',              8000.00, 1),
    (7, 5, 1, 'Campera Vintage',          'Producto discontinuado',              60000.00, 0);

INSERT INTO dbo.VarianteProducto
    (IdVariante, IdProducto, IdSegmento, IdTalle, IdColor, SKU, PrecioVenta, StockActual, StockMinimo)
VALUES
    (1,  1, 1, 2, 1, 'REM-OVG-M-NEG',   18000.00, 20, 5),
    (2,  1, 1, 3, 1, 'REM-OVG-L-NEG',   18000.00,  3, 5),
    (3,  1, 2, 2, 2, 'REM-OVG-M-BLA',   18000.00,  0, 5),
    (4,  2, 5, 3, 3, 'BUZ-HOOD-L-GRI',  30000.00, 10, 4),
    (5,  2, 5, 2, 1, 'BUZ-HOOD-M-NEG',  30000.00,  2, 4),
    (6,  3, 1, 7, 6, 'PAN-CARGO-40-BEI',27000.00,  8, 3),
    (7,  3, 2, 6, 1, 'PAN-CARGO-38-NEG',27000.00,  0, 3),
    (8,  4, 1, 2, 5, 'BER-BAG-M-CEL',   15000.00,  6, 3),
    (9,  4, 2, 1, 2, 'BER-BAG-S-BLA',   15000.00,  1, 3),
    (10, 5, 5, 3, 1, 'CAM-PUF-L-NEG',   48000.00,  4, 2),
    (11, 6, 3, 1, 2, 'REM-BAS-S-BLA',   10000.00,  0, 5),
    (12, 6, 4, 1, 7, 'REM-BAS-S-ROJ',   10000.00,  2, 5);


-- 4. proveedores y clientes

INSERT INTO dbo.Proveedor (IdProveedor, RazonSocial, CUIT, Telefono, Email, Direccion) VALUES
    (1, 'Distribuidora Norte S.A.', '30-71234567-8', '011-4555-1001', 'ventas@norte.com', 'Av. Cabildo 1234'),
    (2, 'Textil Sur S.R.L.',        '30-70987654-3', '011-4555-1002', 'pedidos@textilsur.com', 'San Juan 456'),
    (3, 'Importadora Centro',       '30-70111222-9', '011-4555-1003', 'compras@centro.com', 'Rivadavia 789');

INSERT INTO dbo.Cliente (IdCliente, Nombre, Apellido, DNI, Telefono, Email, Direccion) VALUES
    (1, 'Lucía',  'Gómez',    '30111222', '11-5555-2001', 'lucia.gomez@mail.com',  'Palermo 111'),
    (2, 'Martín', 'Pérez',    '28999888', '11-5555-2002', 'martin.perez@mail.com', 'Belgrano 222'),
    (3, 'Sofía',  'Rodríguez','33444555', '11-5555-2003', 'sofia.rodriguez@mail.com','Caballito 333');


-- 5. compras

-- Compra 1: se registra PENDIENTE y se recibe. Suma 5 unidades a la variante 1.
EXEC dbo.SP_RegistrarCompra
    @IdProveedor = 1, @IdUsuario = 1,
    @IdVariante = 1, @Cantidad = 5, @CostoUnitario = 9000.00,
    @NroComprobante = 'FC-A-0001-00000001';

EXEC dbo.SP_RecibirCompra @IdCompra = 1, @IdUsuario = 1;

-- Compra 2: queda PENDIENTE. No modifica el stock hasta que se reciba.
EXEC dbo.SP_RegistrarCompra
    @IdProveedor = 2, @IdUsuario = 1,
    @IdVariante = 4, @Cantidad = 5, @CostoUnitario = 15000.00,
    @NroComprobante = 'FC-B-0001-00000002';

-- Compra 3: se registra PENDIENTE y se anula sin mover stock.
EXEC dbo.SP_RegistrarCompra
    @IdProveedor = 3, @IdUsuario = 1,
    @IdVariante = 2, @Cantidad = 10, @CostoUnitario = 9000.00,
    @NroComprobante = 'FC-C-0001-00000003';

UPDATE dbo.Compra
SET Estado = 'ANULADA'
WHERE IdCompra = 3;


-- 6. ventas

-- Venta 1: CONFIRMADA. Vendedor 1, cliente 1.
EXEC dbo.SP_RegistrarVenta
    @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO',
    @IdVariante = 1, @Cantidad = 2;

-- Venta 2: CONFIRMADA. Vendedor 1, cliente 1 (compra un buzo).
EXEC dbo.SP_RegistrarVenta
    @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO',
    @IdVariante = 4, @Cantidad = 1;

-- Venta 3: CONFIRMADA y luego ANULADA por el administrador.
EXEC dbo.SP_RegistrarVenta
    @IdCliente = 2, @IdUsuario = 3, @MedioPago = 'DEBITO',
    @IdVariante = 8, @Cantidad = 2;

EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 1;

-- Venta 4: CONFIRMADA, consumidor final. La variante 10 baja de 4 a 2
-- unidades, llega al mínimo y TR_AvisoStockMinimo genera una alerta.
EXEC dbo.SP_RegistrarVenta
    @IdCliente = NULL, @IdUsuario = 2, @MedioPago = 'TRANSFERENCIA',
    @IdVariante = 10, @Cantidad = 2;

-- Venta 5: CONFIRMADA con descuento de $2000.
EXEC dbo.SP_RegistrarVenta
    @IdCliente = 3, @IdUsuario = 3, @MedioPago = 'CREDITO',
    @IdVariante = 6, @Cantidad = 1, @Descuento = 2000.00;

-- Venta 6: CONFIRMADA y luego ANULADA.
EXEC dbo.SP_RegistrarVenta
    @IdCliente = 3, @IdUsuario = 3, @MedioPago = 'CREDITO',
    @IdVariante = 9, @Cantidad = 1;

EXEC dbo.SP_AnularVenta @IdVenta = 6, @IdUsuario = 1;


-- 7. ajustes de stock

-- Ajuste real: la variante 1 pasa de 23 a 22 (movimiento AJUSTE -1).
EXEC dbo.SP_AjustarStock
    @IdVariante = 1, @NuevaCantidad = 22, @IdUsuario = 1,
    @Observacion = 'Ajuste por recuento físico';

-- Ajuste sin diferencia: no genera movimiento.
EXEC dbo.SP_AjustarStock
    @IdVariante = 1, @NuevaCantidad = 22, @IdUsuario = 1,
    @Observacion = 'Prueba de ajuste sin diferencia';


-- 8. casos de error
-- Cada caso se ejecuta dentro de BEGIN TRY / BEGIN CATCH para mostrar
-- el error y que el seed pueda seguir.

-- 8.1 Venta sin stock: la variante 3 tiene stock 0. Esperado: 50006.
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO',
        @IdVariante = 3, @Cantidad = 1;
    SELECT '8.1 VENTA_SIN_STOCK' AS Caso, 'ERROR: la venta no debió registrarse' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.1 VENTA_SIN_STOCK' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.2 Compra con cantidad 0. Esperado: 50104.
BEGIN TRY
    EXEC dbo.SP_RegistrarCompra
        @IdProveedor = 1, @IdUsuario = 1,
        @IdVariante = 1, @Cantidad = 0, @CostoUnitario = 9000.00;
    SELECT '8.2 COMPRA_CANTIDAD_CERO' AS Caso, 'ERROR: la compra no debió registrarse' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.2 COMPRA_CANTIDAD_CERO' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.3 Recibir una compra sin líneas. Esperado: 50111.
-- Se inserta una cabecera PENDIENTE sin detalle solo para la prueba.
INSERT INTO dbo.Compra (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
VALUES (4, 1, 1, GETDATE(), 'TEST-RECEPCION-SIN-LINEAS', 0, 'PENDIENTE');

BEGIN TRY
    EXEC dbo.SP_RecibirCompra @IdCompra = 4, @IdUsuario = 1;
    SELECT '8.3 RECEPCION_SIN_LINEAS' AS Caso, 'ERROR: la compra no debió recibirse' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.3 RECEPCION_SIN_LINEAS' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- La compra de prueba queda anulada.
UPDATE dbo.Compra
SET Estado = 'ANULADA'
WHERE IdCompra = 4;

-- 8.4 Anular una venta ya anulada (venta 3). Esperado: 50011.
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 1;
    SELECT '8.4 ANULACION_DUPLICADA' AS Caso, 'ERROR: la venta no debió anularse dos veces' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.4 ANULACION_DUPLICADA' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.5 Un vendedor intenta anular una venta. Esperado: 50013.
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;
    SELECT '8.5 ANULACION_POR_VENDEDOR' AS Caso, 'ERROR: un vendedor no debió anular' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.5 ANULACION_POR_VENDEDOR' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.6 Un vendedor intenta ajustar stock. Esperado: 50023.
BEGIN TRY
    EXEC dbo.SP_AjustarStock
        @IdVariante = 1, @NuevaCantidad = 10, @IdUsuario = 2,
        @Observacion = 'Prueba de rol no autorizado';
    SELECT '8.6 AJUSTE_POR_VENDEDOR' AS Caso, 'ERROR: un vendedor no debió ajustar stock' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.6 AJUSTE_POR_VENDEDOR' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.7 Un vendedor intenta registrar una compra. Esperado: 50107.
BEGIN TRY
    EXEC dbo.SP_RegistrarCompra
        @IdProveedor = 1, @IdUsuario = 2,
        @IdVariante = 1, @Cantidad = 1, @CostoUnitario = 9000.00;
    SELECT '8.7 COMPRA_POR_VENDEDOR' AS Caso, 'ERROR: un vendedor no debió registrar una compra' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.7 COMPRA_POR_VENDEDOR' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.8 Un vendedor intenta recibir la compra 2 (PENDIENTE). Esperado: 50114.
BEGIN TRY
    EXEC dbo.SP_RecibirCompra @IdCompra = 2, @IdUsuario = 2;
    SELECT '8.8 RECEPCION_POR_VENDEDOR' AS Caso, 'ERROR: un vendedor no debió recibir una compra' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.8 RECEPCION_POR_VENDEDOR' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.9 Venta registrada por un usuario inactivo. Esperado: 50002.
BEGIN TRY
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 4, @MedioPago = 'EFECTIVO',
        @IdVariante = 1, @Cantidad = 1;
    SELECT '8.9 VENTA_USUARIO_INACTIVO' AS Caso, 'ERROR: un usuario inactivo no debió vender' AS Resultado;
END TRY
BEGIN CATCH
    SELECT '8.9 VENTA_USUARIO_INACTIVO' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.10 Borrar una venta. TR_NoBorrarVenta lo impide. Esperado: 50203.
BEGIN TRY
    DELETE FROM dbo.Venta WHERE IdVenta = 1;
    SELECT '8.10 BORRAR_VENTA' AS Caso, 'ERROR: la venta no debió borrarse' AS Resultado;
END TRY
BEGIN CATCH
    -- el error lo tira un trigger, hago rollback por si quedó algo abierto
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    SELECT '8.10 BORRAR_VENTA' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 8.11 Reactivar una venta anulada. TR_DevolverStockAnulacion lo impide. Esperado: 50201.
BEGIN TRY
    UPDATE dbo.Venta SET Estado = 'CONFIRMADA' WHERE IdVenta = 3;
    SELECT '8.11 REACTIVAR_VENTA' AS Caso, 'ERROR: la venta no debió reactivarse' AS Resultado;
END TRY
BEGIN CATCH
    -- el error lo tira un trigger, hago rollback por si quedó algo abierto
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    SELECT '8.11 REACTIVAR_VENTA' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;


-- 9. resumen

SELECT 'Roles' AS Tabla, COUNT(*) AS Cantidad FROM dbo.Rol
UNION ALL SELECT 'Usuarios', COUNT(*) FROM dbo.Usuario
UNION ALL SELECT 'Productos', COUNT(*) FROM dbo.Producto
UNION ALL SELECT 'Variantes', COUNT(*) FROM dbo.VarianteProducto
UNION ALL SELECT 'Proveedores', COUNT(*) FROM dbo.Proveedor
UNION ALL SELECT 'Clientes', COUNT(*) FROM dbo.Cliente
UNION ALL SELECT 'Compras', COUNT(*) FROM dbo.Compra
UNION ALL SELECT 'DetalleCompras', COUNT(*) FROM dbo.DetalleCompra
UNION ALL SELECT 'Ventas', COUNT(*) FROM dbo.Venta
UNION ALL SELECT 'DetalleVentas', COUNT(*) FROM dbo.DetalleVenta
UNION ALL SELECT 'MovimientosStock', COUNT(*) FROM dbo.MovimientoStock
UNION ALL SELECT 'AlertasStock', COUNT(*) FROM dbo.AlertaStock;
GO

-- ===== Subconsultas.sql =====

USE SIAM;
GO

-- Subconsulta: Clientes que han comprado ropa de la categoria 'Buzos'

SELECT Nombre, Apellido, DNI
FROM Cliente
WHERE IdCliente IN(
    SELECT v.IdCliente
    FROM Venta v
    INNER JOIN DetalleVenta dv ON v.idVenta = dv.IdVenta
    INNER JOIN VarianteProducto vp ON dv.IdVariante = vp.IdVariante
    INNER JOIN Producto P on vp.IdProducto = p.IdProducto
    INNER JOIN Categoria c ON p.IdCategoria = c.IdCategoria
    WHERE c.Nombre = 'Buzos'
      AND v.Estado = 'CONFIRMADA'   -- una venta anulada no cuenta como compra
);

-- Subconsultas con NOT EXISTS: Productos que nunca han tenido ventas registradas
SELECT p.IdProducto, p.Nombre
FROM Producto p 
WHERE NOT EXISTS(
    SELECT 1
    FROM VarianteProducto vp
    INNER JOIN DetalleVenta dv ON vp.IdVariante = dv.IdVariante
    INNER JOIN Venta v ON v.IdVenta = dv.IdVenta
    WHERE vp.IdProducto = p.IdProducto
      AND v.Estado = 'CONFIRMADA'   -- si solo tuvo ventas anuladas, cuenta como "nunca vendido"
);
-- 2.3 Subconsulta con ALL (o > ANY): Variantes cuyo precio es mayor a TODOS los precios de la marca 'Nangallery'
SELECT vp.SKU, vp.PrecioVenta 
FROM VarianteProducto vp
WHERE vp.PrecioVenta > ALL (
    SELECT p.PrecioBase 
    FROM Producto p
    INNER JOIN Marca m ON p.IdMarca = m.IdMarca
    WHERE m.Nombre = 'Nangallery'
);

-- ===== sp/ConsultasAvanzadas.sql =====

USE SIAM;
GO

-- PARTE 1: OPERACIONES DE CONJUNTOS (UNION)

-- Une las compras y ventas en un mismo listado.

SELECT
    'VENTA' AS TipoOperacion,
    v.IdVenta AS NroOperacion,
    v.Fecha,
    ISNULL(c.Nombre + ' ' + c.Apellido, 'Consumidor Final') AS Tercero,
    u.NombreUsuario AS Responsable,
    v.Total
FROM Venta v
LEFT JOIN Cliente c ON v.IdCliente = c.IdCliente
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
WHERE v.Estado = 'CONFIRMADA'

UNION

SELECT
    'COMPRA' AS TipoOperacion,
    co.IdCompra AS NroOperacion,
    co.Fecha,
    p.RazonSocial AS Tercero,
    u.NombreUsuario AS Responsable,
    co.Total
FROM Compra co
INNER JOIN Proveedor p ON co.IdProveedor = p.IdProveedor
INNER JOIN Usuario u ON co.IdUsuario = u.IdUsuario
WHERE co.Estado = 'RECIBIDA'
ORDER BY Fecha DESC;
GO

-- PARTE 2: AGRUPACIÓN Y AGREGACIÓN (GROUP BY + HAVING)

-- Ranking de vendedores
-- Muestra las ventas y el promedio facturado por cada vendedor.

SELECT 
    u.NombreUsuario,
    u.Nombre + ' ' + u.Apellido AS NombreCompleto,
    COUNT(v.IdVenta) AS CantidadVentas,
    SUM(v.Total) AS TotalFacturado,
    AVG(v.Total) AS TicketPromedio
FROM Venta v
INNER JOIN Usuario u ON v.IdUsuario = u.IdUsuario
WHERE v.Estado = 'CONFIRMADA'
GROUP BY u.NombreUsuario, u.Nombre, u.Apellido
HAVING SUM(v.Total) > 0 -- Muestra vendedores que hayan realizado ventas.
ORDER BY TotalFacturado DESC;
GO


-- Ventas por mes y medio de pago
-- Agrupa las ventas para conocer la recaudación de cada mes.

SELECT 
    YEAR(v.Fecha) AS Anio,
    MONTH(v.Fecha) AS Mes,
    v.MedioPago,
    COUNT(v.IdVenta) AS CantidadOperaciones,
    SUM(v.Total) AS TotalRecaudado
FROM Venta v
WHERE v.Estado = 'CONFIRMADA'
GROUP BY YEAR(v.Fecha), MONTH(v.Fecha), v.MedioPago
ORDER BY Anio DESC, Mes DESC, TotalRecaudado DESC;
GO


-- PARTE 3: SUBCONSULTAS LÓGICAS (EXISTS, IN, ALL)

-- Busca los productos que pertenecen a la categoría Buzos.

SELECT p.IdProducto, p.Nombre, p.PrecioBase
FROM Producto p
WHERE p.IdCategoria IN (
    SELECT IdCategoria 
    FROM Categoria 
    WHERE Nombre LIKE '%Buzo%' -- Busca categorías que contengan Buzo.
);

-- Subconsulta con NOT EXISTS
-- Muestra los productos que nunca fueron vendidos.

SELECT p.IdProducto, p.Nombre 
FROM Producto p
WHERE NOT EXISTS (
    SELECT 1 
    FROM VarianteProducto vp
    INNER JOIN DetalleVenta dv ON vp.IdVariante = dv.IdVariante
    INNER JOIN Venta v ON v.IdVenta = dv.IdVenta
    WHERE vp.IdProducto = p.IdProducto -- Relaciona las variantes con el producto.
      AND v.Estado = 'CONFIRMADA'      -- Las ventas anuladas no cuentan.
);
-- Subconsulta con ALL
-- Busca variantes más caras que todos los productos de la marca Nangallery.

SELECT vp.SKU, vp.PrecioVenta 
FROM VarianteProducto vp
WHERE vp.PrecioVenta > ALL (
    SELECT p.PrecioBase 
    FROM Producto p
    INNER JOIN Marca m ON p.IdMarca = m.IdMarca
    WHERE m.Nombre = 'Nangallery'
);
GO

-- PARTE 4: SUBCONSULTAS CORRELACIONADAS

-- Variantes con precio superior al promedio de su categoría
-- Compara el precio de cada variante con el promedio de su categoría.

SELECT 
    p.Nombre AS Producto,
    vp.SKU,
    vp.PrecioVenta,
    c.Nombre AS Categoria
FROM VarianteProducto vp
INNER JOIN Producto p ON vp.IdProducto = p.IdProducto
INNER JOIN Categoria c ON p.IdCategoria = c.IdCategoria
WHERE vp.PrecioVenta > (
    SELECT AVG(vp2.PrecioVenta)
    FROM VarianteProducto vp2
    INNER JOIN Producto p2 ON vp2.IdProducto = p2.IdProducto
    WHERE p2.IdCategoria = p.IdCategoria -- Compara con la misma categoría.
);
GO

-- ===== seguridad.sql =====

-- seguridad: logins -> usuarios -> roles -> permisos
-- a cada rol le doy con GRANT solo lo que necesita

-- 1. logins
-- no se borran al recrear la base, asi que se crean solo si no existen
-- (las contraseñas son de ejemplo)
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_admin_siam')
    CREATE LOGIN login_admin_siam WITH PASSWORD = 'Siam_Admin_2026!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'login_vendedor_siam')
    CREATE LOGIN login_vendedor_siam WITH PASSWORD = 'Siam_Vend_2026!';
GO

-- 2. usuarios de la base
USE SIAM;
GO

CREATE USER usr_admin FOR LOGIN login_admin_siam;
CREATE USER usr_vendedor FOR LOGIN login_vendedor_siam;
GO

-- 3. roles
CREATE ROLE rol_administrador;
CREATE ROLE rol_vendedor;
GO

ALTER ROLE rol_administrador ADD MEMBER usr_admin;
ALTER ROLE rol_vendedor ADD MEMBER usr_vendedor;
GO

-- 4. permisos del administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Rol       TO rol_administrador;

-- usuarios: el select es por columna, sin Contrasena, para que no pueda leerla
GRANT SELECT (IdUsuario, IdRol, NombreUsuario, Email, Nombre, Apellido, Activo, FechaAlta)
    ON dbo.Usuario TO rol_administrador;
GRANT INSERT, UPDATE, DELETE ON dbo.Usuario TO rol_administrador;

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Categoria TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Segmento  TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Marca     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Talle     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Color     TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Producto  TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Proveedor TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Cliente   TO rol_administrador;

-- variantes: sin DELETE porque las usan las ventas y compras
-- el update es solo de precio y minimo, el stock no se toca directo
GRANT SELECT, INSERT ON dbo.VarianteProducto TO rol_administrador;
GRANT UPDATE (PrecioVenta, StockMinimo) ON dbo.VarianteProducto TO rol_administrador;

-- ventas, compras y movimientos: solo lectura, se modifican con los SP
GRANT SELECT ON dbo.Venta           TO rol_administrador;
GRANT SELECT ON dbo.DetalleVenta    TO rol_administrador;
GRANT SELECT ON dbo.Compra          TO rol_administrador;
GRANT SELECT ON dbo.DetalleCompra   TO rol_administrador;
GRANT SELECT ON dbo.MovimientoStock TO rol_administrador;
GRANT SELECT ON dbo.HistorialPrecio TO rol_administrador;

-- alertas: las puede marcar como atendidas
GRANT SELECT, UPDATE ON dbo.AlertaStock TO rol_administrador;

-- vistas
GRANT SELECT ON dbo.vw_StockVariante                    TO rol_administrador;
GRANT SELECT ON dbo.vw_VentasDetalladas                 TO rol_administrador;
GRANT SELECT ON dbo.vw_ProductosPremium                 TO rol_administrador;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_administrador;

-- stored procedures
GRANT EXECUTE ON dbo.SP_RegistrarVenta         TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AnularVenta            TO rol_administrador;
GRANT EXECUTE ON dbo.SP_AjustarStock           TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RegistrarCompra        TO rol_administrador;
GRANT EXECUTE ON dbo.SP_RecibirCompra          TO rol_administrador;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_administrador;

-- funciones
GRANT EXECUTE ON dbo.fn_EstadoStock             TO rol_administrador;
GRANT SELECT  ON dbo.fn_ResumenVentasPorUsuario TO rol_administrador;
GO

-- 5. permisos del vendedor
GRANT SELECT ON dbo.Producto         TO rol_vendedor;
GRANT SELECT ON dbo.VarianteProducto TO rol_vendedor;
GRANT SELECT ON dbo.Categoria        TO rol_vendedor;
GRANT SELECT ON dbo.Marca            TO rol_vendedor;
GRANT SELECT ON dbo.Talle            TO rol_vendedor;
GRANT SELECT ON dbo.Color            TO rol_vendedor;
GRANT SELECT ON dbo.Segmento         TO rol_vendedor;
GRANT SELECT ON dbo.Cliente          TO rol_vendedor;

-- vistas
GRANT SELECT ON dbo.vw_StockVariante                    TO rol_vendedor;
GRANT SELECT ON dbo.vw_VentasDetalladas                 TO rol_vendedor;
GRANT SELECT ON dbo.vw_ProductosPremium                 TO rol_vendedor;
GRANT SELECT ON dbo.vw_CategoriasMasVendidasPorSegmento TO rol_vendedor;

-- puede registrar ventas y ver reposicion
GRANT EXECUTE ON dbo.SP_RegistrarVenta         TO rol_vendedor;
GRANT EXECUTE ON dbo.SP_InformeReposicionStock TO rol_vendedor;
GRANT EXECUTE ON dbo.fn_EstadoStock            TO rol_vendedor;
GO

-- el vendedor no puede ver usuarios, compras ni proveedores, ni anular ventas
-- ni ajustar stock (para sacar un permiso: REVOKE)

PRINT 'Seguridad SIAM aplicada: logins, usuarios, roles y permisos configurados.';
GO
