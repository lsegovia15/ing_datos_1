USE SIAM;
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM dbo.Rol)
BEGIN
    PRINT 'Seed ya aplicado: la tabla Rol contiene datos. No se vuelve a ejecutar.';
    RETURN;
END;


-- 1. ROLES Y USUARIOS DE APLICACIÓN

INSERT INTO dbo.Rol (IdRol, Nombre, Descripcion) VALUES
    (1, 'Administrador', 'Acceso total: catálogo, compras, stock, ventas, anulaciones y seguridad.'),
    (2, 'Vendedor',      'Registra ventas y consulta catálogo, stock y reportes de reposición.');

INSERT INTO dbo.Usuario
    (IdUsuario, IdRol, NombreUsuario, Email, Contrasena, Nombre, Apellido, Activo)
VALUES
    -- Las contraseñas no se guardan en texto plano: se guarda su hash
    -- SHA-256 en hexadecimal (64 caracteres). HASHBYTES calcula el hash y
    -- CONVERT(..., 2) lo pasa a texto. Para validar un ingreso se calcula
    -- el hash de lo que escribe el usuario y se compara con el guardado.
    (1, 1, 'admin',             'admin@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Admin123!'), 2),    'Ana',   'Administradora', 1),
    (2, 2, 'vendedor1',         'vendedor1@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Vendedor123!'), 2), 'Bruno', 'Vendedor',       1),
    (3, 2, 'vendedor2',         'vendedor2@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Vendedor123!'), 2), 'Carla', 'Vendedora',      1),
    (4, 2, 'vendedor_inactivo', 'inactivo@siam.local',
        CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'Inactivo123!'), 2), 'Diego', 'Inactivo',       0);


-- 2. CATÁLOGOS

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


-- 3. PRODUCTOS Y VARIANTES
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


-- 4. PROVEEDORES Y CLIENTES

INSERT INTO dbo.Proveedor (IdProveedor, RazonSocial, CUIT, Telefono, Email, Direccion) VALUES
    (1, 'Distribuidora Norte S.A.', '30-71234567-8', '011-4555-1001', 'ventas@norte.com', 'Av. Cabildo 1234'),
    (2, 'Textil Sur S.R.L.',        '30-70987654-3', '011-4555-1002', 'pedidos@textilsur.com', 'San Juan 456'),
    (3, 'Importadora Centro',       '30-70111222-9', '011-4555-1003', 'compras@centro.com', 'Rivadavia 789');

INSERT INTO dbo.Cliente (IdCliente, Nombre, Apellido, DNI, Telefono, Email, Direccion) VALUES
    (1, 'Lucía',  'Gómez',    '30111222', '11-5555-2001', 'lucia.gomez@mail.com',  'Palermo 111'),
    (2, 'Martín', 'Pérez',    '28999888', '11-5555-2002', 'martin.perez@mail.com', 'Belgrano 222'),
    (3, 'Sofía',  'Rodríguez','33444555', '11-5555-2003', 'sofia.rodriguez@mail.com','Caballito 333');


-- 5. COMPRAS (un producto por compra)

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


-- 6. VENTAS (un producto por venta)

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


-- 7. AJUSTES DE STOCK

-- Ajuste real: la variante 1 pasa de 23 a 22 (movimiento AJUSTE -1).
EXEC dbo.SP_AjustarStock
    @IdVariante = 1, @NuevaCantidad = 22, @IdUsuario = 1,
    @Observacion = 'Ajuste por recuento físico';

-- Ajuste sin diferencia: no genera movimiento.
EXEC dbo.SP_AjustarStock
    @IdVariante = 1, @NuevaCantidad = 22, @IdUsuario = 1,
    @Observacion = 'Prueba de ajuste sin diferencia';


-- 8. CASOS DE ERROR
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
    -- El error viene de un trigger: se revierte la operación si quedó abierta.
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
    -- El error viene de un trigger: se revierte la operación si quedó abierta.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    SELECT '8.11 REACTIVAR_VENTA' AS Caso, ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;


-- 9. RESUMEN DEL SEED

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
