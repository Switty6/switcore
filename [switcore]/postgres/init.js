// Sistem de inițializare pentru PostgreSQL
const { Pool } = require('pg');

/**
 * Verifică conexiunea la baza de date
 */
async function checkConnection(pool) {
    try {
        const result = await pool.query('SELECT NOW() as now, version() as version');
        console.log('[POSTGRES] ✓ Conectat cu succes la baza de date PostgreSQL');
        console.log(`[POSTGRES] ✓ Timp baza de date: ${result.rows[0].now}`);
        console.log(`[POSTGRES] ✓ Versiune PostgreSQL: ${result.rows[0].version.split(',')[0]}`);
        return true;
    } catch (error) {
        console.error('[POSTGRES] ✗ Eșec la conectarea la baza de date:', error.message);
        return false;
    }
}

/**
 * Inițializează baza de date (doar verifică conexiunea)
 */
async function initialize(pool) {
    console.log('[POSTGRES] Verificare conexiune...');
    
    const connected = await checkConnection(pool);
    if (!connected) {
        console.error('[POSTGRES] Nu s-a putut conecta la baza de date. Verifică config.js');
        return false;
    }

    console.log('[POSTGRES] ✓ Baza de date este gata de utilizare');
    return true;
}

module.exports = {
    initialize,
    checkConnection
};

