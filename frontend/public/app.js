'use strict';

const state = { meta: null, presets: [], editing: null };
const $ = (sel) => document.querySelector(sel);

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------
async function apiCall(url, body) {
  const options = body === undefined ? {} : {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
  const response = await fetch(url, options);
  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data.error || 'Error desconocido');
    error.number = data.number;
    throw error;
  }
  return data;
}

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === 'class') node.className = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else if (value !== undefined && value !== null && value !== false) node.setAttribute(key, value === true ? '' : value);
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function toast(text) {
  const t = $('#toast');
  t.textContent = text;
  t.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => t.classList.remove('show'), 2500);
}

function message(kind, text) {
  return el('div', { class: 'msg ' + kind }, text);
}

function errorMessage(err) {
  return message('err', (err.number ? `Error ${err.number}: ` : '') + err.message);
}

// Las fechas llegan como ISO (UTC). Se muestran tal cual las guarda SQL Server.
function formatValue(value) {
  if (value === null || value === undefined) return 'NULL';
  if (typeof value === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d/.test(value)) {
    return value.replace('T', ' ').replace(/\.\d+Z$|Z$/, '').replace(/\.000$/, '');
  }
  if (typeof value === 'boolean') return value ? '1' : '0';
  return String(value);
}

function renderTable(rows, { actions } = {}) {
  if (!rows || !rows.length) return el('div', { class: 'meta' }, 'Sin filas.');
  const columns = Object.keys(rows[0]);
  return el('div', { class: 'table-wrap' },
    el('table', {},
      el('thead', {}, el('tr', {}, actions ? el('th', {}, '') : null, columns.map((c) => el('th', {}, c)))),
      el('tbody', {}, rows.map((row) => el('tr', {},
        actions ? el('td', {}, actions(row)) : null,
        columns.map((c) => el('td', {
          class: row[c] === null ? 'null' : typeof row[c] === 'number' ? 'num' : '',
        }, formatValue(row[c]))),
      ))),
    ));
}

async function withBusy(button, fn) {
  if (button) button.disabled = true;
  try {
    return await fn();
  } finally {
    if (button) button.disabled = false;
  }
}

// ---------------------------------------------------------------------------
// Navegacion
// ---------------------------------------------------------------------------
document.querySelectorAll('nav button').forEach((button) => {
  button.addEventListener('click', () => {
    document.querySelectorAll('nav button').forEach((b) => b.classList.toggle('active', b === button));
    document.querySelectorAll('.page').forEach((p) => p.classList.toggle('active', p.id === 'page-' + button.dataset.page));
  });
});

// ---------------------------------------------------------------------------
// Estado y metadatos
// ---------------------------------------------------------------------------
async function refreshAll() {
  const status = $('#status');
  try {
    const info = await apiCall('/api/status');
    if (info.dbMissing) {
      status.className = 'status';
      status.textContent = `Conectado al servidor, pero la base ${info.db} todavía no existe. Tocá "Borrar y recrear la base".`;
      state.meta = null;
      renderSummary();
      return;
    }
    status.className = 'status ok';
    status.textContent = `Conectado a ${info.db} · ${info.version.split('\n')[0].replace('Microsoft ', '')}`;
  } catch (err) {
    status.className = 'status err';
    status.textContent = 'Sin conexión: ' + err.message + ' — revisá .env o reiniciá la base.';
    state.meta = null;
    renderSummary();
    return;
  }
  state.meta = await apiCall('/api/meta');
  state.presets = await apiCall('/api/presets').catch(() => []);
  renderSummary();
  fillSelect($('#table-select'), state.meta.tables.map((t) => t.name));
  fillSelect($('#proc-select'), state.meta.procedures.map((p) => p.name));
  fillSelect($('#view-select'), state.meta.views);
  renderPresets();
  await loadTable();
  renderProcForm();
  checkMissingViews();
}

function fillSelect(select, options) {
  const previous = select.value;
  select.replaceChildren(...options.map((o) => el('option', { value: o }, o)));
  if (options.includes(previous)) select.value = previous;
}

function renderSummary() {
  const target = $('#summary');
  if (!state.meta) {
    target.replaceChildren(message('warn', 'No hay conexión con la base. Si todavía no existe, usá "Borrar y recrear la base".'));
    return;
  }
  const triggers = state.meta.tables.reduce((n, t) => n + (t.triggers || []).length, 0);
  target.replaceChildren(
    el('div', { class: 'badges' },
      el('span', { class: 'badge' }, `${state.meta.tables.length} tablas`),
      el('span', { class: 'badge' }, `${state.meta.views.length} vistas`),
      el('span', { class: 'badge' }, `${state.meta.procedures.length} procedimientos`),
      el('span', { class: 'badge' }, `${triggers} triggers`),
    ),
    el('div', { class: 'meta' }, 'Procedimientos: ' + (state.meta.procedures.map((p) => p.name).join(', ') || '—')),
    el('div', { class: 'meta' }, 'Vistas: ' + (state.meta.views.join(', ') || '—')),
  );
}

// ---------------------------------------------------------------------------
// Reiniciar base
// ---------------------------------------------------------------------------
async function loadScripts() {
  const scripts = await apiCall('/api/scripts');
  $('#scripts').replaceChildren(...scripts.map((s) => el('label', { class: s.exists ? '' : 'missing' },
    el('input', { type: 'checkbox', value: s.file, checked: s.exists, disabled: s.required || !s.exists }),
    el('span', {}, s.label), el('code', {}, s.file), s.exists ? null : el('span', {}, '(no está en esta rama)'),
  )));
}

$('#btn-reset').addEventListener('click', (e) => withBusy(e.target, async () => {
  if (!confirm('Esto borra la base SIAM y la vuelve a crear con los scripts seleccionados. ¿Continuar?')) return;
  const files = [...document.querySelectorAll('#scripts input:checked')].map((i) => i.value);
  const target = $('#reset-report');
  target.replaceChildren(message('warn', 'Ejecutando scripts…'));
  try {
    const { report } = await apiCall('/api/reset', { files });
    const failed = report.filter((r) => r.errors.length).length;
    target.replaceChildren(
      message(failed ? 'warn' : 'ok', failed
        ? `Base recreada con errores en ${failed} script(s). Revisá el detalle.`
        : 'Base recreada sin errores.'),
      ...report.map((r) => el('div', { class: 'report-line' },
        el('b', {}, r.errors.length ? '✗ ' : '✓ '), el('code', {}, r.file), ` · ${r.batches} lote(s)`,
        r.errors.map((e) => message('err', e)),
      )),
    );
    await refreshAll();
  } catch (err) {
    target.replaceChildren(errorMessage(err));
  }
}));

// ---------------------------------------------------------------------------
// Tablas
// ---------------------------------------------------------------------------
const LABEL_COLUMNS = ['Nombre', 'SKU', 'RazonSocial', 'NombreUsuario', 'Descripcion', 'Apellido', 'NroComprobante', 'Estado'];
const refCache = {};

function currentTable() {
  return state.meta && state.meta.tables.find((t) => t.name === $('#table-select').value);
}

async function loadTable() {
  const table = currentTable();
  $('#table-form').replaceChildren();
  $('#table-result').replaceChildren();
  if (!table) {
    $('#table-grid').replaceChildren();
    return;
  }
  $('#table-triggers').replaceChildren(...(table.triggers || []).map((t) =>
    el('span', { class: 'badge', title: `${t.timing} ${t.events}` }, `⚡ ${t.name} (${t.timing} ${t.events})`)));
  try {
    const { rows, total } = await apiCall('/api/table/' + encodeURIComponent(table.name));
    const pk = table.columns.filter((c) => c.pk);
    $('#table-grid').replaceChildren(
      el('div', { class: 'meta' }, `${total} fila(s) · mostrando ${rows.length} · PK: ${pk.map((c) => c.name).join(', ')}`),
      renderTable(rows, {
        actions: (row) => el('span', {},
          el('button', { class: 'small', onclick: () => openForm(table, row) }, 'Editar'), ' ',
          el('button', { class: 'small danger', onclick: () => deleteRow(table, row) }, 'Borrar'),
        ),
      }),
    );
  } catch (err) {
    $('#table-grid').replaceChildren(errorMessage(err));
  }
}

async function refOptions(ref) {
  if (!refCache[ref.table]) {
    const { rows } = await apiCall('/api/table/' + encodeURIComponent(ref.table) + '?limit=2000');
    refCache[ref.table] = rows;
  }
  return refCache[ref.table].map((row) => {
    const labelCol = LABEL_COLUMNS.find((c) => c in row && c !== ref.column);
    return { value: row[ref.column], label: labelCol ? `${row[ref.column]} · ${row[labelCol]}` : String(row[ref.column]) };
  }).sort((a, b) => (a.value > b.value ? 1 : -1));
}

function inputValue(col, value) {
  if (value === null || value === undefined) return '';
  return formatValue(value);
}

async function openForm(table, row) {
  Object.keys(refCache).forEach((k) => delete refCache[k]);
  const editing = !!row;
  const fields = [];
  for (const col of table.columns) {
    if (col.identity || col.computed) continue;
    const id = 'f_' + col.name;
    let input;
    if (col.ref) {
      const options = await refOptions(col.ref).catch(() => []);
      input = el('select', { id },
        el('option', { value: '' }, editing ? '(NULL)' : '(sin valor)'),
        options.map((o) => el('option', { value: o.value }, o.label)));
      input.value = editing && row[col.name] !== null ? String(row[col.name]) : '';
    } else {
      input = el('input', { id, value: editing ? inputValue(col, row[col.name]) : '', placeholder: col.defaultValue ? `default ${col.defaultValue}` : '' });
    }
    if (editing && col.pk) input.disabled = true;
    const type = col.type + (['varchar', 'nvarchar', 'char'].includes(col.type) ? `(${col.maxLength === -1 ? 'max' : col.type === 'nvarchar' ? col.maxLength / 2 : col.maxLength})` : col.type === 'decimal' ? `(${col.precision},${col.scale})` : '');
    fields.push(el('div', { class: 'field' },
      el('label', { for: id }, el('b', {}, col.name), ` ${type}${col.pk ? ' · PK' : ''}${col.nullable ? '' : ' · NOT NULL'}${col.ref ? ` → ${col.ref.table}` : ''}`),
      input));
  }

  const save = el('button', { class: 'primary' }, editing ? 'Guardar cambios' : 'Insertar');
  save.addEventListener('click', () => withBusy(save, async () => {
    const values = {};
    for (const col of table.columns) {
      if (col.identity || col.computed || (editing && col.pk)) continue;
      const raw = $('#f_' + CSS.escape(col.name)).value;
      if (editing) {
        const original = inputValue(col, row[col.name]);
        if (raw !== original) values[col.name] = raw === '' ? null : raw;
      } else if (raw !== '') {
        values[col.name] = raw;
      }
    }
    try {
      const url = '/api/table/' + encodeURIComponent(table.name) + (editing ? '/update' : '/insert');
      const body = editing ? { key: keyOf(table, row), values } : { values };
      const result = await apiCall(url, body);
      await loadTable();
      showTableResult('ok', `${editing ? 'Actualizado' : 'Insertado'} · filas afectadas: ${result.rowsAffected.join(', ')}`, result.statement);
    } catch (err) {
      showTableResult('err', (err.number ? `Error ${err.number}: ` : '') + err.message);
    }
  }));

  $('#table-form').replaceChildren(el('div', { class: 'card' },
    el('h2', {}, editing ? `Editar ${table.name}` : `Nuevo registro en ${table.name}`),
    el('p', { class: 'hint' }, editing
      ? 'Solo se envían los campos que cambies. Dejar vacío = NULL.'
      : 'Los campos vacíos no se envían (aplica el DEFAULT de la columna).'),
    el('div', { class: 'form-grid' }, fields),
    el('div', { class: 'form-actions' }, save, el('button', { onclick: () => $('#table-form').replaceChildren() }, 'Cancelar')),
  ));
  $('#table-form').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function keyOf(table, row) {
  const key = {};
  for (const col of table.columns.filter((c) => c.pk)) key[col.name] = inputValue(col, row[col.name]);
  return key;
}

function showTableResult(kind, text, statement) {
  $('#table-result').replaceChildren(message(kind, text + (statement ? '\n' + statement : '')));
}

async function deleteRow(table, row) {
  const key = keyOf(table, row);
  if (!confirm(`¿Borrar ${table.name} ${JSON.stringify(key)}?`)) return;
  try {
    const result = await apiCall('/api/table/' + encodeURIComponent(table.name) + '/delete', { key });
    await loadTable();
    showTableResult('ok', `Borrado · filas afectadas: ${result.rowsAffected.join(', ')}`);
  } catch (err) {
    showTableResult('err', (err.number ? `Error ${err.number}: ` : '') + err.message);
  }
}

$('#table-select').addEventListener('change', loadTable);
$('#btn-table-refresh').addEventListener('click', loadTable);
$('#btn-table-new').addEventListener('click', () => { const t = currentTable(); if (t) openForm(t, null); });

// ---------------------------------------------------------------------------
// Procedimientos
// ---------------------------------------------------------------------------
function currentProc() {
  return state.meta && state.meta.procedures.find((p) => p.name === $('#proc-select').value);
}

function defaultFromDefinition(definition) {
  if (!definition) return '';
  return definition.replace(/^\(+|\)+$/g, '').replace(/^'(.*)'$/, '$1');
}

function tvpRow(param) {
  return el('tr', {}, param.tableType.map((col) =>
    el('td', {}, el('input', { 'data-col': col.name, value: defaultFromDefinition(col.defaultValue), placeholder: col.type }))),
  el('td', {}, el('button', { class: 'small danger', onclick: (e) => e.target.closest('tr').remove() }, '✕')));
}

function renderProcForm() {
  const proc = currentProc();
  const form = $('#proc-form');
  $('#proc-result').replaceChildren();
  $('#proc-effect').replaceChildren();
  if (!proc) {
    form.replaceChildren(message('warn', 'No hay procedimientos en la base.'));
    return;
  }
  const scalar = [];
  const tables = [];
  for (const param of proc.params) {
    if (param.tableType) {
      const body = el('tbody', {}, tvpRow(param));
      tables.push(el('div', { class: 'tvp', 'data-param': param.name },
        el('h3', {}, `@${param.name} (${param.type}) — una fila por línea`),
        el('table', {}, el('thead', {}, el('tr', {}, param.tableType.map((c) => el('th', {}, c.name)), el('th', {}, ''))), body),
        el('button', { class: 'small', onclick: () => body.append(tvpRow(param)) }, '+ Agregar línea')));
    } else if (!param.output) {
      const id = 'p_' + param.name;
      let input = el('input', { id, 'data-param': param.name, placeholder: param.type });
      if (param.name === 'MedioPago') {
        input = el('select', { id, 'data-param': param.name },
          ['EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA'].map((m) => el('option', { value: m }, m)));
      }
      scalar.push(el('div', { class: 'field' }, el('label', { for: id }, el('b', {}, '@' + param.name), ' ' + param.type), input));
    }
  }
  const run = el('button', { class: 'primary' }, `EXEC ${proc.name}`);
  run.addEventListener('click', () => withBusy(run, () => executeProc(proc)));
  form.replaceChildren(el('h2', {}, proc.name), el('div', { class: 'form-grid' }, scalar), ...tables, run);
}

async function executeProc(proc) {
  const values = {};
  document.querySelectorAll('#proc-form [data-param]').forEach((node) => {
    if (node.classList.contains('tvp')) {
      values[node.dataset.param] = [...node.querySelectorAll('tbody tr')].map((tr) => {
        const row = {};
        tr.querySelectorAll('input').forEach((i) => { row[i.dataset.col] = i.value; });
        return row;
      });
    } else if (node.value !== '') {
      values[node.dataset.param] = node.value;
    }
  });

  const before = await effectSnapshot().catch(() => null);
  const target = $('#proc-result');
  try {
    const result = await apiCall('/api/procedure/' + encodeURIComponent(proc.name), { values });
    target.replaceChildren(
      message('ok', `Ejecutado · return ${result.returnValue}` + (result.messages.length ? '\n' + result.messages.join('\n') : '')),
      ...result.recordsets.map((rs) => renderTable(rs)));
  } catch (err) {
    target.replaceChildren(errorMessage(err));
  }
  const after = await effectSnapshot().catch(() => null);
  renderEffect(before, after);
}

// Foto del stock y movimientos para ver que hizo el SP (y los triggers que disparo)
async function effectSnapshot() {
  const { results } = await apiCall('/api/query', { sql:
    `SELECT IdVariante, SKU, StockActual FROM VarianteProducto ORDER BY IdVariante;
     SELECT ISNULL(MAX(IdMovimiento), 0) AS maxMov FROM MovimientoStock;` });
  if (results[0].error) throw new Error(results[0].error);
  return { stock: results[0].recordsets[0], maxMov: results[0].recordsets[1][0].maxMov };
}

async function renderEffect(before, after) {
  const target = $('#proc-effect');
  if (!before || !after) {
    target.replaceChildren();
    return;
  }
  const changes = after.stock.map((row) => {
    const prev = before.stock.find((b) => b.IdVariante === row.IdVariante);
    return { IdVariante: row.IdVariante, SKU: row.SKU, StockAntes: prev ? prev.StockActual : null, StockDespues: row.StockActual, Diferencia: row.StockActual - (prev ? prev.StockActual : 0) };
  }).filter((r) => r.Diferencia !== 0);
  const { results } = await apiCall('/api/query', { sql:
    `SELECT IdMovimiento, TipoMovimiento, Cantidad, IdVariante, IdVenta, IdCompra, Observacion
     FROM MovimientoStock WHERE IdMovimiento > ${Number(before.maxMov)} ORDER BY IdMovimiento;` });
  target.replaceChildren(el('div', { class: 'card' },
    el('h2', {}, 'Efecto en la base'),
    el('h3', {}, 'Cambios de stock'),
    changes.length ? renderTable(changes) : el('div', { class: 'meta' }, 'Sin cambios de stock.'),
    el('h3', {}, 'Movimientos de stock nuevos'),
    results[0].error ? message('err', results[0].error) : renderTable(results[0].recordsets[0]),
  ));
}

$('#proc-select').addEventListener('change', renderProcForm);

// ---------------------------------------------------------------------------
// Vistas
// ---------------------------------------------------------------------------
$('#btn-view-run').addEventListener('click', (e) => withBusy(e.target, async () => {
  const name = $('#view-select').value;
  if (!name) return;
  try {
    const { rows } = await apiCall('/api/view/' + encodeURIComponent(name));
    $('#view-result').replaceChildren(el('div', { class: 'meta' }, `${rows.length} fila(s)`), renderTable(rows));
  } catch (err) {
    $('#view-result').replaceChildren(errorMessage(err));
  }
}));

// Avisa si vistas.sql define vistas que no llegaron a crearse (error al reiniciar la base)
function checkMissingViews() {
  const expected = ['vw_StockVariate', 'vw_VentasDetalladas', 'vw_ProductosPremium'];
  const missing = expected.filter((v) => !state.meta.views.includes(v));
  $('#view-missing').replaceChildren(missing.length
    ? message('warn', `Definidas en sql/vistas.sql pero no existen en la base: ${missing.join(', ')}. Mirá el reporte de "Reiniciar base".`)
    : '');
}

// ---------------------------------------------------------------------------
// Consola y escenarios
// ---------------------------------------------------------------------------
function renderPresets() {
  const select = $('#preset-select');
  const groups = {};
  state.presets.forEach((p, i) => (groups[p.group] ||= []).push(el('option', { value: i }, p.title)));
  select.replaceChildren(el('option', { value: '' }, '— Elegí una consulta o escenario —'),
    ...Object.entries(groups).map(([group, options]) => el('optgroup', { label: group }, options)));
}

$('#preset-select').addEventListener('change', (e) => {
  const preset = state.presets[e.target.value];
  if (preset) $('#sql').value = preset.sql;
});

async function runQuery() {
  const button = $('#btn-run');
  await withBusy(button, async () => {
    const target = $('#query-result');
    try {
      const { results } = await apiCall('/api/query', { sql: $('#sql').value });
      const nodes = [];
      results.forEach((r, i) => {
        if (results.length > 1) nodes.push(el('h3', {}, `Lote ${i + 1}`));
        if (r.messages && r.messages.length) nodes.push(message('warn', r.messages.join('\n')));
        if (r.error) {
          nodes.push(message('err', (r.number ? `Error ${r.number}: ` : '') + r.error));
          return;
        }
        r.recordsets.forEach((rs) => nodes.push(el('div', { class: 'meta' }, `${rs.length} fila(s)`), renderTable(rs)));
        if (!r.recordsets.length) nodes.push(message('ok', `OK · filas afectadas: ${r.rowsAffected.join(', ') || 0}`));
      });
      target.replaceChildren(...nodes);
    } catch (err) {
      target.replaceChildren(errorMessage(err));
    }
  });
}

$('#btn-run').addEventListener('click', runQuery);
$('#sql').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    runQuery();
  }
});

// ---------------------------------------------------------------------------
loadScripts().catch((err) => $('#scripts').replaceChildren(errorMessage(err)));
refreshAll().catch((err) => toast(err.message));
