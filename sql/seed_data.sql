USE SIAM;
GO

SET NOCOUNT ON;

-- ============================================================
-- SIAM - Datos de prueba
-- Ejecutar después de init_db, triggers, funciones, vistas,
-- tipos TVP y stored procedures.
-- ============================================================

IF EXISTS (SELECT 1 FROM dbo.Rol)
BEGIN
    PRINT 'Seed ya aplicado: la tabla Rol contiene datos. No se vuelve a ejecutar.';
    RETURN;
END;

-- ============================================================
-- 1. ROLES Y USUARIOS DE APLICACIÓN
-- ============================================================
INSERT INTO dbo.Rol (IdRol, Nombre, Descripcion) VALUES
    (1, 'Administrador', 'Acceso total: catálogo, compras, stock, ventas, anulaciones y seguridad.'),
    (2, 'Vendedor',      'Registra ventas y consulta catálogo, stock y reportes de reposición.');

INSERT INTO dbo.Usuario
    (IdUsuario, IdRol, NombreUsuario, Email, Contrasena, Nombre, Apellido, Activo)
VALUES
    (1, 1, 'admin',           'admin@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Admin123!'), 2),
        'Ana',   'Administradora', 1),
    (2, 2, 'vendedor1',       'vendedor1@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Vendedor123!'), 2),
        'Bruno', 'Vendedor',       1),
    (3, 2, 'vendedor2',       'vendedor2@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Vendedor123!'), 2),
        'Carla', 'Vendedora',      1),
    (4, 2, 'vendedor_inactivo', 'inactivo@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Inactivo123!'), 2),
        'Diego', 'Inactivo',       0);

-- ============================================================
-- 2. CATÁLOGOS
-- ============================================================
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

-- ============================================================
-- 3. PRODUCTOS Y VARIANTES
-- Stock inicial 0: el stock real ingresa con la compra recibida.
-- Así los movimientos de ENTRADA quedan coherentes.
-- ============================================================
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
    (1,  1, 1, 2, 1, 'REM-OVG-M-NEG',   18000.00, 0, 5),
    (2,  1, 1, 3, 1, 'REM-OVG-L-NEG',   18000.00, 0, 5),
    (3,  1, 2, 2, 2, 'REM-OVG-M-BLA',   18000.00, 0, 5),
    (4,  2, 5, 3, 3, 'BUZ-HOOD-L-GRI',  30000.00, 0, 4),
    (5,  2, 5, 2, 1, 'BUZ-HOOD-M-NEG',  30000.00, 0, 4),
    (6,  3, 1, 7, 6, 'PAN-CARGO-40-BEI',27000.00, 0, 3),
    (7,  3, 2, 6, 1, 'PAN-CARGO-38-NEG',27000.00, 0, 3),
    (8,  4, 1, 2, 5, 'BER-BAG-M-CEL',   15000.00, 0, 3),
    (9,  4, 2, 1, 2, 'BER-BAG-S-BLA',   15000.00, 0, 3),
    (10, 5, 5, 3, 1, 'CAM-PUF-L-NEG',   48000.00, 0, 2),
    (11, 6, 3, 1, 2, 'REM-BAS-S-BLA',   10000.00, 0, 5),
    (12, 6, 4, 1, 7, 'REM-BAS-S-ROJ',   10000.00, 0, 5);

-- ============================================================
-- 4. PROVEEDORES Y CLIENTES
-- ============================================================
INSERT INTO dbo.Proveedor (IdProveedor, RazonSocial, CUIT, Telefono, Email, Direccion) VALUES
    (1, 'Distribuidora Norte S.A.', '30-71234567-8', '011-4555-1001', 'ventas@norte.com', 'Av. Cabildo 1234'),
    (2, 'Textil Sur S.R.L.',        '30-70987654-3', '011-4555-1002', 'pedidos@textilsur.com', 'San Juan 456'),
    (3, 'Importadora Centro',       '30-70111222-9', '011-4555-1003', 'compras@centro.com', 'Rivadavia 789');

INSERT INTO dbo.Cliente (IdCliente, Nombre, Apellido, DNI, Telefono, Email, Direccion) VALUES
    (1, 'Lucía',  'Gómez',    '30111222', '11-5555-2001', 'lucia.gomez@mail.com',  'Palermo 111'),
    (2, 'Martín', 'Pérez',    '28999888', '11-5555-2002', 'martin.perez@mail.com', 'Belgrano 222'),
    (3, 'Sofía',  'Rodríguez','33444555', '11-5555-2003', 'sofia.rodriguez@mail.com','Caballito 333');

-- ============================================================
-- 5. COMPRAS
-- ============================================================
DECLARE @dc TipoDetalleCompra;
DECLARE @dv TipoDetalleVenta;
DECLARE @dcVacio TipoDetalleCompra;
DECLARE @dvSinStock TipoDetalleVenta;
DECLARE @StockActual INT;

-- Compra 1: RECIBIDA. Es la carga inicial de stock.
INSERT INTO @dc (IdVariante, Cantidad, CostoUnitario) VALUES
    (1, 20, 9000.00),
    (2,  3, 9000.00),
    (4, 10, 15000.00),
    (5,  2, 15000.00),
    (6,  8, 12000.00),
    (8,  6, 7000.00),
    (9,  1, 7000.00),
    (10, 4, 25000.00),
    (12, 2, 5000.00);

EXEC dbo.SP_RegistrarCompra
    @IdProveedor = 1,
    @IdUsuario = 1,
    @NroComprobante = 'FC-A-0001-00000001',
    @Detalle = @dc;

EXEC dbo.SP_RecibirCompra @IdCompra = 1, @IdUsuario = 1;

-- Cerrar las alertas iniciales de las variantes que ya quedaron con stock
-- suficiente. Las variantes bajas/cero conservan su alerta abierta.
UPDATE dbo.AlertaStock
SET Atendida = 1
WHERE Atendida = 0
  AND IdVariante IN (
      SELECT IdVariante
      FROM dbo.VarianteProducto
      WHERE StockActual > StockMinimo
  );

-- Compra 2: PENDIENTE. No modifica stock hasta que se reciba.
DELETE FROM @dc;
INSERT INTO @dc (IdVariante, Cantidad, CostoUnitario) VALUES
    (1, 5, 9000.00),
    (4, 5, 15000.00);

EXEC dbo.SP_RegistrarCompra
    @IdProveedor = 2,
    @IdUsuario = 1,
    @NroComprobante = 'FC-B-0001-00000002',
    @Detalle = @dc;

-- Compra 3: ANULADA. Se registra PENDIENTE y luego se anula sin mover stock.
DELETE FROM @dc;
INSERT INTO @dc (IdVariante, Cantidad, CostoUnitario) VALUES
    (2, 10, 9000.00),
    (9,  5, 7000.00);

EXEC dbo.SP_RegistrarCompra
    @IdProveedor = 3,
    @IdUsuario = 1,
    @NroComprobante = 'FC-C-0001-00000003',
    @Detalle = @dc;

UPDATE dbo.Compra
SET Estado = 'ANULADA'
WHERE IdCompra = 3;

-- ============================================================
-- 6. VENTAS
-- ============================================================
-- Venta 1: CONFIRMADA. Vendedor 1.
INSERT INTO @dv (IdVariante, Cantidad, PrecioUnitario, Descuento) VALUES
    (1, 2, 18000.00, 0),
    (4, 1, 30000.00, 0);

EXEC dbo.SP_RegistrarVenta
    @IdCliente = 1,
    @IdUsuario = 2,
    @MedioPago = 'EFECTIVO',
    @Detalle = @dv;

-- Venta 2: CONFIRMADA y luego ANULADA. Vendedor 2.
DELETE FROM @dv;
INSERT INTO @dv (IdVariante, Cantidad, PrecioUnitario, Descuento) VALUES
    (2, 1, 18000.00, 0),
    (8, 2, 15000.00, 0);

EXEC dbo.SP_RegistrarVenta
    @IdCliente = 2,
    @IdUsuario = 3,
    @MedioPago = 'DEBITO',
    @Detalle = @dv;

EXEC dbo.SP_AnularVenta @IdVenta = 2, @IdUsuario = 1;

-- Venta 3: CONFIRMADA, consumidor final. Vendedor 1.
-- La venta de 2 unidades de la variante 10 cruza el mínimo y genera alerta.
DELETE FROM @dv;
INSERT INTO @dv (IdVariante, Cantidad, PrecioUnitario, Descuento) VALUES
    (6, 1, 27000.00, 0),
    (10, 2, 48000.00, 0);

EXEC dbo.SP_RegistrarVenta
    @IdCliente = NULL,
    @IdUsuario = 2,
    @MedioPago = 'TRANSFERENCIA',
    @Detalle = @dv;

-- Venta 4: CONFIRMADA y luego ANULADA. Vendedor 2.
DELETE FROM @dv;
INSERT INTO @dv (IdVariante, Cantidad, PrecioUnitario, Descuento) VALUES
    (9, 1, 15000.00, 0);

EXEC dbo.SP_RegistrarVenta
    @IdCliente = 3,
    @IdUsuario = 3,
    @MedioPago = 'CREDITO',
    @Detalle = @dv;

EXEC dbo.SP_AnularVenta @IdVenta = 4, @IdUsuario = 1;

-- ============================================================
-- 7. AJUSTES DE STOCK
-- ============================================================
-- Ajuste real: la variante 1 pasa de 18 a 17 (movimiento AJUSTE -1).
EXEC dbo.SP_AjustarStock
    @IdVariante = 1,
    @NuevaCantidad = 17,
    @IdUsuario = 1,
    @Observacion = 'Ajuste por recuento físico';

-- Caso borde: ajuste sin diferencia. No debe generar movimiento.
SELECT @StockActual = StockActual FROM dbo.VarianteProducto WHERE IdVariante = 1;

EXEC dbo.SP_AjustarStock
    @IdVariante = 1,
    @NuevaCantidad = @StockActual,
    @IdUsuario = 1,
    @Observacion = 'Prueba de ajuste sin diferencia';

-- ============================================================
-- 8. CASOS BORDE / PRUEBAS DE ERROR
-- Los errores se capturan para que el seed pueda terminar.
-- ============================================================

-- 8.1 Venta sin stock: variante 3 tiene stock 0.
INSERT INTO @dvSinStock (IdVariante, Cantidad, PrecioUnitario, Descuento) VALUES
    (3, 1, 18000.00, 0);

BEGIN TRY
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1,
        @IdUsuario = 2,
        @MedioPago = 'EFECTIVO',
        @Detalle = @dvSinStock;

    SELECT 'VENTA_SIN_STOCK' AS Caso, 'ERROR: la venta no debió registrarse' AS Resultado;
END TRY
BEGIN CATCH
    SELECT 'VENTA_SIN_STOCK' AS Caso, ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- 8.2 Compra sin líneas: TVP vacío.
BEGIN TRY
    EXEC dbo.SP_RegistrarCompra
        @IdProveedor = 1,
        @IdUsuario = 1,
        @NroComprobante = 'TEST-SIN-DETALLE',
        @Detalle = @dcVacio;

    SELECT 'COMPRA_SIN_DETALLE' AS Caso, 'ERROR: la compra no debió registrarse' AS Resultado;
END TRY
BEGIN CATCH
    SELECT 'COMPRA_SIN_DETALLE' AS Caso, ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- 8.3 Recepción de compra sin líneas: cabecera PENDIENTE sin detalle.
INSERT INTO dbo.Compra
    (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
VALUES
    (4, 1, 1, GETDATE(), 'TEST-RECEPCION-SIN-LINEAS', 0, 'PENDIENTE');

BEGIN TRY
    EXEC dbo.SP_RecibirCompra @IdCompra = 4, @IdUsuario = 1;
    SELECT 'RECEPCION_SIN_LINEAS' AS Caso, 'ERROR: la compra no debió recibirse' AS Resultado;
END TRY
BEGIN CATCH
    SELECT 'RECEPCION_SIN_LINEAS' AS Caso, ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- Dejar la compra de prueba en un estado válido y sin stock asociado.
UPDATE dbo.Compra
SET Estado = 'ANULADA'
WHERE IdCompra = 4;

-- 8.4 Anulación duplicada: la venta 2 ya está ANULADA.
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 2, @IdUsuario = 1;
    SELECT 'ANULACION_DUPLICADA' AS Caso, 'ERROR: la venta no debió anularse dos veces' AS Resultado;
END TRY
BEGIN CATCH
    SELECT 'ANULACION_DUPLICADA' AS Caso, ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- 8.5 Anulación por Vendedor: la venta 3 sigue CONFIRMADA.
BEGIN TRY
    EXEC dbo.SP_AnularVenta @IdVenta = 3, @IdUsuario = 2;
    SELECT 'ANULACION_POR_VENDEDOR' AS Caso, 'ERROR: un vendedor no debió anular' AS Resultado;
END TRY
BEGIN CATCH
    SELECT 'ANULACION_POR_VENDEDOR' AS Caso, ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- ============================================================
-- 9. RESUMEN DEL SEED
-- ============================================================
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
