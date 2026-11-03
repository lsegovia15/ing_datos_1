-- ============================================================
-- SIAM - Ejecución completa y ordenada
-- Ejecutar con SQLCMD desde la carpeta sql:
--   cd sql
--   sqlcmd -S localhost -E -C -b -i 00_master.sql
--
-- En SSMS: habilitar "SQLCMD Mode" y abrir este archivo.
-- Requiere permisos de sysadmin para crear la base y los logins.
--
-- ADVERTENCIA: init_db.sql elimina y recrea la base SIAM si ya existe.
-- No ejecutar sobre una base con datos reales sin backup previo.
-- ============================================================

:on error exit
:setvar Base "."

:r $(Base)\init_db.sql
:r $(Base)\siam_triggers.sql
:r $(Base)\funciones.sql
:r $(Base)\vistas.sql

:r $(Base)\sp\SPs.sql
:r $(Base)\sp\SP_RegistrarVenta.sql
:r $(Base)\sp\SP_AnularVenta.sql
:r $(Base)\sp\SP_AjustarStock.sql
:r $(Base)\sp\SP_RegistrarCompra.sql
:r $(Base)\sp\SP_RecibirCompra.sql

:r $(Base)\cursores.sql
:r $(Base)\seed_data.sql
:r $(Base)\seguridad.sql
