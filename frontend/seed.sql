-- ============================================
-- SIAM - Datos de prueba para el frontend
-- Se ejecuta despues de init_db.sql y antes de SPs / vistas / triggers
-- ============================================

USE SIAM;
GO

INSERT INTO Rol (IdRol, Nombre, Descripcion) VALUES
    (1, 'Administrador', 'Acceso total al sistema'),
    (2, 'Vendedor',      'Operacion diaria del local');

INSERT INTO Usuario (IdUsuario, IdRol, NombreUsuario, Email, Contrasena, Nombre, Apellido, Activo) VALUES
    (1, 1, 'admin',    'admin@firme38.com',    'hash_admin',   'Ana',   'Gomez',  1),
    (2, 2, 'vendedor', 'vendedor@firme38.com', 'hash_vend',    'Bruno', 'Perez',  1),
    (3, 2, 'inactivo', 'inactivo@firme38.com', 'hash_inact',   'Carla', 'Lopez',  0);

INSERT INTO Categoria (IdCategoria, Nombre, Descripcion) VALUES
    (1, 'Remeras',    'Remeras de algodon'),
    (2, 'Buzos',      'Buzos y hoodies'),
    (3, 'Pantalones', 'Jeans y joggers');

INSERT INTO Segmento (IdSegmento, Nombre) VALUES
    (1, 'Hombre'), (2, 'Mujer'), (3, 'Unisex');

INSERT INTO Marca (IdMarca, Nombre) VALUES
    (1, 'Firme38'), (2, 'UrbanCo'), (3, 'MarcaEjemplo');

INSERT INTO Talle (IdTalle, Descripcion) VALUES
    (1, 'S'), (2, 'M'), (3, 'L'), (4, 'XL');

INSERT INTO Color (IdColor, Nombre) VALUES
    (1, 'Negro'), (2, 'Blanco'), (3, 'Gris');

INSERT INTO Producto (IdProducto, IdCategoria, IdMarca, Nombre, Descripcion, PrecioBase, Activo) VALUES
    (1, 1, 1, 'Remera Basica',   'Remera lisa cuello redondo', 15000, 1),
    (2, 2, 1, 'Buzo Hoodie',     'Buzo con capucha',           42000, 1),
    (3, 3, 2, 'Jogger Cargo',    'Jogger con bolsillos',       38000, 1),
    (4, 1, 3, 'Remera Estampada','Remera con estampa',         18000, 1),
    (5, 2, 2, 'Buzo Discontinuado', 'Producto dado de baja',   30000, 0);

INSERT INTO VarianteProducto (IdVariante, IdProducto, IdSegmento, IdTalle, IdColor, SKU, PrecioVenta, StockActual, StockMinimo) VALUES
    (1,  1, 3, 1, 1, 'REM-BAS-S-NEG',  15000, 20, 5),
    (2,  1, 3, 2, 1, 'REM-BAS-M-NEG',  15000, 15, 5),
    (3,  1, 3, 2, 2, 'REM-BAS-M-BLA',  15000,  6, 5),
    (4,  2, 1, 3, 3, 'BUZ-HOO-L-GRI',  42000, 10, 3),
    (5,  2, 2, 1, 1, 'BUZ-HOO-S-NEG',  42000,  3, 3),
    (6,  3, 1, 3, 1, 'JOG-CAR-L-NEG',  38000,  8, 2),
    (7,  3, 1, 4, 3, 'JOG-CAR-XL-GRI', 38000,  0, 2),
    (8,  4, 3, 2, 2, 'REM-EST-M-BLA',  18000, 12, 4),
    (9,  5, 1, 2, 3, 'BUZ-DIS-M-GRI',  30000,  5, 1);

INSERT INTO Proveedor (IdProveedor, RazonSocial, CUIT, Telefono, Email, Direccion) VALUES
    (1, 'Textil Sur SA',     '30-71234567-8', '11-4000-1000', 'ventas@textilsur.com', 'Av. Siempreviva 742'),
    (2, 'Confecciones Norte','30-79876543-2', '11-4000-2000', 'info@cnorte.com',      'Calle Falsa 123');

INSERT INTO Cliente (IdCliente, Nombre, Apellido, DNI, Email, Telefono, Direccion) VALUES
    (1, 'Juan',  'Martinez', '30111222', 'juan@mail.com',  '11-5555-0001', 'Belgrano 100'),
    (2, 'Lucia', 'Fernandez','32333444', 'lucia@mail.com', '11-5555-0002', 'Rivadavia 2000'),
    (3, 'Pedro', 'Sosa',     '28999888', NULL,             NULL,           NULL);

-- Una compra PENDIENTE con lineas (para probar el paso a RECIBIDA)
INSERT INTO Compra (IdCompra, IdProveedor, IdUsuario, NroComprobante, Total, Estado) VALUES
    (1, 1, 1, 'FC-A-0001-00000001', 0, 'PENDIENTE');

INSERT INTO DetalleCompra (IdCompra, NroLinea, IdVariante, Cantidad, CostoUnitario) VALUES
    (1, 1, 1, 10, 7000),
    (1, 2, 7,  5, 19000);

UPDATE Compra SET Total = 10 * 7000 + 5 * 19000 WHERE IdCompra = 1;
GO
