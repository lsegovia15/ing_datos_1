require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const fs = require('fs');
const path = require('path');
const express = require('express');
const sql = require('mssql');

const ROOT = path.join(__dirname, '..');
const DB_NAME = process.env.DB_NAME || 'SIAM';

function dbConfig(database) {
  const config = {
    server: process.env.DB_SERVER || 'localhost',
    user: process.env.DB_USER || 'sa',
    password: process.env.DB_PASSWORD || '',
    database,
    options: {
      trustServerCertificate: (process.env.DB_TRUST_CERT || 'true') === 'true',
      encrypt: true,
      enableArithAbort: true,
    },
    requestTimeout: 60000,
  };
  if (process.env.DB_INSTANCE) config.options.instanceName = process.env.DB_INSTANCE;
  else config.port = parseInt(process.env.DB_PORT || '1433', 10);
  return config;
}

// ---------------------------------------------------------------------------
// Conexion principal (a la base SIAM). Se crea a demanda y se descarta si falla.
// ---------------------------------------------------------------------------
let poolPromise = null;

function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(dbConfig(DB_NAME)).connect().catch((err) => {
      poolPromise = null;
      throw err;
    });
  }
  return poolPromise;
}

async function closePool() {
  if (!poolPromise) return;
  try {
    (await poolPromise).close();
  } catch (_) { /* la conexion ya estaba caida */ }
  poolPromise = null;
}

// ---------------------------------------------------------------------------
// Scripts del repo. El orden es el orden de ejecucion al reiniciar la base.
// ---------------------------------------------------------------------------
const SCRIPTS = [
  { file: 'sql/init_db.sql', label: 'Crear base y tablas', required: true },
  { file: 'frontend/seed.sql', label: 'Datos de prueba' },
  { file: 'sql/sp/SPs.sql', label: 'Tipo TipoDetalleVenta (TVP)' },
  { file: 'sql/sp/SP_RegistrarVenta.sql', label: 'SP_RegistrarVenta' },
  { file: 'sql/sp/SP_Anularventa.sql', label: 'SP_AnularVenta' },
  { file: 'sql/sp/SP_AjustarStock.sql', label: 'SP_AjustarStock' },
  { file: 'sql/vistas.sql', label: 'Vistas' },
  { file: 'sql/firme38_triggers.sql', label: 'Triggers (rama martin)' },
];

function splitBatches(script) {
  return script
    .split(/^\s*GO\s*(?:--.*)?$/gim)
    .map((batch) => batch.trim())
    .filter((batch) => batch.length > 0);
}

function readScript(file) {
  return fs.readFileSync(path.join(ROOT, file), 'utf8').replace(/^﻿/, '');
}

// ---------------------------------------------------------------------------
// Metadatos: tablas, columnas, claves, vistas y procedimientos
// ---------------------------------------------------------------------------
async function loadMeta() {
  const pool = await getPool();
  const columns = await pool.request().query(`
    SELECT t.name AS tableName, c.name AS columnName, c.column_id AS ord,
           ty.name AS typeName, c.max_length AS maxLength, c.precision, c.scale,
           c.is_nullable AS nullable, c.is_identity AS isIdentity, c.is_computed AS isComputed,
           dc.definition AS defaultValue,
           CASE WHEN ic.column_id IS NOT NULL THEN 1 ELSE 0 END AS isPk,
           fk.refTable, fk.refColumn
    FROM sys.tables t
    JOIN sys.columns c ON c.object_id = t.object_id
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
    LEFT JOIN sys.indexes i ON i.object_id = t.object_id AND i.is_primary_key = 1
    LEFT JOIN sys.index_columns ic ON ic.object_id = t.object_id AND ic.index_id = i.index_id AND ic.column_id = c.column_id
    OUTER APPLY (
      SELECT TOP 1 OBJECT_NAME(fkc.referenced_object_id) AS refTable,
             COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS refColumn
      FROM sys.foreign_key_columns fkc
      WHERE fkc.parent_object_id = t.object_id AND fkc.parent_column_id = c.column_id
    ) fk
    WHERE t.is_ms_shipped = 0
    ORDER BY t.name, c.column_id`);

  const tables = {};
  for (const row of columns.recordset) {
    if (!tables[row.tableName]) tables[row.tableName] = { name: row.tableName, columns: [] };
    tables[row.tableName].columns.push({
      name: row.columnName,
      type: row.typeName,
      maxLength: row.maxLength,
      precision: row.precision,
      scale: row.scale,
      nullable: !!row.nullable,
      identity: !!row.isIdentity,
      computed: !!row.isComputed,
      defaultValue: row.defaultValue,
      pk: !!row.isPk,
      ref: row.refTable ? { table: row.refTable, column: row.refColumn } : null,
    });
  }

  const triggers = await pool.request().query(`
    SELECT OBJECT_NAME(tr.parent_id) AS tableName, tr.name, tr.is_disabled AS disabled,
           STUFF((SELECT ', ' + te.type_desc FROM sys.trigger_events te
                  WHERE te.object_id = tr.object_id FOR XML PATH('')), 1, 2, '') AS events,
           CASE WHEN tr.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS timing
    FROM sys.triggers tr
    WHERE tr.parent_class = 1
    ORDER BY tableName, tr.name`);
  for (const t of triggers.recordset) {
    if (tables[t.tableName]) {
      (tables[t.tableName].triggers ||= []).push({ name: t.name, events: t.events, timing: t.timing, disabled: !!t.disabled });
    }
  }

  const views = await pool.request().query(`SELECT name FROM sys.views WHERE is_ms_shipped = 0 ORDER BY name`);

  const params = await pool.request().query(`
    SELECT p.name AS procName, pa.name AS paramName, pa.parameter_id AS ord,
           ty.name AS typeName, pa.max_length AS maxLength, pa.precision, pa.scale,
           pa.is_output AS isOutput, ty.is_table_type AS isTableType, pa.is_readonly AS isReadonly
    FROM sys.procedures p
    LEFT JOIN sys.parameters pa ON pa.object_id = p.object_id
    LEFT JOIN sys.types ty ON ty.user_type_id = pa.user_type_id
    WHERE p.is_ms_shipped = 0
    ORDER BY p.name, pa.parameter_id`);

  const tableTypes = await pool.request().query(`
    SELECT tt.name AS typeName, c.name AS columnName, c.column_id AS ord,
           ty.name AS colType, c.max_length AS maxLength, c.precision, c.scale,
           c.is_nullable AS nullable, dc.definition AS defaultValue
    FROM sys.table_types tt
    JOIN sys.columns c ON c.object_id = tt.type_table_object_id
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
    ORDER BY tt.name, c.column_id`);

  const types = {};
  for (const row of tableTypes.recordset) {
    (types[row.typeName] ||= []).push({
      name: row.columnName,
      type: row.colType,
      maxLength: row.maxLength,
      precision: row.precision,
      scale: row.scale,
      nullable: !!row.nullable,
      defaultValue: row.defaultValue,
    });
  }

  const procedures = {};
  for (const row of params.recordset) {
    if (!procedures[row.procName]) procedures[row.procName] = { name: row.procName, params: [] };
    if (!row.paramName) continue;
    procedures[row.procName].params.push({
      name: row.paramName.replace(/^@/, ''),
      type: row.typeName,
      maxLength: row.maxLength,
      precision: row.precision,
      scale: row.scale,
      output: !!row.isOutput,
      tableType: row.isTableType ? types[row.typeName] || [] : null,
    });
  }

  return {
    database: DB_NAME,
    tables: Object.values(tables),
    views: views.recordset.map((v) => v.name),
    procedures: Object.values(procedures),
  };
}

// Tipo de mssql a partir de los metadatos de una columna o parametro
function sqlType(meta) {
  const len = meta.maxLength === -1 ? sql.MAX : meta.maxLength;
  switch (meta.type) {
    case 'int': return sql.Int;
    case 'bigint': return sql.BigInt;
    case 'smallint': return sql.SmallInt;
    case 'tinyint': return sql.TinyInt;
    case 'bit': return sql.Bit;
    case 'decimal':
    case 'numeric': return sql.Decimal(meta.precision, meta.scale);
    case 'money': return sql.Money;
    case 'float': return sql.Float;
    case 'varchar': return sql.VarChar(len);
    case 'char': return sql.Char(len);
    case 'nvarchar': return sql.NVarChar(len === sql.MAX ? len : len / 2);
    case 'nchar': return sql.NChar(len / 2);
    case 'date': return sql.Date;
    case 'datetime2': return sql.DateTime2;
    // Fechas como texto: SQL Server convierte 'YYYY-MM-DD HH:MM:SS' sin problemas de zona horaria
    case 'datetime':
    case 'smalldatetime': return sql.VarChar(30);
    default: return sql.NVarChar(sql.MAX);
  }
}

const NUMERIC = new Set(['int', 'bigint', 'smallint', 'tinyint', 'decimal', 'numeric', 'money', 'float']);

function convertValue(meta, value) {
  if (value === null || value === undefined) return null;
  if (meta.type === 'bit') return value === true || value === 'true' || value === '1' || value === 1;
  if (NUMERIC.has(meta.type)) {
    const number = Number(String(value).replace(',', '.'));
    if (Number.isNaN(number)) throw new Error(`"${value}" no es un numero valido para ${meta.name}`);
    return number;
  }
  if (meta.type === 'date' || meta.type === 'datetime2') return new Date(value);
  return String(value);
}

function quote(name) {
  return '[' + String(name).replace(/]/g, ']]') + ']';
}

async function tableMeta(name) {
  const meta = await loadMeta();
  const table = meta.tables.find((t) => t.name === name);
  if (!table) throw new Error(`La tabla ${name} no existe`);
  return table;
}

function formatError(err) {
  const errors = [];
  if (err.precedingErrors) for (const e of err.precedingErrors) errors.push(e.message);
  errors.push(err.message);
  return {
    error: errors.join('\n'),
    number: err.number || (err.originalError && err.originalError.info && err.originalError.info.number) || null,
  };
}

// Ejecuta un request capturando mensajes PRINT / informativos
function collectMessages(request) {
  const messages = [];
  request.on('info', (info) => messages.push(info.message));
  return messages;
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------
const app = express();
app.use(express.json({ limit: '2mb' }));
app.use(express.static(path.join(__dirname, 'public')));

const api = (handler) => async (req, res) => {
  try {
    res.json(await handler(req, res));
  } catch (err) {
    res.status(400).json(formatError(err));
  }
};

app.get('/api/status', api(async () => {
  const pool = await getPool();
  const result = await pool.request().query('SELECT @@VERSION AS version, DB_NAME() AS db');
  return { ok: true, ...result.recordset[0] };
}));

app.get('/api/meta', api(loadMeta));

app.get('/api/table/:name', api(async (req) => {
  const table = await tableMeta(req.params.name);
  const limit = Math.min(parseInt(req.query.limit || '500', 10) || 500, 5000);
  const order = table.columns.filter((c) => c.pk).map((c) => quote(c.name)).join(', ') || '1';
  const pool = await getPool();
  const result = await pool.request().query(
    `SELECT TOP (${limit}) * FROM ${quote(table.name)} ORDER BY ${order} DESC;
     SELECT COUNT(*) AS total FROM ${quote(table.name)};`);
  return { rows: result.recordsets[0], total: result.recordsets[1][0].total };
}));

app.post('/api/table/:name/insert', api(async (req) => {
  const table = await tableMeta(req.params.name);
  const values = req.body.values || {};
  const pool = await getPool();
  const request = pool.request();
  const messages = collectMessages(request);
  const cols = [];
  table.columns.forEach((col, i) => {
    if (col.identity || col.computed || !(col.name in values)) return;
    request.input('p' + i, sqlType(col), convertValue(col, values[col.name]));
    cols.push({ col, param: '@p' + i });
  });
  const statement = cols.length
    ? `INSERT INTO ${quote(table.name)} (${cols.map((c) => quote(c.col.name)).join(', ')}) VALUES (${cols.map((c) => c.param).join(', ')})`
    : `INSERT INTO ${quote(table.name)} DEFAULT VALUES`;
  const result = await request.query(statement);
  return { rowsAffected: result.rowsAffected, messages, statement };
}));

function whereByKey(table, key, request) {
  const pkCols = table.columns.filter((c) => c.pk);
  if (!pkCols.length) throw new Error('La tabla no tiene clave primaria');
  return pkCols.map((col, i) => {
    if (!(col.name in key)) throw new Error(`Falta la clave ${col.name}`);
    request.input('k' + i, sqlType(col), convertValue(col, key[col.name]));
    return `${quote(col.name)} = @k${i}`;
  }).join(' AND ');
}

app.post('/api/table/:name/update', api(async (req) => {
  const table = await tableMeta(req.params.name);
  const { key = {}, values = {} } = req.body;
  const pool = await getPool();
  const request = pool.request();
  const messages = collectMessages(request);
  const sets = [];
  table.columns.forEach((col, i) => {
    if (col.identity || col.computed || !(col.name in values)) return;
    request.input('p' + i, sqlType(col), convertValue(col, values[col.name]));
    sets.push(`${quote(col.name)} = @p${i}`);
  });
  if (!sets.length) throw new Error('No hay cambios para guardar');
  const statement = `UPDATE ${quote(table.name)} SET ${sets.join(', ')} WHERE ${whereByKey(table, key, request)}`;
  const result = await request.query(statement);
  return { rowsAffected: result.rowsAffected, messages, statement };
}));

app.post('/api/table/:name/delete', api(async (req) => {
  const table = await tableMeta(req.params.name);
  const pool = await getPool();
  const request = pool.request();
  const messages = collectMessages(request);
  const statement = `DELETE FROM ${quote(table.name)} WHERE ${whereByKey(table, req.body.key || {}, request)}`;
  const result = await request.query(statement);
  return { rowsAffected: result.rowsAffected, messages, statement };
}));

app.get('/api/view/:name', api(async (req) => {
  const meta = await loadMeta();
  if (!meta.views.includes(req.params.name)) throw new Error(`La vista ${req.params.name} no existe`);
  const pool = await getPool();
  const result = await pool.request().query(`SELECT TOP (1000) * FROM ${quote(req.params.name)}`);
  return { rows: result.recordset };
}));

app.post('/api/procedure/:name', api(async (req) => {
  const meta = await loadMeta();
  const proc = meta.procedures.find((p) => p.name === req.params.name);
  if (!proc) throw new Error(`El procedimiento ${req.params.name} no existe`);
  const values = req.body.values || {};
  const pool = await getPool();
  const request = pool.request();
  const messages = collectMessages(request);

  for (const param of proc.params) {
    if (param.tableType) {
      const tvp = new sql.Table(param.type);
      for (const col of param.tableType) tvp.columns.add(col.name, sqlType(col), { nullable: col.nullable });
      for (const row of values[param.name] || []) {
        tvp.rows.add(...param.tableType.map((col) => {
          const raw = row[col.name];
          if (raw === '' || raw === undefined || raw === null) {
            if (col.nullable) return null;
            throw new Error(`Falta ${col.name} en una linea de ${param.name}`);
          }
          return convertValue(col, raw);
        }));
      }
      request.input(param.name, tvp);
    } else if (param.output) {
      request.output(param.name, sqlType(param));
    } else if (param.name in values) {
      // Si el campo viene vacio no se envia, asi aplica el valor por defecto del SP
      const raw = values[param.name];
      request.input(param.name, sqlType(param), raw === null ? null : convertValue(param, raw));
    }
  }

  const result = await request.execute(proc.name);
  return {
    recordsets: result.recordsets,
    output: result.output,
    returnValue: result.returnValue,
    rowsAffected: result.rowsAffected,
    messages,
  };
}));

// Consola SQL: acepta varios lotes separados por GO
app.post('/api/query', api(async (req) => {
  const batches = splitBatches(req.body.sql || '');
  if (!batches.length) throw new Error('No hay nada para ejecutar');
  const pool = await getPool();
  const results = [];
  for (const batch of batches) {
    const request = pool.request();
    const messages = collectMessages(request);
    try {
      const result = await request.query(batch);
      results.push({ recordsets: result.recordsets, rowsAffected: result.rowsAffected, messages });
    } catch (err) {
      results.push({ ...formatError(err), messages });
      break;
    }
  }
  return { results };
}));

// Consultas listas para usar: las del repo (Subconsultas.sql) + chequeos utiles para los triggers
app.get('/api/presets', api(async () => {
  const presets = [
    { group: 'Control', title: 'Stock por variante', sql:
`SELECT v.IdVariante, v.SKU, p.Nombre AS Producto, p.Activo AS ProductoActivo,
       v.PrecioVenta, v.StockActual, v.StockMinimo
FROM VarianteProducto v
JOIN Producto p ON p.IdProducto = v.IdProducto
ORDER BY v.IdVariante;` },
    { group: 'Control', title: 'Ultimos movimientos de stock', sql:
`SELECT TOP 30 m.IdMovimiento, m.Fecha, m.TipoMovimiento, m.Cantidad, v.SKU,
       m.IdVenta, m.IdCompra, u.NombreUsuario, m.Observacion
FROM MovimientoStock m
JOIN VarianteProducto v ON v.IdVariante = m.IdVariante
JOIN Usuario u ON u.IdUsuario = m.IdUsuario
ORDER BY m.IdMovimiento DESC;` },
    { group: 'Control', title: 'Ventas con su detalle', sql:
`SELECT ve.IdVenta, ve.Fecha, ve.Estado, ve.MedioPago, ve.Total,
       dv.NroLinea, v.SKU, dv.Cantidad, dv.PrecioUnitario, dv.Descuento
FROM Venta ve
LEFT JOIN DetalleVenta dv ON dv.IdVenta = ve.IdVenta
LEFT JOIN VarianteProducto v ON v.IdVariante = dv.IdVariante
ORDER BY ve.IdVenta DESC, dv.NroLinea;` },
    { group: 'Control', title: 'Compras con su detalle', sql:
`SELECT c.IdCompra, c.Fecha, c.Estado, c.Total, pr.RazonSocial,
       dc.NroLinea, v.SKU, dc.Cantidad, dc.CostoUnitario
FROM Compra c
JOIN Proveedor pr ON pr.IdProveedor = c.IdProveedor
LEFT JOIN DetalleCompra dc ON dc.IdCompra = c.IdCompra
LEFT JOIN VarianteProducto v ON v.IdVariante = dc.IdVariante
ORDER BY c.IdCompra DESC, dc.NroLinea;` },
    { group: 'Control', title: 'Coherencia stock vs movimientos', sql:
`-- Compara el stock actual con la suma de movimientos registrados
SELECT v.IdVariante, v.SKU, v.StockActual,
       SUM(CASE m.TipoMovimiento WHEN 'SALIDA' THEN -m.Cantidad ELSE m.Cantidad END) AS NetoMovimientos
FROM VarianteProducto v
LEFT JOIN MovimientoStock m ON m.IdVariante = v.IdVariante
GROUP BY v.IdVariante, v.SKU, v.StockActual
ORDER BY v.IdVariante;` },
    { group: 'Control', title: 'Triggers instalados', sql:
`SELECT OBJECT_NAME(parent_id) AS Tabla, name AS TriggerName, is_disabled AS Deshabilitado
FROM sys.triggers WHERE parent_class = 1 ORDER BY Tabla, name;` },
  ];

  // Escenarios que modifican datos para ejercitar los triggers (rama martin).
  // Si algo queda inconsistente: Inicio -> Reiniciar base.
  const scenario = (title, sqlText) => presets.push({ group: 'Escenarios de triggers (modifican datos)', title, sql: sqlText });
  scenario('Recibir compra PENDIENTE (entra stock)',
`-- TR_Compra_CambioEstado: PENDIENTE -> RECIBIDA genera movimientos ENTRADA
DECLARE @IdCompra INT = (SELECT MIN(IdCompra) FROM Compra WHERE Estado = 'PENDIENTE');
SELECT 'Antes' AS Momento, v.IdVariante, v.SKU, v.StockActual
FROM DetalleCompra dc JOIN VarianteProducto v ON v.IdVariante = dc.IdVariante WHERE dc.IdCompra = @IdCompra;
UPDATE Compra SET Estado = 'RECIBIDA' WHERE IdCompra = @IdCompra;
SELECT 'Despues' AS Momento, v.IdVariante, v.SKU, v.StockActual
FROM DetalleCompra dc JOIN VarianteProducto v ON v.IdVariante = dc.IdVariante WHERE dc.IdCompra = @IdCompra;`);
  scenario('Venta cargada a mano en tablas (sin SP)',
`-- TR_DetalleVenta_Insert: genera SALIDA de stock y recalcula Venta.Total
DECLARE @IdVenta INT = (SELECT ISNULL(MAX(IdVenta), 0) + 1 FROM Venta);
INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, MedioPago) VALUES (@IdVenta, 1, 2, 'EFECTIVO');
INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario, Descuento)
VALUES (@IdVenta, 1, 1, 2, 15000, 0), (@IdVenta, 2, 4, 1, 42000, 2000);
SELECT IdVenta, Total, Estado FROM Venta WHERE IdVenta = @IdVenta;
SELECT * FROM MovimientoStock WHERE IdVenta = @IdVenta;`);
  scenario('Anular la ultima venta con UPDATE (devuelve stock)',
`-- TR_Venta_CambioEstado: CONFIRMADA -> ANULADA genera DEVOLUCION
DECLARE @IdVenta INT = (SELECT MAX(IdVenta) FROM Venta WHERE Estado = 'CONFIRMADA');
UPDATE Venta SET Estado = 'ANULADA' WHERE IdVenta = @IdVenta;
SELECT * FROM MovimientoStock WHERE IdVenta = @IdVenta ORDER BY IdMovimiento;`);
  scenario('Usuario inactivo intenta vender (debe fallar 50004)',
`DECLARE @IdVenta INT = (SELECT ISNULL(MAX(IdVenta), 0) + 1 FROM Venta);
INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, MedioPago)
VALUES (@IdVenta, NULL, (SELECT TOP 1 IdUsuario FROM Usuario WHERE Activo = 0), 'EFECTIVO');`);
  scenario('Vender variante de producto inactivo (debe fallar 50011)',
`DECLARE @IdVenta INT = (SELECT ISNULL(MAX(IdVenta), 0) + 1 FROM Venta);
DECLARE @IdVariante INT = (SELECT TOP 1 v.IdVariante FROM VarianteProducto v
                           JOIN Producto p ON p.IdProducto = v.IdProducto WHERE p.Activo = 0);
BEGIN TRAN;
INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, MedioPago) VALUES (@IdVenta, NULL, 2, 'EFECTIVO');
INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario) VALUES (@IdVenta, 1, @IdVariante, 1, 1000);
COMMIT;`);
  scenario('Vender mas que el stock (debe fallar 50002)',
`DECLARE @IdVenta INT = (SELECT ISNULL(MAX(IdVenta), 0) + 1 FROM Venta);
BEGIN TRAN;
INSERT INTO Venta (IdVenta, IdCliente, IdUsuario, MedioPago) VALUES (@IdVenta, NULL, 2, 'EFECTIVO');
INSERT INTO DetalleVenta (IdVenta, NroLinea, IdVariante, Cantidad, PrecioUnitario) VALUES (@IdVenta, 1, 5, 999, 42000);
COMMIT;`);
  scenario('Borrar una venta (debe fallar 50050)',
`DELETE FROM Venta WHERE IdVenta = (SELECT MIN(IdVenta) FROM Venta);`);
  scenario('Editar un movimiento de stock (debe fallar 50003)',
`UPDATE MovimientoStock SET Cantidad = Cantidad + 1 WHERE IdMovimiento = (SELECT MIN(IdMovimiento) FROM MovimientoStock);`);
  scenario('Cambiar precio de una variante (HistorialPrecio)',
`-- TR_Variante_HistorialPrecio
UPDATE VarianteProducto SET PrecioVenta = PrecioVenta * 1.10 WHERE IdVariante = 1;
SELECT * FROM HistorialPrecio ORDER BY IdHistorial DESC;`);
  scenario('Stock cruza el minimo (AlertaStock)',
`-- TR_Variante_AlertaStock: deja la variante 2 justo en su stock minimo con una SALIDA
DECLARE @Cant INT = (SELECT StockActual - StockMinimo FROM VarianteProducto WHERE IdVariante = 2);
IF @Cant > 0
    INSERT INTO MovimientoStock (IdMovimiento, IdVariante, IdUsuario, TipoMovimiento, Cantidad, Observacion)
    VALUES ((SELECT ISNULL(MAX(IdMovimiento), 0) + 1 FROM MovimientoStock), 2, 1, 'SALIDA', @Cant, 'Prueba alerta');
SELECT IdVariante, StockActual, StockMinimo FROM VarianteProducto WHERE IdVariante = 2;
SELECT * FROM AlertaStock ORDER BY IdAlerta DESC;`);
  scenario('Agregar linea a compra ya RECIBIDA (debe fallar 50040)',
`INSERT INTO DetalleCompra (IdCompra, NroLinea, IdVariante, Cantidad, CostoUnitario)
VALUES ((SELECT MIN(IdCompra) FROM Compra WHERE Estado = 'RECIBIDA'), 99, 8, 1, 100);`);

  const file = 'sql/Subconsultas.sql';
  if (fs.existsSync(path.join(ROOT, file))) {
    const chunks = readScript(file).split(/;\s*(?:\r?\n|$)/).map((c) => c.trim()).filter(Boolean);
    for (const chunk of chunks) {
      const comment = chunk.split(/\r?\n/).find((line) => line.trim().startsWith('--'));
      presets.push({
        group: 'Subconsultas.sql',
        title: comment ? comment.replace(/^\s*--\s*/, '') : chunk.slice(0, 60),
        sql: chunk + ';',
      });
    }
  }
  return presets;
}));

app.get('/api/scripts', api(async () => SCRIPTS.map((s) => ({
  ...s,
  exists: fs.existsSync(path.join(ROOT, s.file)),
}))));

// Recrea la base ejecutando los scripts del repo en orden. Reporta errores por lote sin cortar.
app.post('/api/reset', api(async (req) => {
  const selected = new Set(req.body.files || SCRIPTS.map((s) => s.file));
  const report = [];
  await closePool();

  for (const script of SCRIPTS) {
    if (!script.required && !selected.has(script.file)) continue;
    const entry = { file: script.file, label: script.label, batches: 0, errors: [] };
    report.push(entry);
    if (!fs.existsSync(path.join(ROOT, script.file))) {
      entry.errors.push('El archivo no existe en esta rama');
      continue;
    }
    // init_db necesita master (borra y crea la base). El resto corre contra la base nueva.
    const pool = await new sql.ConnectionPool({
      ...dbConfig(script.required ? 'master' : DB_NAME),
      pool: { max: 1, min: 0 },
    }).connect();
    try {
      for (const batch of splitBatches(readScript(script.file))) {
        entry.batches++;
        try {
          await pool.request().batch(batch);
        } catch (err) {
          entry.errors.push(formatError(err).error);
        }
      }
    } finally {
      await pool.close();
    }
    if (script.required && entry.errors.length) break;
  }
  return { report };
}));

const port = parseInt(process.env.PORT || '3000', 10);
app.listen(port, '127.0.0.1', () => {
  console.log(`Frontend SIAM en http://localhost:${port}`);
});
