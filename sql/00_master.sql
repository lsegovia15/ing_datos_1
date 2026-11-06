
:on error exit
:setvar Base "."

:r $(Base)\init_db.sql
:r $(Base)\siam_triggers.sql
:r $(Base)\funciones.sql
:r $(Base)\vistas.sql

:r $(Base)\sp\SP_RegistrarVenta.sql
:r $(Base)\sp\SP_AnularVenta.sql
:r $(Base)\sp\SP_AjustarStock.sql
:r $(Base)\sp\SP_RegistrarCompra.sql
:r $(Base)\sp\SP_RecibirCompra.sql

:r $(Base)\cursores.sql
:r $(Base)\seed_data.sql
:r $(Base)\seguridad.sql
