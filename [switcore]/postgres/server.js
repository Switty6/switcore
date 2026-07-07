const checkDependencies = require('./check_dependencies');

if (!checkDependencies()) {
    console.error('[POSTGRES] ❌ Resursa nu poate porni fără dependențe!');
    console.error('[POSTGRES] Rulează: npm install');
    throw new Error('Dependențele nu sunt instalate! Rulează npm install în folderul resursei.');
}

const { Pool, types } = require('pg');

types.setTypeParser(1114, str => str);
types.setTypeParser(1184, str => str);
types.setTypeParser(1082, str => str);

const config = require('./config');
const { initialize, applySchemaForResource, applySchemasAutomatically } = require('./init');

const QUERY_DEBUG    = config.queryDebug    ?? false;
const QUERY_WARN_MS  = config.queryWarnMs   ?? 150;
const QUERY_CRIT_MS  = config.queryCriticalMs ?? 500;

const pool = new Pool(config);

let isInitialized = false;
let isInitializing = false;

async function start() {
    if (isInitialized || isInitializing) return;

    isInitializing = true;
    await initialize(pool);
    isInitialized = true;
    isInitializing = false;

    emit('postgres:ready');
    console.log('[POSTGRES] ✓ Eveniment postgres:ready emis');
}

pool.on('error', (err) => {
    console.error('[POSTGRES] Eroare neașteptată pe client inactiv', err);
});

function sanitizeParam(v) {
    if (v === false || v === null || v === undefined || typeof v === 'function') return null;
    return v;
}

function normalizeParams(params) {
    if (params === null || params === undefined) return [];
    if (Array.isArray(params)) return params.map(sanitizeParam);

    if (typeof params === 'object') {
        const keys = Object.keys(params);
        if (keys.length === 0) return [];

        const isSparseArray = keys.every(key => !isNaN(parseInt(key)));
        if (isSparseArray) {
            const maxIndex = Math.max(...keys.map(k => parseInt(k)));
            const arr = [];
            for (let i = 1; i <= maxIndex; i++) {
                const raw = params[String(i)] ?? params[i];
                arr.push(sanitizeParam(raw));
            }
            return arr;
        }
    }

    return [params];
}

async function query(queryText, params = []) {
    params = normalizeParams(params);
    const start = Date.now();
    try {
        const result = await pool.query(queryText, params);
        const ms = Date.now() - start;
        const preview = queryText.substring(0, 120);

        if (ms >= QUERY_CRIT_MS) {
            console.error(`\x1b[31m[POSTGRES] CRITIC ${ms}ms: ${preview}\x1b[0m`);
        } else if (ms >= QUERY_WARN_MS) {
            console.warn(`\x1b[33m[POSTGRES] LENT ${ms}ms: ${preview}\x1b[0m`);
        } else if (QUERY_DEBUG) {
            console.log(`[POSTGRES] ${ms}ms: ${preview}`);
        }

        return result;
    } catch (error) {
        console.error('[POSTGRES] Eroare la interogare:', error.message);
        console.error('[POSTGRES] Interogare:', queryText);
        throw error;
    }
}

async function transaction(callback) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        await client.query('ROLLBACK');
        console.error('[POSTGRES] Eroare tranzacție:', error.message);
        throw error;
    } finally {
        client.release();
    }
}

async function queryOne(queryText, params = []) {
    const result = await query(queryText, params);
    return result.rows[0] || null;
}

async function queryAll(queryText, params = []) {
    const result = await query(queryText, params);
    return result.rows;
}

async function insert(table, data, returnColumn = 'id') {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const placeholders = values.map((_, i) => `$${i + 1}`).join(', ');
    const queryText = `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders}) RETURNING *`;
    const result = await query(queryText, values);
    return result.rows[0];
}

async function update(table, data, where, whereParams = []) {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const setClause = columns.map((col, i) => `${col} = $${i + 1}`).join(', ');
    const queryText = `UPDATE ${table} SET ${setClause} WHERE ${where} RETURNING *`;
    const result = await query(queryText, [...values, ...whereParams]);
    return result.rows;
}

async function deleteRows(table, where, params = []) {
    const queryText = `DELETE FROM ${table} WHERE ${where} RETURNING *`;
    const result = await query(queryText, params);
    return result.rowCount;
}

exports('query', query);
exports('queryOne', queryOne);
exports('queryAll', queryAll);
exports('insert', insert);
exports('update', update);
exports('delete', deleteRows);
exports('transaction', transaction);
exports('pool', () => pool);
exports('isReady', () => isInitialized);
exports('applySchema', (resourceName) => applySchemaForResource(pool, resourceName));
exports('applySchemasAll', () => applySchemasAutomatically(pool));

start().catch(err => {
    console.error('[POSTGRES] Eroare la inițializare:', err);
});
AddEventHandler('onResourceStop', (resourceName) => {
    if (resourceName === GetCurrentResourceName()) {
        pool.end(() => {
            console.log('[POSTGRES] Pool-ul de conexiuni închis');
        });
    }
});

console.log('[POSTGRES] Resursa se inițializează... Folosește exports pentru a interacționa cu baza de date.');
