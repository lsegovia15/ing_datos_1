
IF DB_ID('SIAM') IS NOT NULL
BEGIN
    ALTER DATABASE SIAM SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SIAM;
END
GO

CREATE DATABASE SIAM;
GO

USE SIAM;
GO


-- TABLAS

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

-- Segmento: público al que va dirigida una variante (Hombre, Mujer, Niño, Niña, Unisex)
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


-- FOREIGN KEYS


ALTER TABLE Usuario ADD CONSTRAINT FK_Usuario_Rol
    FOREIGN KEY (IdRol) REFERENCES Rol (IdRol)
    ON DELETE NO ACTION;

ALTER TABLE Producto ADD CONSTRAINT FK_Producto_Categoria
    FOREIGN KEY (IdCategoria) REFERENCES Categoria (IdCategoria)
    ON DELETE NO ACTION;

ALTER TABLE Producto ADD CONSTRAINT FK_Producto_Marca
    FOREIGN KEY (IdMarca) REFERENCES Marca (IdMarca)
    ON DELETE NO ACTION;

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Producto
    FOREIGN KEY (IdProducto) REFERENCES Producto (IdProducto)
    ON DELETE NO ACTION;

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Segmento
    FOREIGN KEY (IdSegmento) REFERENCES Segmento (IdSegmento)
    ON DELETE NO ACTION;

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Talle
    FOREIGN KEY (IdTalle) REFERENCES Talle (IdTalle)
    ON DELETE NO ACTION;

ALTER TABLE VarianteProducto ADD CONSTRAINT FK_Variante_Color
    FOREIGN KEY (IdColor) REFERENCES Color (IdColor)
    ON DELETE NO ACTION;

ALTER TABLE Compra ADD CONSTRAINT FK_Compra_Proveedor
    FOREIGN KEY (IdProveedor) REFERENCES Proveedor (IdProveedor)
    ON DELETE NO ACTION;

ALTER TABLE Compra ADD CONSTRAINT FK_Compra_Usuario
    FOREIGN KEY (IdUsuario) REFERENCES Usuario (IdUsuario)
    ON DELETE NO ACTION;

ALTER TABLE DetalleCompra ADD CONSTRAINT FK_DetalleCompra_Compra
    FOREIGN KEY (IdCompra) REFERENCES Compra (IdCompra)
    ON DELETE CASCADE;

ALTER TABLE DetalleCompra ADD CONSTRAINT FK_DetalleCompra_Variante
    FOREIGN KEY (IdVariante) REFERENCES VarianteProducto (IdVariante)
    ON DELETE NO ACTION;

ALTER TABLE Venta ADD CONSTRAINT FK_Venta_Cliente
    FOREIGN KEY (IdCliente) REFERENCES Cliente (IdCliente)
    ON DELETE SET NULL;

ALTER TABLE Venta ADD CONSTRAINT FK_Venta_Usuario
    FOREIGN KEY (IdUsuario) REFERENCES Usuario (IdUsuario)
    ON DELETE NO ACTION;

ALTER TABLE DetalleVenta ADD CONSTRAINT FK_DetalleVenta_Venta
    FOREIGN KEY (IdVenta) REFERENCES Venta (IdVenta)
    ON DELETE CASCADE;

ALTER TABLE DetalleVenta ADD CONSTRAINT FK_DetalleVenta_Variante
    FOREIGN KEY (IdVariante) REFERENCES VarianteProducto (IdVariante)
    ON DELETE NO ACTION;

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Variante
    FOREIGN KEY (IdVariante) REFERENCES VarianteProducto (IdVariante)
    ON DELETE NO ACTION;

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Usuario
    FOREIGN KEY (IdUsuario) REFERENCES Usuario (IdUsuario)
    ON DELETE NO ACTION;

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Compra
    FOREIGN KEY (IdCompra) REFERENCES Compra (IdCompra)
    ON DELETE SET NULL;

ALTER TABLE MovimientoStock ADD CONSTRAINT FK_Mov_Venta
    FOREIGN KEY (IdVenta) REFERENCES Venta (IdVenta)
    ON DELETE SET NULL;
GO

-- ÍNDICES

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
