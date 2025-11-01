// Configurație PostgreSQL
// Sistem simplu de priorități:
// 1. Variabile de mediu (cea mai mare prioritate)
// 2. config.local.js (dacă nu există variabile de mediu)

const fs = require('fs');
const path = require('path');

// Verifică dacă există variabile de mediu setate
const hasEnvVars = process.env.POSTGRES_HOST || 
                   process.env.POSTGRES_PORT || 
                   process.env.POSTGRES_DATABASE || 
                   process.env.POSTGRES_USER || 
                   process.env.POSTGRES_PASSWORD;

let config;

if (hasEnvVars) {
    // Dacă există variabile de mediu, folosește-le
    console.log('[POSTGRES] Configurație încărcată din variabile de mediu');
    config = {
        host: process.env.POSTGRES_HOST,
        port: parseInt(process.env.POSTGRES_PORT) || 5432,
        database: process.env.POSTGRES_DATABASE,
        user: process.env.POSTGRES_USER,
        password: process.env.POSTGRES_PASSWORD,
        ssl: process.env.POSTGRES_SSL === 'true' ? { rejectUnauthorized: false } : false,
        max: parseInt(process.env.POSTGRES_MAX) || 20,
        idleTimeoutMillis: parseInt(process.env.POSTGRES_IDLE_TIMEOUT) || 30000,
        connectionTimeoutMillis: parseInt(process.env.POSTGRES_CONNECTION_TIMEOUT) || 2000,
    };
} else {
    // Dacă NU există variabile de mediu, încarcă din config.local.js
    const localConfigPath = path.join(__dirname, 'config.local.js');
    
    if (fs.existsSync(localConfigPath)) {
        try {
            config = require(localConfigPath);
            console.log('[POSTGRES] Configurație încărcată din config.local.js');
        } catch (error) {
            console.error('[POSTGRES] Eroare la încărcarea config.local.js:', error.message);
            throw new Error('Nu s-a putut încărca configurația! Verifică config.local.js sau setează variabile de mediu.');
        }
    } else {
        console.error('[POSTGRES] Nu există variabile de mediu și nici config.local.js!');
        throw new Error('Configurație lipsă! Fie setează variabile de mediu, fie creează config.local.js din config.local.js.example');
    }
}

module.exports = config;
