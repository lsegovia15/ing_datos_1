CREATE DATABASE SIAM ;--Sistema Integrado Administracion Multiple
GO

USE SIAM
GO
;

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
 
CREATE TABLE CategoriaSegmento (
    IdCategoriaSegmento INT         NOT NULL,
    IdCategoria         INT         NOT NULL,
    Nombre              VARCHAR(50) NOT NULL,
    CONSTRAINT PK_CategoriaSegmento PRIMARY KEY (IdCategoriaSegmento),
    CONSTRAINT UQ_CategoriaSegmento UNIQUE (IdCategoria, Nombre)
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
    IdProducto          INT           NOT NULL,
    IdCategoriaSegmento INT           NOT NULL,
    IdMarca             INT           NOT NULL,
    Nombre              VARCHAR(100)  NOT NULL,
    Descripcion         VARCHAR(500)  NULL,
    PrecioBase          DECIMAL(12,2) NOT NULL,
    Activo              INT           NOT NULL DEFAULT 1,
    CONSTRAINT PK_Producto PRIMARY KEY (IdProducto),
    CONSTRAINT CK_Producto_Precio CHECK (PrecioBase >= 0),
    CONSTRAINT CK_Producto_Activo CHECK (Activo IN (0, 1))
);
 
CREATE TABLE VarianteProducto (
    IdVariante      INT           NOT NULL,
    IdProducto      INT           NOT NULL,
    IdTalle         INT           NOT NULL,
    IdColor         INT           NOT NULL,
    SKU             VARCHAR(30)   NOT NULL,
    PrecioVenta     DECIMAL(12,2) NOT NULL,
    StockActual     INT           NOT NULL DEFAULT 0,
    StockMinimo     INT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_VarianteProducto PRIMARY KEY (IdVariante),
    CONSTRAINT UQ_Variante_SKU UNIQUE (SKU),
    CONSTRAINT UQ_Variante_Combinacion UNIQUE (IdProducto, IdTalle, IdColor),
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
    CONSTRAINT CK_Mov_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Mov_Origen CHECK (IdCompra IS NULL OR IdVenta IS NULL)
);
GO
 