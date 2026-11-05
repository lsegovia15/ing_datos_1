/* ============================================================
   SIAM - Suite de pruebas del motor
   ------------------------------------------------------------
   Prueba:
     - Existencia de tablas, vistas, funciones, SPs, triggers,
       tipos TVP, logins, usuarios y roles.
     - Funciones escalares y table-valued.
     - Vistas de negocio.
     - Los 6 stored procedures (casos exitosos y de error).
     - El cursor SP_InformeReposicionStock.
     - Los 8 triggers.
     - La seguridad (catálogo de permisos y pruebas con
       EXECUTE AS USER).
     - Integridad de totales y constraints.

   Requisitos:
     - Haber ejecutado sql/00_master.sql (o el master de la
       rama con el diseño final: TVP + 8 triggers + DENY).
     - Ejecutarse como sysadmin (para poder hacer EXECUTE AS USER).

   Uso con SQLCMD:
     sqlcmd -S localhost -E -C -b -f 65001 -i 99_test_siam.sql

   Uso en SSMS:
     Abrir este archivo y ejecutarlo completo con F5.

   IMPORTANTE:
   - Las pruebas que modifican datos abren una transacción y
     terminan con ROLLBACK. No dejan cambios permanentes.
   - Si alguna prueba falla, al final se lanza un THROW 59000.
     Con sqlcmd -b eso devuelve código de salida distinto de 0.
   ============================================================ */

USE SIAM;
GO

SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO

IF DB_NAME() <> N'SIAM'
BEGIN
    THROW 59001, 'Este script debe ejecutarse sobre la base SIAM.', 1;
END;
GO

/* ------------------------------------------------------------
   0. INFRAESTRUCTURA DE RESULTADOS
   ------------------------------------------------------------ */

IF OBJECT_ID('tempdb..#Resultados') IS NOT NULL DROP TABLE #Resultados;

CREATE TABLE #Resultados
(
    IdResultado INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Bloque      VARCHAR(60)  NOT NULL,
    Caso        VARCHAR(180) NOT NULL,
    Esperado    VARCHAR(300) NULL,
    Obtenido    VARCHAR(700) NULL,
    Estado      VARCHAR(10)  NOT NULL
);
GO

/* ------------------------------------------------------------
   1. INVENTARIO DE OBJETOS
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Tabla dbo.' + v.Nombre,
    'Existe',
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'U') IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'U') IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES
    ('Rol'), ('Usuario'), ('Categoria'), ('Segmento'), ('Marca'),
    ('Talle'), ('Color'), ('Producto'), ('VarianteProducto'),
    ('Proveedor'), ('Compra'), ('DetalleCompra'), ('Cliente'),
    ('Venta'), ('DetalleVenta'), ('MovimientoStock'),
    ('AlertaStock'), ('HistorialPrecio')
) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Vista dbo.' + v.Nombre,
    'Existe',
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'V') IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'V') IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES
    ('vw_StockVariante'),
    ('vw_VentasDetalladas'),
    ('vw_ProductosPremium'),
    ('vw_CategoriasMasVendidasPorSegmento')
) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Función dbo.' + v.Nombre,
    'Existe',
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'FN') IS NOT NULL
              OR OBJECT_ID(N'dbo.' + v.Nombre, N'IF') IS NOT NULL
              OR OBJECT_ID(N'dbo.' + v.Nombre, N'TF') IS NOT NULL
         THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'FN') IS NOT NULL
              OR OBJECT_ID(N'dbo.' + v.Nombre, N'IF') IS NOT NULL
              OR OBJECT_ID(N'dbo.' + v.Nombre, N'TF') IS NOT NULL
         THEN 'OK' ELSE 'FALLA' END
FROM (VALUES
    ('fn_EstadoStock'),
    ('fn_ResumenVentasPorUsuario')
) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'SP dbo.' + v.Nombre,
    'Existe',
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'P') IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'P') IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES
    ('SP_RegistrarVenta'),
    ('SP_AnularVenta'),
    ('SP_AjustarStock'),
    ('SP_RegistrarCompra'),
    ('SP_RecibirCompra'),
    ('SP_InformeReposicionStock')
) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Trigger dbo.' + v.Nombre,
    'Existe y está habilitado',
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'TR') IS NULL THEN 'No existe'
         WHEN EXISTS (SELECT 1 FROM sys.triggers t WHERE t.object_id = OBJECT_ID(N'dbo.' + v.Nombre, N'TR') AND t.is_disabled = 1) THEN 'Deshabilitado'
         ELSE 'Existe y habilitado' END,
    CASE WHEN OBJECT_ID(N'dbo.' + v.Nombre, N'TR') IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM sys.triggers t WHERE t.object_id = OBJECT_ID(N'dbo.' + v.Nombre, N'TR') AND t.is_disabled = 1)
         THEN 'OK' ELSE 'FALLA' END
FROM (VALUES
    ('TR_DescontarStockVenta'),
    ('TR_CalcularTotalVenta'),
    ('TR_DevolverStockAnulacion'),
    ('TR_SumarStockCompra'),
    ('TR_AvisoStockMinimo'),
    ('TR_HistorialPrecio'),
    ('TR_NoBorrarVenta'),
    ('TR_AplicarAjusteStock')
) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Tipo TVP dbo.' + v.Nombre,
    'Existe',
    CASE WHEN TYPE_ID(N'dbo.' + v.Nombre) IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN TYPE_ID(N'dbo.' + v.Nombre) IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES ('TipoDetalleVenta'), ('TipoDetalleCompra')) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Login ' + v.Nombre,
    'Existe',
    CASE WHEN SUSER_ID(v.Nombre) IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN SUSER_ID(v.Nombre) IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES ('login_admin_siam'), ('login_vendedor_siam')) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Usuario de base ' + v.Nombre,
    'Existe',
    CASE WHEN DATABASE_PRINCIPAL_ID(v.Nombre) IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN DATABASE_PRINCIPAL_ID(v.Nombre) IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES ('usr_admin'), ('usr_vendedor')) AS v(Nombre);

INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
SELECT
    '00. Inventario',
    'Rol de base ' + v.Nombre,
    'Existe',
    CASE WHEN DATABASE_PRINCIPAL_ID(v.Nombre) IS NOT NULL THEN 'Existe' ELSE 'No existe' END,
    CASE WHEN DATABASE_PRINCIPAL_ID(v.Nombre) IS NOT NULL THEN 'OK' ELSE 'FALLA' END
FROM (VALUES ('rol_administrador'), ('rol_vendedor')) AS v(Nombre);

-- Si faltan objetos críticos, no tiene sentido seguir: se avisa y se corta.
IF EXISTS (
    SELECT 1
    FROM #Resultados
    WHERE Bloque = '00. Inventario'
      AND Estado = 'FALLA'
)
BEGIN
    SELECT Bloque, Caso, Esperado, Obtenido, Estado
    FROM #Resultados
    WHERE Bloque = '00. Inventario'
      AND Estado = 'FALLA';

    THROW 59002, 'Faltan objetos del motor SIAM. Ejecute primero sql/00_master.sql (rama con TVP + 8 triggers + seguridad).', 1;
END;
GO

/* ------------------------------------------------------------
   2. FUNCIONES
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @vSuficiente INT, @vBajo INT, @vCero INT;
DECLARE @estado VARCHAR(20);
DECLARE @desde DATE, @hasta DATE;
DECLARE @cantFunc INT, @cantBase INT;
DECLARE @totFunc DECIMAL(18,2), @totBase DECIMAL(18,2);
DECLARE @e INT, @m NVARCHAR(4000);

SELECT TOP 1 @vSuficiente = v.IdVariante
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > v.StockMinimo
ORDER BY v.IdVariante;

SELECT TOP 1 @vBajo = v.IdVariante
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > 0 AND v.StockActual <= v.StockMinimo
ORDER BY v.IdVariante;

SELECT TOP 1 @vCero = v.IdVariante
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual = 0
ORDER BY v.IdVariante;

-- 2.1 fn_EstadoStock: INACTIVO
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.Producto
    SET Activo = 0
    WHERE IdProducto = (SELECT IdProducto FROM dbo.VarianteProducto WHERE IdVariante = @vSuficiente);

    SELECT @estado = dbo.fn_EstadoStock(@vSuficiente);

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con producto inactivo', 180), LEFT('INACTIVO', 300), LEFT(@estado, 700),
        CASE WHEN (CASE WHEN @estado = 'INACTIVO' THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con producto inactivo', 180), LEFT('INACTIVO', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 2.2 fn_EstadoStock: SIN STOCK
BEGIN TRY
    SELECT @estado = dbo.fn_EstadoStock(@vCero);
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con stock cero', 180), LEFT('SIN STOCK', 300), LEFT(ISNULL(@estado, 'NULL'), 700),
        CASE WHEN (CASE WHEN @estado = 'SIN STOCK' THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con stock cero', 180), LEFT('SIN STOCK', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 2.3 fn_EstadoStock: BAJO STOCK
BEGIN TRY
    SELECT @estado = dbo.fn_EstadoStock(@vBajo);
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con stock bajo', 180), LEFT('BAJO STOCK', 300), LEFT(ISNULL(@estado, 'NULL'), 700),
        CASE WHEN (CASE WHEN @estado = 'BAJO STOCK' THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con stock bajo', 180), LEFT('BAJO STOCK', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 2.4 fn_EstadoStock: STOCK SUFICIENTE
BEGIN TRY
    SELECT @estado = dbo.fn_EstadoStock(@vSuficiente);
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con stock suficiente', 180), LEFT('STOCK SUFICIENTE', 300), LEFT(ISNULL(@estado, 'NULL'), 700),
        CASE WHEN (CASE WHEN @estado = 'STOCK SUFICIENTE' THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con stock suficiente', 180), LEFT('STOCK SUFICIENTE', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 2.5 fn_EstadoStock: variante inexistente
BEGIN TRY
    SELECT @estado = dbo.fn_EstadoStock(999999);
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con variante inexistente', 180), LEFT('NULL', 300), LEFT(ISNULL(@estado, 'NULL'), 700),
        CASE WHEN (CASE WHEN @estado IS NULL THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_EstadoStock con variante inexistente', 180), LEFT('NULL', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 2.6 fn_ResumenVentasPorUsuario: comparación contra consulta directa
BEGIN TRY
    SET @desde = '2000-01-01';
    SET @hasta = '2100-12-31';

    SELECT @cantFunc = COUNT(*), @totFunc = ISNULL(SUM(TotalVendido), 0)
    FROM dbo.fn_ResumenVentasPorUsuario(@desde, @hasta);

    SELECT @cantBase = COUNT(*), @totBase = ISNULL(SUM(Total), 0)
    FROM (
        SELECT v.IdUsuario, SUM(v.Total) AS Total
        FROM dbo.Venta v
        WHERE v.Estado = 'CONFIRMADA'
          AND v.Fecha >= @desde
          AND v.Fecha < DATEADD(DAY, 1, @hasta)
        GROUP BY v.IdUsuario
    ) AS x;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_ResumenVentasPorUsuario cantidades y totales', 180), LEFT(CONCAT('filas=', @cantBase, ', total=', @totBase), 300), LEFT(CONCAT('filas=', @cantFunc, ', total=', @totFunc), 700),
        CASE WHEN (CASE WHEN @cantFunc = @cantBase AND @totFunc = @totBase THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_ResumenVentasPorUsuario cantidades y totales', 180), LEFT('Igual a la consulta directa', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 2.7 fn_ResumenVentasPorUsuario: período sin ventas
BEGIN TRY
    SELECT @cantFunc = COUNT(*)
    FROM dbo.fn_ResumenVentasPorUsuario('1900-01-01', '1900-01-02');

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_ResumenVentasPorUsuario período vacío', 180), LEFT('0 filas', 300), LEFT(CAST(@cantFunc AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @cantFunc = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('01. Funciones', 60), LEFT('fn_ResumenVentasPorUsuario período vacío', 180), LEFT('0 filas', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   3. VISTAS
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @n INT, @nBase INT, @e INT, @m NVARCHAR(4000);

-- 3.1 vw_StockVariante
BEGIN TRY
    SELECT @n = COUNT(*) FROM dbo.vw_StockVariante;
    SELECT @nBase = COUNT(*)
    FROM dbo.VarianteProducto v
    INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
    WHERE p.Activo = 1;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_StockVariante filas de productos activos', 180), LEFT(CAST(@nBase AS VARCHAR(20)), 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = @nBase THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_StockVariante filas de productos activos', 180), LEFT('Consulta sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 3.2 vw_VentasDetalladas
BEGIN TRY
    SELECT @n = COUNT(*) FROM dbo.vw_VentasDetalladas;
    SELECT @nBase = COUNT(*) FROM dbo.Venta;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_VentasDetalladas incluye todas las ventas', 180), LEFT(CAST(@nBase AS VARCHAR(20)), 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = @nBase THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_VentasDetalladas incluye todas las ventas', 180), LEFT('Consulta sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 3.3 vw_ProductosPremium
BEGIN TRY
    SELECT @n = COUNT(*) FROM dbo.vw_ProductosPremium;

    SELECT @nBase = COUNT(*)
    FROM dbo.Producto p
    WHERE p.Activo = 1
      AND p.PrecioBase > (SELECT AVG(p2.PrecioBase) FROM dbo.Producto p2 WHERE p2.Activo = 1);

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_ProductosPremium sobre el promedio', 180), LEFT(CAST(@nBase AS VARCHAR(20)), 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = @nBase THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_ProductosPremium sobre el promedio', 180), LEFT('Consulta sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 3.4 vw_CategoriasMasVendidasPorSegmento
BEGIN TRY
    SELECT @n = COUNT(*) FROM dbo.vw_CategoriasMasVendidasPorSegmento;

    IF EXISTS (SELECT 1 FROM dbo.vw_CategoriasMasVendidasPorSegmento WHERE Posicion <> 1)
        THROW 59010, 'La vista devolvió una posición distinta de 1.', 1;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_CategoriasMasVendidasPorSegmento ejecuta y marca Posicion=1', 180), LEFT('Consulta sin error y Posicion=1', 300), LEFT(CONCAT('filas=', @n), 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('02. Vistas', 60), LEFT('vw_CategoriasMasVendidasPorSegmento ejecuta y marca Posicion=1', 180), LEFT('Consulta sin error y Posicion=1', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   4. SP_RegistrarVenta
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @v1 INT, @v2 INT, @vCero INT;
DECLARE @p1 DECIMAL(12,2), @p2 DECIMAL(12,2);
DECLARE @stock1 INT, @stock2 INT, @s1Despues INT, @s2Despues INT;
DECLARE @idVenta INT, @total DECIMAL(12,2), @esperado DECIMAL(12,2);
DECLARE @d dbo.TipoDetalleVenta;
DECLARE @e INT, @m NVARCHAR(4000), @ok BIT, @n INT;

SELECT TOP 1 @v1 = v.IdVariante, @p1 = v.PrecioVenta
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > v.StockMinimo
ORDER BY v.IdVariante;

SELECT TOP 1 @v2 = v.IdVariante, @p2 = v.PrecioVenta
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > 0 AND v.StockActual <= v.StockMinimo
  AND v.IdVariante <> @v1
ORDER BY v.IdVariante;

SELECT TOP 1 @vCero = v.IdVariante
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual = 0
ORDER BY v.IdVariante;

-- 4.1 Venta exitosa con dos líneas y descuento
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stock1 = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v1;
    SELECT @stock2 = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v2;

    DELETE FROM @d;
    INSERT INTO @d (IdVariante, Cantidad, PrecioUnitario, Descuento)
    VALUES (@v1, 2, @p1, 1000.00),
           (@v2, 1, @p2, 0.00);

    SET @esperado = (2 * @p1 - 1000.00) + @p2;

    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1,
        @IdUsuario = 2,
        @MedioPago = 'EFECTIVO',
        @Detalle = @d;

    SELECT @idVenta = MAX(IdVenta) FROM dbo.Venta;
    SELECT @total = Total FROM dbo.Venta WHERE IdVenta = @idVenta;
    SELECT @s1Despues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v1;
    SELECT @s2Despues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v2;

    SET @ok = CASE
        WHEN @total = @esperado
         AND @s1Despues = @stock1 - 2
         AND @s2Despues = @stock2 - 1
         AND (SELECT COUNT(*) FROM dbo.DetalleVenta WHERE IdVenta = @idVenta) = 2
        THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Venta exitosa con 2 líneas y descuento', 180), LEFT(CONCAT('Total=', @esperado, ', stock=', @stock1 - 2, '/', @stock2 - 1), 300), LEFT(CONCAT('Total=', @total, ', stock=', @s1Despues, '/', @s2Despues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Venta exitosa con 2 líneas y descuento', 180), LEFT('Venta registrada', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.2 Detalle vacío -> 50001
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @d;
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @Detalle = @d;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza detalle vacío', 180), LEFT('error 50001', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza detalle vacío', 180), LEFT('error 50001', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50001 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.3 Usuario inactivo -> 50002
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @d;
    INSERT INTO @d VALUES (@v1, 1, @p1, 0);
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 4, @MedioPago = 'EFECTIVO', @Detalle = @d;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50002', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50002', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50002 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.4 Cliente inexistente -> 50003
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @d;
    INSERT INTO @d VALUES (@v1, 1, @p1, 0);
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 999999, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @Detalle = @d;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza cliente inexistente', 180), LEFT('error 50003', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza cliente inexistente', 180), LEFT('error 50003', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50003 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.5 Variante repetida -> 50004
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @d;
    INSERT INTO @d VALUES (@v1, 1, @p1, 0), (@v1, 1, @p1, 0);
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @Detalle = @d;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza variante repetida', 180), LEFT('error 50004', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza variante repetida', 180), LEFT('error 50004', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50004 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.6 Variante inexistente -> 50005
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @d;
    INSERT INTO @d VALUES (999999, 1, 100.00, 0);
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @Detalle = @d;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza variante inexistente', 180), LEFT('error 50005', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza variante inexistente', 180), LEFT('error 50005', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50005 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.7 Stock insuficiente -> 50006
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @d;
    INSERT INTO @d VALUES (@vCero, 1, 100.00, 0);
    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @Detalle = @d;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza venta sin stock', 180), LEFT('error 50006', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza venta sin stock', 180), LEFT('error 50006', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50006 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 4.8 Usuario con rol no autorizado -> 50007
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Rol (IdRol, Nombre, Descripcion)
    VALUES (999, 'RolTest', 'Rol temporal para prueba');

    INSERT INTO dbo.Usuario
        (IdUsuario, IdRol, NombreUsuario, Email, Contrasena, Nombre, Apellido, Activo)
    VALUES
        (999, 999, 'usuario_rol_test', 'rol_test@siam.local', 'x', 'Test', 'Rol', 1);

    DELETE FROM @d;
    INSERT INTO @d VALUES (@v1, 1, @p1, 0);

    EXEC dbo.SP_RegistrarVenta
        @IdCliente = 1, @IdUsuario = 999, @MedioPago = 'EFECTIVO', @Detalle = @d;

    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza rol no autorizado', 180), LEFT('error 50007', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('03. SP_RegistrarVenta', 60), LEFT('Rechaza rol no autorizado', 180), LEFT('error 50007', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50007 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   5. SP_AnularVenta
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @v INT, @p DECIMAL(12,2);
DECLARE @stockAntes INT, @stockDespuesVenta INT, @stockDespuesAnul INT;
DECLARE @idVenta INT, @estado VARCHAR(20);
DECLARE @idVentaAnulada INT;
DECLARE @d dbo.TipoDetalleVenta;
DECLARE @e INT, @m NVARCHAR(4000), @ok BIT;

SELECT TOP 1 @v = v.IdVariante, @p = v.PrecioVenta
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > v.StockMinimo
ORDER BY v.IdVariante;

SELECT TOP 1 @idVentaAnulada = IdVenta
FROM dbo.Venta
WHERE Estado = 'ANULADA'
ORDER BY IdVenta;

-- 5.1 Anulación exitosa: devuelve el stock
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stockAntes = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    DELETE FROM @d;
    INSERT INTO @d VALUES (@v, 1, @p, 0);

    EXEC dbo.SP_RegistrarVenta
        @IdCliente = NULL, @IdUsuario = 2, @MedioPago = 'EFECTIVO', @Detalle = @d;

    SELECT @idVenta = MAX(IdVenta) FROM dbo.Venta;
    SELECT @stockDespuesVenta = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    EXEC dbo.SP_AnularVenta @IdVenta = @idVenta, @IdUsuario = 1;

    SELECT @stockDespuesAnul = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @estado = Estado FROM dbo.Venta WHERE IdVenta = @idVenta;

    SET @ok = CASE
        WHEN @stockDespuesVenta = @stockAntes - 1
         AND @stockDespuesAnul = @stockAntes
         AND @estado = 'ANULADA'
        THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Anulación exitosa devuelve stock', 180), LEFT(CONCAT('Venta ANULADA y stock=', @stockAntes), 300), LEFT(CONCAT('Estado=', @estado, ', stock=', @stockDespuesAnul), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Anulación exitosa devuelve stock', 180), LEFT('Venta ANULADA y stock restaurado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 5.2 Usuario inexistente -> 50012
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 999999;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza usuario inexistente', 180), LEFT('error 50012', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza usuario inexistente', 180), LEFT('error 50012', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50012 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 5.3 Usuario inactivo -> 50013
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 4;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50013', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50013', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50013 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 5.4 Vendedor -> 50013
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 2;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza anulación por vendedor', 180), LEFT('error 50013', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza anulación por vendedor', 180), LEFT('error 50013', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50013 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 5.5 Venta inexistente -> 50010
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AnularVenta @IdVenta = 999999, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza venta inexistente', 180), LEFT('error 50010', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza venta inexistente', 180), LEFT('error 50010', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50010 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 5.6 Venta ya anulada -> 50011
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AnularVenta @IdVenta = @idVentaAnulada, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza venta ya anulada', 180), LEFT('error 50011', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('04. SP_AnularVenta', 60), LEFT('Rechaza venta ya anulada', 180), LEFT('error 50011', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50011 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   6. SP_AjustarStock
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @v INT;
DECLARE @stock INT, @nueva INT, @stockDespues INT;
DECLARE @movAntes INT, @movDespues INT;
DECLARE @e INT, @m NVARCHAR(4000), @ok BIT;

SELECT TOP 1 @v = v.IdVariante
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > 2
ORDER BY v.IdVariante;

-- 6.1 Ajuste negativo exitoso
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @movAntes = COUNT(*) FROM dbo.MovimientoStock WHERE IdVariante = @v;
    SET @nueva = @stock - 2;

    EXEC dbo.SP_AjustarStock
        @IdVariante = @v, @NuevaCantidad = @nueva, @IdUsuario = 1,
        @Observacion = 'Test suite: ajuste negativo';

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @movDespues = COUNT(*) FROM dbo.MovimientoStock WHERE IdVariante = @v;

    SET @ok = CASE WHEN @stockDespues = @nueva AND @movDespues = @movAntes + 1 THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Ajuste negativo aplica stock y registra movimiento', 180), LEFT(CONCAT('Stock=', @nueva, ', movimientos=', @movAntes + 1), 300), LEFT(CONCAT('Stock=', @stockDespues, ', movimientos=', @movDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Ajuste negativo aplica stock y registra movimiento', 180), LEFT('Ajuste aplicado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.2 Ajuste positivo exitoso
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @movAntes = COUNT(*) FROM dbo.MovimientoStock WHERE IdVariante = @v;
    SET @nueva = @stock + 3;

    EXEC dbo.SP_AjustarStock
        @IdVariante = @v, @NuevaCantidad = @nueva, @IdUsuario = 1,
        @Observacion = 'Test suite: ajuste positivo';

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @movDespues = COUNT(*) FROM dbo.MovimientoStock WHERE IdVariante = @v;

    SET @ok = CASE WHEN @stockDespues = @nueva AND @movDespues = @movAntes + 1 THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Ajuste positivo aplica stock y registra movimiento', 180), LEFT(CONCAT('Stock=', @nueva, ', movimientos=', @movAntes + 1), 300), LEFT(CONCAT('Stock=', @stockDespues, ', movimientos=', @movDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Ajuste positivo aplica stock y registra movimiento', 180), LEFT('Ajuste aplicado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.3 Ajuste sin diferencia: no genera movimiento
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @movAntes = COUNT(*) FROM dbo.MovimientoStock WHERE IdVariante = @v;

    EXEC dbo.SP_AjustarStock
        @IdVariante = @v, @NuevaCantidad = @stock, @IdUsuario = 1,
        @Observacion = 'Test suite: sin diferencia';

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @movDespues = COUNT(*) FROM dbo.MovimientoStock WHERE IdVariante = @v;

    SET @ok = CASE WHEN @stockDespues = @stock AND @movDespues = @movAntes THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Ajuste sin diferencia no registra movimiento', 180), LEFT(CONCAT('Stock=', @stock, ', movimientos=', @movAntes), 300), LEFT(CONCAT('Stock=', @stockDespues, ', movimientos=', @movDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Ajuste sin diferencia no registra movimiento', 180), LEFT('Sin cambios', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.4 Cantidad negativa -> 50020
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AjustarStock @IdVariante = @v, @NuevaCantidad = -1, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza cantidad negativa', 180), LEFT('error 50020', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza cantidad negativa', 180), LEFT('error 50020', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50020 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.5 Usuario inexistente -> 50021
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AjustarStock @IdVariante = @v, @NuevaCantidad = 1, @IdUsuario = 999999;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza usuario inexistente', 180), LEFT('error 50021', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza usuario inexistente', 180), LEFT('error 50021', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50021 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.6 Usuario inactivo -> 50021
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AjustarStock @IdVariante = @v, @NuevaCantidad = 1, @IdUsuario = 4;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50021', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50021', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50021 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.7 Vendedor -> 50023
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AjustarStock @IdVariante = @v, @NuevaCantidad = 1, @IdUsuario = 2;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza ajuste por vendedor', 180), LEFT('error 50023', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza ajuste por vendedor', 180), LEFT('error 50023', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50023 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 6.8 Variante inexistente -> 50022
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_AjustarStock @IdVariante = 999999, @NuevaCantidad = 1, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza variante inexistente', 180), LEFT('error 50022', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('05. SP_AjustarStock', 60), LEFT('Rechaza variante inexistente', 180), LEFT('error 50022', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50022 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   7. SP_RegistrarCompra
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @v1 INT, @v2 INT;
DECLARE @stock1 INT, @stock1Despues INT;
DECLARE @idCompra INT, @total DECIMAL(12,2), @estado VARCHAR(20), @lineas INT;
DECLARE @dc dbo.TipoDetalleCompra;
DECLARE @e INT, @m NVARCHAR(4000), @ok BIT;

SELECT TOP 1 @v1 = IdVariante FROM dbo.VarianteProducto ORDER BY IdVariante;
SELECT TOP 1 @v2 = IdVariante FROM dbo.VarianteProducto WHERE IdVariante <> @v1 ORDER BY IdVariante;

-- 7.1 Compra exitosa con dos líneas
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stock1 = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v1;

    DELETE FROM @dc;
    INSERT INTO @dc (IdVariante, Cantidad, CostoUnitario)
    VALUES (@v1, 3, 1000.00), (@v2, 2, 2000.00);

    EXEC dbo.SP_RegistrarCompra
        @IdProveedor = 1,
        @IdUsuario = 1,
        @NroComprobante = 'TEST-SUITE-COMPRA',
        @Detalle = @dc;

    SELECT @idCompra = MAX(IdCompra) FROM dbo.Compra;
    SELECT @total = Total, @estado = Estado FROM dbo.Compra WHERE IdCompra = @idCompra;
    SELECT @lineas = COUNT(*) FROM dbo.DetalleCompra WHERE IdCompra = @idCompra;
    SELECT @stock1Despues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v1;

    SET @ok = CASE
        WHEN @total = 7000.00
         AND @estado = 'PENDIENTE'
         AND @lineas = 2
         AND @stock1Despues = @stock1
        THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Compra exitosa con 2 líneas', 180), LEFT('Total=7000, PENDIENTE, 2 líneas, stock sin cambios', 300), LEFT(CONCAT('Total=', @total, ', Estado=', @estado, ', líneas=', @lineas, ', stock=', @stock1Despues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Compra exitosa con 2 líneas', 180), LEFT('Compra PENDIENTE', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.2 Detalle vacío -> 50100
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza detalle vacío', 180), LEFT('error 50100', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza detalle vacío', 180), LEFT('error 50100', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50100 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.3 Proveedor inexistente -> 50101
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v1, 1, 100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 999999, @IdUsuario = 1, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza proveedor inexistente', 180), LEFT('error 50101', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza proveedor inexistente', 180), LEFT('error 50101', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50101 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.4 Usuario inactivo -> 50102
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v1, 1, 100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 4, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50102', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50102', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50102 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.5 Vendedor -> 50107
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v1, 1, 100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 2, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza compra por vendedor', 180), LEFT('error 50107', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza compra por vendedor', 180), LEFT('error 50107', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50107 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.6 Variante repetida -> 50103
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v1, 1, 100.00), (@v1, 2, 100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza variante repetida', 180), LEFT('error 50103', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza variante repetida', 180), LEFT('error 50103', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50103 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.7 Cantidad <= 0 -> 50104
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v1, 0, 100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza cantidad cero', 180), LEFT('error 50104', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza cantidad cero', 180), LEFT('error 50104', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50104 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.8 Costo negativo -> 50105
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v1, 1, -100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza costo negativo', 180), LEFT('error 50105', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza costo negativo', 180), LEFT('error 50105', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50105 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 7.9 Variante inexistente -> 50106
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM @dc;
    INSERT INTO @dc VALUES (999999, 1, 100.00);
    EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @Detalle = @dc;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza variante inexistente', 180), LEFT('error 50106', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('06. SP_RegistrarCompra', 60), LEFT('Rechaza variante inexistente', 180), LEFT('error 50106', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50106 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   8. SP_RecibirCompra
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @v INT;
DECLARE @stock INT, @stockDespues INT;
DECLARE @idCompra INT, @idCompraRecibida INT, @idCompraAnulada INT;
DECLARE @estado VARCHAR(20), @lineas INT;
DECLARE @dc dbo.TipoDetalleCompra;
DECLARE @e INT, @m NVARCHAR(4000), @ok BIT;

SELECT TOP 1 @v = IdVariante FROM dbo.VarianteProducto ORDER BY IdVariante;

SELECT TOP 1 @idCompraRecibida = IdCompra
FROM dbo.Compra WHERE Estado = 'RECIBIDA' ORDER BY IdCompra;

SELECT TOP 1 @idCompraAnulada = IdCompra
FROM dbo.Compra WHERE Estado = 'ANULADA' ORDER BY IdCompra;

-- 8.1 Recepción exitosa: suma stock
BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM @dc;
    INSERT INTO @dc VALUES (@v, 4, 500.00);

    EXEC dbo.SP_RegistrarCompra
        @IdProveedor = 1, @IdUsuario = 1,
        @NroComprobante = 'TEST-SUITE-RECEPCION', @Detalle = @dc;

    SELECT @idCompra = MAX(IdCompra) FROM dbo.Compra;
    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    EXEC dbo.SP_RecibirCompra @IdCompra = @idCompra, @IdUsuario = 1;

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @estado = Estado FROM dbo.Compra WHERE IdCompra = @idCompra;

    SET @ok = CASE WHEN @estado = 'RECIBIDA' AND @stockDespues = @stock + 4 THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Recepción exitosa suma stock', 180), LEFT(CONCAT('Estado=RECIBIDA, stock=', @stock + 4), 300), LEFT(CONCAT('Estado=', @estado, ', stock=', @stockDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Recepción exitosa suma stock', 180), LEFT('Compra RECIBIDA y stock sumado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 8.2 Usuario inactivo -> 50113
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RecibirCompra @IdCompra = @idCompraRecibida, @IdUsuario = 4;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50113', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza usuario inactivo', 180), LEFT('error 50113', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50113 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 8.3 Vendedor -> 50114
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RecibirCompra @IdCompra = @idCompraRecibida, @IdUsuario = 2;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza recepción por vendedor', 180), LEFT('error 50114', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza recepción por vendedor', 180), LEFT('error 50114', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50114 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 8.4 Compra inexistente -> 50110
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RecibirCompra @IdCompra = 999999, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra inexistente', 180), LEFT('error 50110', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra inexistente', 180), LEFT('error 50110', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50110 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 8.5 Compra ya recibida -> 50112
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RecibirCompra @IdCompra = @idCompraRecibida, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra ya recibida', 180), LEFT('error 50112', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra ya recibida', 180), LEFT('error 50112', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50112 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 8.6 Compra anulada -> 50112
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.SP_RecibirCompra @IdCompra = @idCompraAnulada, @IdUsuario = 1;
    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra anulada', 180), LEFT('error 50112', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra anulada', 180), LEFT('error 50112', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50112 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 8.7 Compra sin líneas -> 50111
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Compra (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
    SELECT ISNULL(MAX(IdCompra), 0) + 1, 1, 1, GETDATE(), 'TEST-SUITE-SIN-LINEAS', 0, 'PENDIENTE'
    FROM dbo.Compra;

    SELECT @idCompra = MAX(IdCompra) FROM dbo.Compra;

    EXEC dbo.SP_RecibirCompra @IdCompra = @idCompra, @IdUsuario = 1;

    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra sin líneas', 180), LEFT('error 50111', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('07. SP_RecibirCompra', 60), LEFT('Rechaza compra sin líneas', 180), LEFT('error 50111', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 50111 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   9. SP_InformeReposicionStock (cursor)
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

BEGIN TRY
    IF OBJECT_ID('tempdb..#Reposicion') IS NOT NULL DROP TABLE #Reposicion;

    CREATE TABLE #Reposicion
    (
        IdVariante      INT,
        SKU             VARCHAR(30),
        Producto        VARCHAR(100),
        StockActual     INT,
        StockMinimo     INT,
        CantidadSugerida INT,
        Prioridad       VARCHAR(15)
    );

    INSERT INTO #Reposicion
    EXEC dbo.SP_InformeReposicionStock;

    DECLARE @n INT = (SELECT COUNT(*) FROM #Reposicion);
    DECLARE @nBase INT = (
        SELECT COUNT(*)
        FROM dbo.VarianteProducto v
        INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
        WHERE p.Activo = 1 AND v.StockActual <= v.StockMinimo
    );

    DECLARE @ok INT = CASE WHEN @n = @nBase THEN 1 ELSE 0 END;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('08. SP_InformeReposicionStock', 60), LEFT('Cursor devuelve las variantes a reponer', 180), LEFT(CAST(@nBase AS VARCHAR(20)), 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1
        FROM #Reposicion r
        WHERE r.CantidadSugerida <> (CASE WHEN r.StockMinimo = 0 THEN 1 ELSE r.StockMinimo * 2 END) - r.StockActual
           OR r.Prioridad <> (CASE WHEN r.StockActual = 0 THEN 'URGENTE' ELSE 'NORMAL' END)
    )
        SET @ok = 0;
    ELSE
        SET @ok = 1;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('08. SP_InformeReposicionStock', 60), LEFT('Cantidad sugerida y prioridad correctas', 180), LEFT('Cantidad = objetivo - stock y prioridad URGENTE/NORMAL', 300), LEFT(CONCAT('filas=', @n), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);

    DROP TABLE #Reposicion;
END TRY
BEGIN CATCH
    DECLARE @e INT = ERROR_NUMBER(), @m NVARCHAR(4000) = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('08. SP_InformeReposicionStock', 60), LEFT('Ejecución del cursor', 180), LEFT('Sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   10. TRIGGERS
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @v INT, @p DECIMAL(12,2);
DECLARE @stock INT, @stockDespues INT, @stockDespues2 INT;
DECLARE @idVenta INT, @idCompra INT, @total DECIMAL(12,2);
DECLARE @alertaAntes INT, @alertaDespues INT, @alertaDespues2 INT;
DECLARE @min INT, @precio DECIMAL(12,2), @precioNuevo DECIMAL(12,2);
DECLARE @histAntes INT, @histDespues INT;
DECLARE @ventasAntes INT, @ventasDespues INT;
DECLARE @mov INT;
DECLARE @e INT, @m NVARCHAR(4000), @ok BIT;

SELECT TOP 1 @v = v.IdVariante, @p = v.PrecioVenta
FROM dbo.VarianteProducto v
INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
WHERE p.Activo = 1 AND v.StockActual > v.StockMinimo
ORDER BY v.IdVariante;

-- 10.1 TR_DescontarStockVenta + TR_CalcularTotalVenta
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @idVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM dbo.Venta;

    INSERT INTO dbo.Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
    VALUES (@idVenta, 1, 2, GETDATE(), 'EFECTIVO', 0, 'CONFIRMADA');

    INSERT INTO dbo.DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
    VALUES (@idVenta, 1, @v, 2, 123.45, 0);

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @total = Total FROM dbo.Venta WHERE IdVenta = @idVenta;

    SET @ok = CASE WHEN @stockDespues = @stock - 2 AND @total = 246.90 THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_DescontarStockVenta y TR_CalcularTotalVenta', 180), LEFT('Stock -2 y Total 246.90', 300), LEFT(CONCAT('Stock=', @stockDespues, ', Total=', @total), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_DescontarStockVenta y TR_CalcularTotalVenta', 180), LEFT('Stock -2 y Total 246.90', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 10.2 TR_DevolverStockAnulacion
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @idVenta = ISNULL(MAX(IdVenta), 0) + 1 FROM dbo.Venta;

    INSERT INTO dbo.Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
    VALUES (@idVenta, 1, 2, GETDATE(), 'EFECTIVO', 0, 'CONFIRMADA');

    INSERT INTO dbo.DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
    VALUES (@idVenta, 1, @v, 2, @p, 0);

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    UPDATE dbo.Venta SET Estado = 'ANULADA' WHERE IdVenta = @idVenta;

    SELECT @stockDespues2 = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    SET @ok = CASE WHEN @stockDespues = @stock - 2 AND @stockDespues2 = @stock THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_DevolverStockAnulacion', 180), LEFT(CONCAT('Stock vuelve a ', @stock), 300), LEFT(CONCAT('Después venta=', @stockDespues, ', después anulación=', @stockDespues2), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_DevolverStockAnulacion', 180), LEFT('Stock restaurado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 10.3 TR_SumarStockCompra
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @idCompra = ISNULL(MAX(IdCompra), 0) + 1 FROM dbo.Compra;

    INSERT INTO dbo.Compra (IdCompra, IdProveedor, IdUsuario, Fecha, NroComprobante, Total, Estado)
    VALUES (@idCompra, 1, 1, GETDATE(), 'TEST-SUITE-TRIGGER-COMPRA', 0, 'PENDIENTE');

    INSERT INTO dbo.DetalleCompra (IdCompra, NroLinea, IdVariante, Cantidad, CostoUnitario)
    VALUES (@idCompra, 1, @v, 3, 100.00);

    UPDATE dbo.Compra SET Estado = 'RECIBIDA' WHERE IdCompra = @idCompra;

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    SET @ok = CASE WHEN @stockDespues = @stock + 3 THEN 1 ELSE 0 END;
    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_SumarStockCompra', 180), LEFT(CONCAT('Stock=', @stock + 3), 300), LEFT(CONCAT('Stock=', @stockDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_SumarStockCompra', 180), LEFT('Stock sumado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 10.4 TR_AvisoStockMinimo
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @min = StockMinimo FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @alertaAntes = COUNT(*) FROM dbo.AlertaStock WHERE IdVariante = @v;

    UPDATE dbo.VarianteProducto SET StockActual = @min WHERE IdVariante = @v;
    SELECT @alertaDespues = COUNT(*) FROM dbo.AlertaStock WHERE IdVariante = @v;

    UPDATE dbo.VarianteProducto
    SET StockActual = CASE WHEN @min > 0 THEN @min - 1 ELSE 0 END
    WHERE IdVariante = @v;
    SELECT @alertaDespues2 = COUNT(*) FROM dbo.AlertaStock WHERE IdVariante = @v;

    SET @ok = CASE
        WHEN @alertaDespues = @alertaAntes + 1
         AND @alertaDespues2 = @alertaDespues
        THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_AvisoStockMinimo', 180), LEFT('Inserta 1 alerta al cruzar el mínimo y no duplica al seguir bajo', 300), LEFT(CONCAT('Alertas=', @alertaAntes, ' -> ', @alertaDespues, ' -> ', @alertaDespues2), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_AvisoStockMinimo', 180), LEFT('Alerta insertada una sola vez', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 10.5 TR_HistorialPrecio
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @precio = PrecioVenta FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @histAntes = COUNT(*) FROM dbo.HistorialPrecio WHERE IdVariante = @v;

    UPDATE dbo.VarianteProducto
    SET PrecioVenta = @precio + 123.45
    WHERE IdVariante = @v;

    SET @precioNuevo = @precio + 123.45;
    SELECT @histDespues = COUNT(*) FROM dbo.HistorialPrecio WHERE IdVariante = @v;

    SET @ok = CASE
        WHEN @histDespues = @histAntes + 1
         AND EXISTS (
             SELECT 1 FROM dbo.HistorialPrecio
             WHERE IdVariante = @v
               AND PrecioAnterior = @precio
               AND PrecioNuevo = @precioNuevo
         )
        THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_HistorialPrecio', 180), LEFT(CONCAT('Registro ', @precio, ' -> ', @precioNuevo), 300), LEFT(CONCAT('Historial=', @histAntes, ' -> ', @histDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_HistorialPrecio', 180), LEFT('Cambio de precio auditado', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 10.6 TR_NoBorrarVenta (INSTEAD OF DELETE)
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @ventasAntes = COUNT(*) FROM dbo.Venta;
    SELECT @idVenta = MIN(IdVenta) FROM dbo.Venta;

    BEGIN TRY
        DELETE FROM dbo.Venta WHERE IdVenta = @idVenta;
        SET @e = 0;
        SET @m = 'DELETE ejecutado sin error';
    END TRY
    BEGIN CATCH
        SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    END CATCH;

    SELECT @ventasDespues = COUNT(*) FROM dbo.Venta;
    SET @ok = CASE WHEN @ventasDespues = @ventasAntes THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_NoBorrarVenta', 180), LEFT('La venta no se elimina', 300), LEFT(CONCAT('Ventas=', @ventasAntes, ' -> ', @ventasDespues, '; ', @e, ': ', @m), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_NoBorrarVenta', 180), LEFT('La venta no se elimina', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 10.7 TR_AplicarAjusteStock
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;
    SELECT @mov = ISNULL(MAX(IdMovimiento), 0) FROM dbo.MovimientoStock;

    INSERT INTO dbo.MovimientoStock
        (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
    VALUES (@mov + 1, @v, 1, GETDATE(), 'AJUSTE', 2, 'Test trigger ajuste +2');

    SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    INSERT INTO dbo.MovimientoStock
        (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
    VALUES (@mov + 2, @v, 1, GETDATE(), 'AJUSTE', -2, 'Test trigger ajuste -2');

    SELECT @stockDespues2 = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

    INSERT INTO dbo.MovimientoStock
        (IdMovimiento, IdVariante, IdUsuario, Fecha, TipoMovimiento, Cantidad, Observacion)
    VALUES (@mov + 3, @v, 1, GETDATE(), 'ENTRADA', 5, 'Test trigger: ENTRADA no aplica');

    SET @ok = CASE
        WHEN @stockDespues = @stock + 2
         AND @stockDespues2 = @stock
        THEN 1 ELSE 0 END;

    ROLLBACK TRANSACTION;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_AplicarAjusteStock', 180), LEFT(CONCAT('+2 -> ', @stock + 2, '; -2 -> ', @stock), 300), LEFT(CONCAT('+2 -> ', @stockDespues, '; -2 -> ', @stockDespues2), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('09. Triggers', 60), LEFT('TR_AplicarAjusteStock', 180), LEFT('Ajustes aplicados', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   11. SEGURIDAD: CATÁLOGO DE PERMISOS
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

-- 11.1 Pertenencia de usuarios a roles
BEGIN TRY
    IF EXISTS (
        SELECT 1
        FROM sys.database_role_members rm
        INNER JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        INNER JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
        WHERE r.name = N'rol_administrador' AND u.name = N'usr_admin'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('usr_admin pertenece a rol_administrador', 180), LEFT('Pertenece', 300), LEFT('Pertenece', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('usr_admin pertenece a rol_administrador', 180), LEFT('Pertenece', 300), LEFT('No pertenece', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1
        FROM sys.database_role_members rm
        INNER JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
        INNER JOIN sys.database_principals u ON u.principal_id = rm.member_principal_id
        WHERE r.name = N'rol_vendedor' AND u.name = N'usr_vendedor'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('usr_vendedor pertenece a rol_vendedor', 180), LEFT('Pertenece', 300), LEFT('Pertenece', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('usr_vendedor pertenece a rol_vendedor', 180), LEFT('Pertenece', 300), LEFT('No pertenece', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    DECLARE @e INT = ERROR_NUMBER(), @m NVARCHAR(4000) = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('Pertenencia de roles', 180), LEFT('Consultar miembros', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 11.2 DENY de lectura de Contrasena para ambos roles
BEGIN TRY
    IF EXISTS (
        SELECT 1
        FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        INNER JOIN sys.columns c ON c.object_id = p.major_id AND c.column_id = p.minor_id
        WHERE dp.name = N'rol_administrador'
          AND o.name = N'Usuario'
          AND c.name = N'Contrasena'
          AND p.permission_name = N'SELECT'
          AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_administrador no puede leer Usuario.Contrasena', 180), LEFT('DENY SELECT', 300), LEFT('DENY SELECT', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_administrador no puede leer Usuario.Contrasena', 180), LEFT('DENY SELECT', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1
        FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        INNER JOIN sys.columns c ON c.object_id = p.major_id AND c.column_id = p.minor_id
        WHERE dp.name = N'rol_vendedor'
          AND o.name = N'Usuario'
          AND c.name = N'Contrasena'
          AND p.permission_name = N'SELECT'
          AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede leer Usuario.Contrasena', 180), LEFT('DENY SELECT', 300), LEFT('DENY SELECT', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede leer Usuario.Contrasena', 180), LEFT('DENY SELECT', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    DECLARE @e2 INT = ERROR_NUMBER(), @m2 NVARCHAR(4000) = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('DENY de Contrasena', 180), LEFT('DENY SELECT', 300), LEFT(CONCAT(@e2, ': ', @m2), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 11.3 DENY de DELETE sobre ventas/compras para administrador y vendedor
BEGIN TRY
    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_administrador' AND o.name = N'Venta'
          AND p.permission_name = N'DELETE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_administrador no puede borrar Venta', 180), LEFT('DENY DELETE', 300), LEFT('DENY DELETE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_administrador no puede borrar Venta', 180), LEFT('DENY DELETE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_administrador' AND o.name = N'Compra'
          AND p.permission_name = N'DELETE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_administrador no puede borrar Compra', 180), LEFT('DENY DELETE', 300), LEFT('DENY DELETE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_administrador no puede borrar Compra', 180), LEFT('DENY DELETE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    DECLARE @e3 INT = ERROR_NUMBER(), @m3 NVARCHAR(4000) = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('DENY DELETE en ventas/compras', 180), LEFT('DENY DELETE', 300), LEFT(CONCAT(@e3, ': ', @m3), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 11.4 Permisos del vendedor sobre stock, compras y SPs administrativos
BEGIN TRY
    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'VarianteProducto'
          AND p.permission_name = N'UPDATE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede actualizar stock directo', 180), LEFT('DENY UPDATE', 300), LEFT('DENY UPDATE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede actualizar stock directo', 180), LEFT('DENY UPDATE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'Compra'
          AND p.permission_name = N'SELECT' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede leer Compra', 180), LEFT('DENY SELECT', 300), LEFT('DENY SELECT', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede leer Compra', 180), LEFT('DENY SELECT', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'SP_RegistrarVenta'
          AND p.permission_name = N'EXECUTE' AND p.state = N'G'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor puede ejecutar SP_RegistrarVenta', 180), LEFT('GRANT EXECUTE', 300), LEFT('GRANT EXECUTE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor puede ejecutar SP_RegistrarVenta', 180), LEFT('GRANT EXECUTE', 300), LEFT('Sin GRANT', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'SP_AnularVenta'
          AND p.permission_name = N'EXECUTE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_AnularVenta', 180), LEFT('DENY EXECUTE', 300), LEFT('DENY EXECUTE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_AnularVenta', 180), LEFT('DENY EXECUTE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'SP_AjustarStock'
          AND p.permission_name = N'EXECUTE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_AjustarStock', 180), LEFT('DENY EXECUTE', 300), LEFT('DENY EXECUTE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_AjustarStock', 180), LEFT('DENY EXECUTE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'SP_RegistrarCompra'
          AND p.permission_name = N'EXECUTE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_RegistrarCompra', 180), LEFT('DENY EXECUTE', 300), LEFT('DENY EXECUTE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_RegistrarCompra', 180), LEFT('DENY EXECUTE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);

    IF EXISTS (
        SELECT 1 FROM sys.database_permissions p
        INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
        INNER JOIN sys.objects o ON o.object_id = p.major_id
        WHERE dp.name = N'rol_vendedor' AND o.name = N'SP_RecibirCompra'
          AND p.permission_name = N'EXECUTE' AND p.state = N'D'
    )
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_RecibirCompra', 180), LEFT('DENY EXECUTE', 300), LEFT('DENY EXECUTE', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
    ELSE
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('rol_vendedor no puede ejecutar SP_RecibirCompra', 180), LEFT('DENY EXECUTE', 300), LEFT('Sin DENY', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    DECLARE @e4 INT = ERROR_NUMBER(), @m4 NVARCHAR(4000) = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('10. Seguridad catálogo', 60), LEFT('Permisos del vendedor', 180), LEFT('Revisar DENY/GRANT', 300), LEFT(CONCAT(@e4, ': ', @m4), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   12. SEGURIDAD: PRUEBAS DE COMPORTAMIENTO CON EXECUTE AS USER
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

IF IS_SRVROLEMEMBER('sysadmin') <> 1 AND HAS_PERMS_BY_NAME('usr_vendedor', 'USER', 'IMPERSONATE') <> 1
BEGIN
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('EXECUTE AS USER', 180), LEFT('Permiso de impersonación', 300), LEFT('OMITIDO: el login actual no puede impersonar usuarios', 700),
        CASE WHEN (1) = 1 THEN 'OK' ELSE 'FALLA' END);
END
ELSE
BEGIN
    -- 12.1 Vendedor: no puede leer la contraseña
    DECLARE @e INT, @m NVARCHAR(4000), @ok BIT;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @v INT, @p DECIMAL(12,2);
    DECLARE @stock INT, @stockDespues INT;

    SELECT TOP 1 @v = v.IdVariante, @p = v.PrecioVenta
    FROM dbo.VarianteProducto v
    INNER JOIN dbo.Producto p ON p.IdProducto = v.IdProducto
    WHERE p.Activo = 1 AND v.StockActual > v.StockMinimo
    ORDER BY v.IdVariante;

    -- Helper temporal para ejecutar SQL como vendedor.
    IF OBJECT_ID('tempdb..#run_vendor') IS NOT NULL DROP PROCEDURE #run_vendor;

    EXEC(N'
        CREATE PROCEDURE #run_vendor
            @Sql NVARCHAR(MAX),
            @Err INT OUTPUT,
            @Msg NVARCHAR(4000) OUTPUT
        AS
        BEGIN
            SET NOCOUNT ON;
            SET @Err = 0;
            SET @Msg = NULL;

            BEGIN TRY
                EXECUTE AS USER = ''usr_vendedor'';
                BEGIN TRY
                    EXEC sys.sp_executesql @Sql;
                    REVERT;
                END TRY
                BEGIN CATCH
                    SET @Err = ERROR_NUMBER();
                    SET @Msg = ERROR_MESSAGE();
                    REVERT;
                END CATCH
            END TRY
            BEGIN CATCH
                SET @Err = ERROR_NUMBER();
                SET @Msg = ERROR_MESSAGE();
            END CATCH
        END;
    ');

    -- Helper temporal para ejecutar SQL como administrador.
    IF OBJECT_ID('tempdb..#run_admin') IS NOT NULL DROP PROCEDURE #run_admin;

    EXEC(N'
        CREATE PROCEDURE #run_admin
            @Sql NVARCHAR(MAX),
            @Err INT OUTPUT,
            @Msg NVARCHAR(4000) OUTPUT
        AS
        BEGIN
            SET NOCOUNT ON;
            SET @Err = 0;
            SET @Msg = NULL;

            BEGIN TRY
                EXECUTE AS USER = ''usr_admin'';
                BEGIN TRY
                    EXEC sys.sp_executesql @Sql;
                    REVERT;
                END TRY
                BEGIN CATCH
                    SET @Err = ERROR_NUMBER();
                    SET @Msg = ERROR_MESSAGE();
                    REVERT;
                END CATCH
            END TRY
            BEGIN CATCH
                SET @Err = ERROR_NUMBER();
                SET @Msg = ERROR_MESSAGE();
            END CATCH
        END;
    ');

    -- 12.1 Vendedor: SELECT * FROM Usuario (debe fallar por Contrasena)
    EXEC #run_vendor N'SELECT * FROM dbo.Usuario;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no lee Usuario.Contrasena', 180), LEFT('error 229 o 230', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e IN (229, 230) THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.2 Vendedor: columnas permitidas de Usuario
    EXEC #run_vendor N'SELECT IdUsuario, NombreUsuario, Activo FROM dbo.Usuario;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor lee columnas permitidas de Usuario', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.3 Vendedor: no lee Compra
    EXEC #run_vendor N'SELECT TOP 1 * FROM dbo.Compra;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no lee Compra', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.4 Vendedor: no lee Proveedor
    EXEC #run_vendor N'SELECT TOP 1 * FROM dbo.Proveedor;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no lee Proveedor', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.5 Vendedor: no lee MovimientoStock
    EXEC #run_vendor N'SELECT TOP 1 * FROM dbo.MovimientoStock;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no lee MovimientoStock', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.6 Vendedor: no actualiza stock directo
    EXEC #run_vendor N'UPDATE dbo.VarianteProducto SET StockActual = StockActual WHERE IdVariante = 1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no actualiza VarianteProducto', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.7 Vendedor: no borra ventas
    EXEC #run_vendor N'DELETE FROM dbo.Venta WHERE IdVenta = -1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no borra Venta', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.8 Vendedor: no ejecuta SP_AnularVenta
    EXEC #run_vendor N'EXEC dbo.SP_AnularVenta @IdVenta = 1, @IdUsuario = 1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no ejecuta SP_AnularVenta', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.9 Vendedor: no ejecuta SP_AjustarStock
    EXEC #run_vendor N'EXEC dbo.SP_AjustarStock @IdVariante = 1, @NuevaCantidad = 1, @IdUsuario = 1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no ejecuta SP_AjustarStock', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.10 Vendedor: no ejecuta SP_RegistrarCompra
    EXEC #run_vendor N'
        DECLARE @d dbo.TipoDetalleCompra;
        INSERT INTO @d VALUES (1, 1, 100.00);
        EXEC dbo.SP_RegistrarCompra @IdProveedor = 1, @IdUsuario = 1, @Detalle = @d;
    ', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no ejecuta SP_RegistrarCompra', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.11 Vendedor: no ejecuta SP_RecibirCompra
    EXEC #run_vendor N'EXEC dbo.SP_RecibirCompra @IdCompra = 1, @IdUsuario = 1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no ejecuta SP_RecibirCompra', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.12 Vendedor: no consulta fn_ResumenVentasPorUsuario
    EXEC #run_vendor N'SELECT TOP 1 * FROM dbo.fn_ResumenVentasPorUsuario(''2000-01-01'', ''2100-12-31'');', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor no consulta fn_ResumenVentasPorUsuario', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.13 Vendedor: sí consulta catálogo
    EXEC #run_vendor N'SELECT TOP 1 IdProducto, Nombre FROM dbo.Producto;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor consulta Producto', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.14 Vendedor: sí consulta stock
    EXEC #run_vendor N'SELECT TOP 1 IdVariante, StockActual FROM dbo.VarianteProducto;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor consulta VarianteProducto', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.15 Vendedor: sí consulta vistas
    EXEC #run_vendor N'SELECT TOP 1 * FROM dbo.vw_StockVariante;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor consulta vw_StockVariante', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    EXEC #run_vendor N'SELECT TOP 1 * FROM dbo.vw_VentasDetalladas;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor consulta vw_VentasDetalladas', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.16 Vendedor: sí ejecuta fn_EstadoStock
    EXEC #run_vendor N'SELECT dbo.fn_EstadoStock(1);', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor ejecuta fn_EstadoStock', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.17 Vendedor: sí ejecuta SP_InformeReposicionStock
    EXEC #run_vendor N'EXEC dbo.SP_InformeReposicionStock;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor ejecuta SP_InformeReposicionStock', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.18 Vendedor: sí registra una venta por SP
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

        SET @sql = N'
            DECLARE @d dbo.TipoDetalleVenta;
            INSERT INTO @d VALUES (' + CAST(@v AS NVARCHAR(20)) + N', 1, ' + CAST(@p AS NVARCHAR(30)) + N', 0);
            EXEC dbo.SP_RegistrarVenta
                @IdCliente = NULL,
                @IdUsuario = 2,
                @MedioPago = ''EFECTIVO'',
                @Detalle = @d;';

        EXEC #run_vendor @sql, @e OUTPUT, @m OUTPUT;

        SELECT @stockDespues = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

        SET @ok = CASE WHEN @e = 0 AND @stockDespues = @stock - 1 THEN 1 ELSE 0 END;

        ROLLBACK TRANSACTION;

        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor registra venta por SP_RegistrarVenta', 180), LEFT(CONCAT('sin error y stock=', @stock - 1), 300), LEFT(CONCAT(@e, ': ', @m, '; stock=', @stockDespues), 700),
        CASE WHEN (@ok) = 1 THEN 'OK' ELSE 'FALLA' END);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Vendedor registra venta por SP_RegistrarVenta', 180), LEFT('Venta registrada', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
    END CATCH;

    -- 12.19 Administrador: no lee Contrasena
    EXEC #run_admin N'SELECT * FROM dbo.Usuario;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador no lee Usuario.Contrasena', 180), LEFT('error 229 o 230', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e IN (229, 230) THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.20 Administrador: sí lee columnas permitidas
    EXEC #run_admin N'SELECT IdUsuario, NombreUsuario, Activo FROM dbo.Usuario;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador lee columnas permitidas de Usuario', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.21 Administrador: sí consulta compras
    EXEC #run_admin N'SELECT TOP 1 IdCompra, Estado FROM dbo.Compra;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador consulta Compra', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.22 Administrador: no borra ventas
    EXEC #run_admin N'DELETE FROM dbo.Venta WHERE IdVenta = -1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador no borra Venta', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.23 Administrador: no borra compras
    EXEC #run_admin N'DELETE FROM dbo.Compra WHERE IdCompra = -1;', @e OUTPUT, @m OUTPUT;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador no borra Compra', 180), LEFT('error 229', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 229 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    -- 12.24 Administrador: sí ejecuta SP_AjustarStock (sin diferencia)
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @stock = StockActual FROM dbo.VarianteProducto WHERE IdVariante = @v;

        SET @sql = N'EXEC dbo.SP_AjustarStock @IdVariante = ' + CAST(@v AS NVARCHAR(20)) +
                   N', @NuevaCantidad = ' + CAST(@stock AS NVARCHAR(20)) + N', @IdUsuario = 1;';

        EXEC #run_admin @sql, @e OUTPUT, @m OUTPUT;

        ROLLBACK TRANSACTION;

        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador ejecuta SP_AjustarStock', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
        INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('11. Seguridad comportamiento', 60), LEFT('Administrador ejecuta SP_AjustarStock', 180), LEFT('sin error', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
    END CATCH;
END;
GO

/* ------------------------------------------------------------
   13. INTEGRIDAD DE DATOS Y CONSTRAINTS
   ------------------------------------------------------------ */

SET NOCOUNT ON ;
SET XACT_ABORT OFF ;

DECLARE @n INT, @e INT, @m NVARCHAR(4000);

-- 13.1 Totales de ventas coinciden con su detalle
BEGIN TRY
    SELECT @n = COUNT(*)
    FROM (
        SELECT v.IdVenta
        FROM dbo.Venta v
        LEFT JOIN dbo.DetalleVenta dv ON dv.IdVenta = v.IdVenta
        GROUP BY v.IdVenta, v.Total
        HAVING v.Total <> ISNULL(SUM(dv.Cantidad * dv.PrecioUnitario - dv.Descuento), 0)
    ) AS x;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('Venta.Total coincide con DetalleVenta', 180), LEFT('0 diferencias', 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('Venta.Total coincide con DetalleVenta', 180), LEFT('0 diferencias', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 13.2 Totales de compras coinciden con su detalle
BEGIN TRY
    SELECT @n = COUNT(*)
    FROM (
        SELECT c.IdCompra
        FROM dbo.Compra c
        LEFT JOIN dbo.DetalleCompra dc ON dc.IdCompra = c.IdCompra
        GROUP BY c.IdCompra, c.Total
        HAVING c.Total <> ISNULL(SUM(dc.Cantidad * dc.CostoUnitario), 0)
    ) AS x;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('Compra.Total coincide con DetalleCompra', 180), LEFT('0 diferencias', 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('Compra.Total coincide con DetalleCompra', 180), LEFT('0 diferencias', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 13.3 No hay stock negativo
BEGIN TRY
    SELECT @n = COUNT(*) FROM dbo.VarianteProducto WHERE StockActual < 0;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('No hay variantes con stock negativo', 180), LEFT('0 filas', 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('No hay variantes con stock negativo', 180), LEFT('0 filas', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 13.4 Alertas solo con Atendida 0/1
BEGIN TRY
    SELECT @n = COUNT(*) FROM dbo.AlertaStock WHERE Atendida NOT IN (0, 1);
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('AlertaStock.Atendida solo 0/1', 180), LEFT('0 filas', 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('AlertaStock.Atendida solo 0/1', 180), LEFT('0 filas', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 13.5 DBCC CHECKCONSTRAINTS sin violaciones
BEGIN TRY
    IF OBJECT_ID('tempdb..#DBCC') IS NOT NULL DROP TABLE #DBCC;

    CREATE TABLE #DBCC
    (
        Tabla       VARCHAR(255),
        Restriccion VARCHAR(255),
        Ubicacion   VARCHAR(255)
    );

    INSERT INTO #DBCC
    EXEC ('DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS');

    SELECT @n = COUNT(*) FROM #DBCC;

    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS', 180), LEFT('0 violaciones', 300), LEFT(CAST(@n AS VARCHAR(20)), 700),
        CASE WHEN (CASE WHEN @n = 0 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);

    DROP TABLE #DBCC;
END TRY
BEGIN CATCH
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS', 180), LEFT('0 violaciones', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;

-- 13.6 CHECK de MedioPago (la tabla debe rechazar un valor inválido)
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Venta (IdVenta, IdCliente, IdUsuario, Fecha, MedioPago, Total, Estado)
    SELECT ISNULL(MAX(IdVenta), 0) + 1, NULL, 2, GETDATE(), 'BITCOIN', 0, 'CONFIRMADA'
    FROM dbo.Venta;

    ROLLBACK TRANSACTION;
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('CHECK Venta.MedioPago rechaza valor inválido', 180), LEFT('error 547', 300), LEFT('Sin error', 700),
        CASE WHEN (0) = 1 THEN 'OK' ELSE 'FALLA' END);
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT @e = ERROR_NUMBER(), @m = ERROR_MESSAGE();
    INSERT INTO #Resultados (Bloque, Caso, Esperado, Obtenido, Estado)
VALUES (LEFT('12. Integridad', 60), LEFT('CHECK Venta.MedioPago rechaza valor inválido', 180), LEFT('error 547', 300), LEFT(CONCAT(@e, ': ', @m), 700),
        CASE WHEN (CASE WHEN @e = 547 THEN 1 ELSE 0 END) = 1 THEN 'OK' ELSE 'FALLA' END);
END CATCH;
GO

/* ------------------------------------------------------------
   14. RESUMEN FINAL
   ------------------------------------------------------------ */

SET NOCOUNT ON ;

SELECT
    Bloque,
    Caso,
    Esperado,
    Obtenido,
    Estado
FROM #Resultados
ORDER BY IdResultado;

SELECT
    'RESUMEN' AS Resumen,
    COUNT(*) AS Pruebas,
    SUM(CASE WHEN Estado = 'OK' THEN 1 ELSE 0 END) AS OK,
    SUM(CASE WHEN Estado = 'FALLA' THEN 1 ELSE 0 END) AS Fallas
FROM #Resultados;

SELECT
    Bloque,
    COUNT(*) AS Pruebas,
    SUM(CASE WHEN Estado = 'OK' THEN 1 ELSE 0 END) AS OK,
    SUM(CASE WHEN Estado = 'FALLA' THEN 1 ELSE 0 END) AS Fallas
FROM #Resultados
GROUP BY Bloque
ORDER BY Bloque;

IF EXISTS (SELECT 1 FROM #Resultados WHERE Estado = 'FALLA')
BEGIN
    THROW 59000, 'La suite de pruebas encontró fallas. Revise la columna Estado = FALLA.', 1;
END;
ELSE
BEGIN
    PRINT 'Todas las pruebas de SIAM finalizaron correctamente.';
END;
GO
