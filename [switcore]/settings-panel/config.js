// JWT, DB password, parola admin) NU sunt in acest fisier!!!
// Se citesc din FiveM convars (setat in server.cfg) sau env
//  Daca lipsesc, JWT secret se genereaza random si se persista in
// .jwt-secret pentru sesiuni stabile intre restarturi.
//
// In server.cfg:
//   set switcore_panel_jwt_secret "<random long string>" (trebuie sa fie random si lung minim 32 caractere!!!)
//   set switcore_panel_db_password "<password>" (obligatoriu!!!)
//   set switcore_panel_admin_password "<password>" (obligatoriu!!!)
//   set switcore_panel_cors_origins "http://localhost:8080,https://domeniultau.com" (obligatoriu!!!)

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function getSecretValue(convarName, envName) {
    if (typeof GetConvar === 'function') {
        const v = GetConvar(convarName, '');
        if (v && v !== '' && v !== 'default') return v;
    }
    if (process.env[envName]) return process.env[envName];
    return null;
}

function getOrCreateJwtSecret() {
    const fromConvar = getSecretValue('switcore_panel_jwt_secret', 'SWITCORE_PANEL_JWT_SECRET');
    if (fromConvar) return fromConvar;

    const secretPath = path.join(__dirname, '.jwt-secret');
    try {
        if (fs.existsSync(secretPath)) {
            const v = fs.readFileSync(secretPath, 'utf8').trim();
            if (v.length >= 32) return v;
        }
    } catch { }

    const generated = crypto.randomBytes(48).toString('hex');
    try {
        fs.writeFileSync(secretPath, generated, { mode: 0o600 });
        console.warn('[PANEL] JWT secret generat random in .jwt-secret. Seteaza switcore_panel_jwt_secret in server.cfg pentru persistenta cross-resource.');
    } catch (err) {
        console.warn('[PANEL] Nu pot scrie .jwt-secret:', err.message);
    }
    return generated;
}

function parseCorsOrigins() {
    const raw = getSecretValue('switcore_panel_cors_origins', 'SWITCORE_PANEL_CORS_ORIGINS');
    if (!raw) return ['http://localhost:8080'];
    return raw.split(',').map(s => s.trim()).filter(Boolean);
}

module.exports = {
    port: 8080,
    jwtSecret: getOrCreateJwtSecret(),
    jwtExpiry: '24h',

    admin: {
        username: getSecretValue('switcore_panel_admin_username', 'SWITCORE_PANEL_ADMIN_USERNAME') || 'admin',
        password: getSecretValue('switcore_panel_admin_password', 'SWITCORE_PANEL_ADMIN_PASSWORD') || 'CHANGE_ME_via_convar'
    },

    database: {
        host: getSecretValue('switcore_panel_db_host', 'SWITCORE_PANEL_DB_HOST') || 'localhost',
        port: parseInt(getSecretValue('switcore_panel_db_port', 'SWITCORE_PANEL_DB_PORT') || '5432', 10),
        database: getSecretValue('switcore_panel_db_name', 'SWITCORE_PANEL_DB_NAME') || 'switcore',
        user: getSecretValue('switcore_panel_db_user', 'SWITCORE_PANEL_DB_USER') || 'switcore_user',
        password: getSecretValue('switcore_panel_db_password', 'SWITCORE_PANEL_DB_PASSWORD') || ''
    },

    corsOrigins: parseCorsOrigins()
};
