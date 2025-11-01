// Verifică dependențele înainte de a continua
const checkDependencies = require('./check_dependencies');

if (!checkDependencies()) {
    console.error('[POSTGRES] ❌ Resursa nu poate porni fără dependențe!');
    console.error('[POSTGRES] Rulează: npm install');
    throw new Error('Dependențele nu sunt instalate! Rulează npm install în folderul resursei.');
}

const { Pool } = require('pg');
const config = require('./config');
const { initialize } = require('./init');

// Creează un pool de conexiuni
const pool = new Pool(config);

// Inițializează baza de date la pornirea resursei
let isInitialized = false;

async function start() {
    if (isInitialized) return;
    
    isInitialized = true;
    await initialize(pool);
}

// Gestionează erorile pool-ului
pool.on('error', (err) => {
    console.error('[POSTGRES] Eroare neașteptată pe client inactiv', err);
});

/**
 * Execută o interogare cu parametri
 * @param {string} queryText - String SQL query
 * @param {Array} params - Parametrii interogării
 * @returns {Promise<Object>} Rezultatul interogării
 */
async function query(queryText, params = []) {
    const start = Date.now();
    try {
        const result = await pool.query(queryText, params);
        const duration = Date.now() - start;
        console.log(`[POSTGRES] Interogare executată (${duration}ms):`, queryText.substring(0, 100));
        return result;
    } catch (error) {
        console.error('[POSTGRES] Eroare la interogare:', error.message);
        console.error('[POSTGRES] Interogare:', queryText);
        throw error;
    }
}

/**
 * Execută o tranzacție
 * @param {Function} callback - Funcția callback care primește un client
 * @returns {Promise<any>} Rezultatul tranzacției
 */
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

/**
 * Obține un singur rând
 * @param {string} queryText - String SQL query
 * @param {Array} params - Parametrii interogării
 * @returns {Promise<Object|null>} Primul rând sau null
 */
async function queryOne(queryText, params = []) {
    const result = await query(queryText, params);
    return result.rows[0] || null;
}

/**
 * Obține toate rândurile
 * @param {string} queryText - String SQL query
 * @param {Array} params - Parametrii interogării
 * @returns {Promise<Array>} Array cu toate rândurile
 */
async function queryAll(queryText, params = []) {
    const result = await query(queryText, params);
    return result.rows;
}

/**
 * Inserează și returnează rândul inserat
 * @param {string} table - Numele tabelei
 * @param {Object} data - Datele de inserat
 * @param {string} returnColumn - Coloana de returnat (implicit: 'id')
 * @returns {Promise<Object>} Rândul inserat
 */
async function insert(table, data, returnColumn = 'id') {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const placeholders = values.map((_, i) => `$${i + 1}`).join(', ');
    const queryText = `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders}) RETURNING *`;
    const result = await query(queryText, values);
    return result.rows[0];
}

/**
 * Actualizează rânduri și returnează rândurile actualizate
 * @param {string} table - Numele tabelei
 * @param {Object} data - Datele de actualizat
 * @param {string} where - Clauza WHERE
 * @param {Array} whereParams - Parametrii pentru clauza WHERE
 * @returns {Promise<Array>} Rânduri actualizate
 */
async function update(table, data, where, whereParams = []) {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const setClause = columns.map((col, i) => `${col} = $${i + 1}`).join(', ');
    const queryText = `UPDATE ${table} SET ${setClause} WHERE ${where} RETURNING *`;
    const result = await query(queryText, [...values, ...whereParams]);
    return result.rows;
}

/**
 * Șterge rânduri
 * @param {string} table - Numele tabelei
 * @param {string} where - Clauza WHERE
 * @param {Array} params - Parametrii pentru clauza WHERE
 * @returns {Promise<number>} Numărul de rânduri șterse
 */
async function deleteRows(table, where, params = []) {
    const queryText = `DELETE FROM ${table} WHERE ${where} RETURNING *`;
    const result = await query(queryText, params);
    return result.rowCount;
}

// Exportă funcțiile către FiveM
exports('query', query);
exports('queryOne', queryOne);
exports('queryAll', queryAll);
exports('insert', insert);
exports('update', update);
exports('delete', deleteRows);
exports('transaction', transaction);
exports('pool', () => pool);
exports('isReady', () => isInitialized);

// Pornește inițializarea
start().catch(err => {
    console.error('[POSTGRES] Eroare la inițializare:', err);
});

// Curăță la oprirea resursei
AddEventHandler('onResourceStop', (resourceName) => {
    if (resourceName === GetCurrentResourceName()) {
        pool.end(() => {
            console.log('[POSTGRES] Pool-ul de conexiuni închis');
        });
    }
});

console.log('[POSTGRES] Resursa se inițializează... Folosește exports pentru a interacționa cu baza de date.');

