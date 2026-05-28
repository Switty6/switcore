{
    const express = require('express');
    const { Pool } = require('pg');
    const jwt = require('jsonwebtoken');
    const bcrypt = require('bcryptjs');
    const cors = require('cors');
    const path = require('path');
    const __dirname = GetResourcePath(GetCurrentResourceName());

    // config.local.js overrides config.js when present
    let config;
    try {
        config = require('./config.local');
        console.log('[PANEL] Folosind config.local.js');
    } catch {
        config = require('./config');
        console.log('[PANEL] Folosind config.js (implicit)');
    }

    const ROLE_LEVELS = { staff: 1, moderator: 2, admin: 3, superadmin: 4 };

    let adminUsers = [];

    function initDefaultUser() {
        if (adminUsers.length === 0) {
            if (config.admin.password === 'CHANGE_ME_via_convar' || !config.admin.password) {
                console.warn('[PANEL] AVERTISMENT: parola admin nu este setata. Seteaza switcore_panel_admin_password in server.cfg.');
            }
            adminUsers.push({
                username: config.admin.username,
                passwordHash: bcrypt.hashSync(config.admin.password, 12),
                role: 'superadmin',
                created_at: new Date().toISOString(),
                last_login: null
            });
        }
    }

    let auditLog = [];

    function addAuditEntry(username, action, target, oldValue = null, newValue = null) {
        const entry = {
            id: Date.now() + '-' + Math.floor(Math.random() * 10000),
            username,
            action,
            target,
            old_value: oldValue !== null ? String(oldValue) : null,
            new_value: newValue !== null ? String(newValue) : null,
            timestamp: new Date().toISOString()
        };
        auditLog.unshift(entry);
        if (auditLog.length > 2000) auditLog.pop();

        if (!useDummy) {
            pool.query(
                `INSERT INTO panel_audit_log (username, action, target, old_value, new_value)
             VALUES ($1, $2, $3, $4, $5)`,
                [username, action, target, entry.old_value, entry.new_value]
            ).catch(() => { });
        }
    }

    // Fallback dataset used when the postgres pool is unreachable so the UI still renders
    const DUMMY_SETTINGS = [
        { key: 'core.playtime_update_interval', value: '60', description: 'Cât de des se salvează playtime-ul în DB (secunde)' },
        { key: 'core.default_language', value: 'ro', description: 'Limba implicită a serverului (ro/en)' },
        { key: 'core.log_commands', value: 'true', description: 'Activează logarea comenzilor admin' },
        { key: 'characters.max_per_player', value: '3', description: 'Numărul maxim de personaje per cont' },
        { key: 'characters.min_age', value: '18', description: 'Vârsta minimă a personajului' },
        { key: 'characters.max_age', value: '80', description: 'Vârsta maximă a personajului' },
        { key: 'characters.enable_deletion', value: 'true', description: 'Permite ștergerea personajelor' },
        { key: 'characters.first_name_min_length', value: '2', description: 'Lungimea minimă a prenumelui' },
        { key: 'characters.first_name_max_length', value: '20', description: 'Lungimea maximă a prenumelui' },
        { key: 'characters.last_name_min_length', value: '2', description: 'Lungimea minimă a numelui de familie' },
        { key: 'characters.last_name_max_length', value: '20', description: 'Lungimea maximă a numelui de familie' },
        { key: 'characters.name_pattern', value: "^[%w%s%-%'%.]+$", description: 'Pattern Lua pentru validarea numelui' },
        { key: 'characters.spawn_x', value: '-269.4', description: 'Coordonata X a spawn-ului implicit' },
        { key: 'characters.spawn_y', value: '-955.3', description: 'Coordonata Y a spawn-ului implicit' },
        { key: 'characters.spawn_z', value: '31.2', description: 'Coordonata Z a spawn-ului implicit' },
        { key: 'characters.spawn_heading', value: '205.8', description: 'Direcția personajului la spawn' },
        { key: 'inventory.max_weight', value: '30.0', description: 'Greutatea maximă a inventarului (kg)' },
        { key: 'inventory.max_slots', value: '40', description: 'Numărul de sloturi al inventarului' },
        { key: 'inventory.hotbar_slots', value: '5', description: 'Numărul de sloturi hotbar' },
        { key: 'inventory.drop_interaction_range', value: '2.0', description: 'Raza de interacțiune cu item-urile droplate (m)' },
        { key: 'banking.inflation_calculation_interval', value: '3600', description: 'Interval recalculare inflație (secunde)' },
        { key: 'banking.interest_calculation_interval', value: '3600', description: 'Interval calcul dobânzi (secunde)' },
        { key: 'banking.log_transactions', value: 'true', description: 'Activează logarea tranzacțiilor' },
        { key: 'banking.dynamic_exchange_rate_update_interval', value: '300', description: 'Interval actualizare rate de schimb (secunde)' },
        { key: 'banking.max_dynamic_exchange_rate_fluctuation', value: '5.0', description: 'Fluctuația maximă a ratei de schimb (%)' },
        { key: 'banking.min_transaction_amount', value: '0.01', description: 'Suma minimă a unei tranzacții' },
        { key: 'banking.max_transaction_amount', value: '999999999.99', description: 'Suma maximă a unei tranzacții' },
        { key: 'banking.auto_calculate_interest', value: 'true', description: 'Calculează dobânzile automat' },
        { key: 'banking.inflation_multiplier_enabled', value: 'true', description: 'Aplică multiplicatorul de inflație' },
        { key: 'banking.min_loan_term_months', value: '6', description: 'Durata minimă a unui credit (luni)' },
        { key: 'banking.max_loan_term_months', value: '60', description: 'Durata maximă a unui credit (luni)' },
        { key: 'banking.min_deposit_term_days', value: '30', description: 'Durata minimă a unui depozit (zile)' },
        { key: 'banking.max_deposit_term_days', value: '365', description: 'Durata maximă a unui depozit (zile)' },
        { key: 'banking.atm_distance', value: '1.5', description: 'Distanța de interacțiune ATM (m)' },
        { key: 'banking.bank_distance', value: '2.0', description: 'Distanța de interacțiune bancă (m)' },
        { key: 'banking.account_number_sequence_length', value: '12', description: 'Lungimea secvenței din numărul de cont' },
        { key: 'notifications.max_notifications', value: '5', description: 'Numărul maxim de notificări simultane' },
        { key: 'notifications.default_duration', value: '5000', description: 'Durata implicită a notificărilor (ms)' },
        { key: 'notifications.position', value: 'right-middle', description: 'Poziția notificărilor pe ecran' },
        { key: 'hud.primary_currency', value: 'USD', description: 'Moneda principală afișată în HUD' },
        { key: 'hud.primary_symbol', value: '$', description: 'Simbolul monedei principale' },
        { key: 'hud.max_speed', value: '240', description: 'Viteza maximă a vitezometrului (km/h)' },
        { key: 'hud.tick_interval', value: '333', description: 'Intervalul de actualizare a HUD-ului (ms)' },
        { key: 'hud.hide_native_hud', value: 'true', description: 'Ascunde HUD-ul nativ FiveM' },
        { key: 'hud.component_stats', value: 'true', description: 'Afișează bara de stats (HP/armor/hunger/thirst)' },
        { key: 'hud.component_cash', value: 'true', description: 'Afișează cash-ul în HUD' },
        { key: 'hud.component_time', value: 'true', description: 'Afișează ceasul în HUD' },
        { key: 'hud.component_speedometer', value: 'true', description: 'Afișează vitezometrul în vehicul' },
        { key: 'proximity.proximity_distance', value: '2.0', description: 'Distanța de detecție proximity (m)' },
        { key: 'proximity.show_marker', value: 'true', description: 'Afișează markere la punctele de interacțiune' },
        { key: 'proximity.show_text', value: 'true', description: 'Afișează text la punctele de interacțiune' },
        { key: 'proximity.debug', value: 'false', description: 'Modul debug proximity' },
        { key: 'needs.hunger_decay_rate', value: '0.5', description: 'Cât scade hunger-ul per interval' },
        { key: 'needs.thirst_decay_rate', value: '0.8', description: 'Cât scade thirst-ul per interval' },
        { key: 'needs.damage_threshold', value: '10.0', description: 'Sub ce valoare se aplică damage' },
        { key: 'needs.damage_amount', value: '2', description: 'HP scos per interval când e critic' },
        { key: 'needs.update_interval', value: '60', description: 'Intervalul de scădere hunger/thirst (secunde)' },
        { key: 'needs.save_interval', value: '300', description: 'Intervalul de salvare în DB (secunde)' },
        { key: 'police.jail_cell', value: '{"x":1651.0,"y":2570.0,"z":45.5,"heading":90.0}', description: 'Coordonate celulă închisoare (x,y,z,heading)' },
        { key: 'police.jail_release', value: '{"x":1845.0,"y":2586.0,"z":45.7,"heading":270.0}', description: 'Coordonate ieșire închisoare (x,y,z,heading)' },
        { key: 'police.armory_coords', value: '{"x":462.5,"y":-993.6,"z":26.7}', description: 'Coordonate dulap armament' },
        { key: 'police.armory_radius', value: '1.5', description: 'Raza de interacțiune cu armamentul (metri)' },
        { key: 'police.cloakroom_coords', value: '{"x":458.8,"y":-1000.2,"z":26.7}', description: 'Coordonate vestiar poliție' },
        { key: 'police.cloakroom_radius', value: '1.5', description: 'Raza de interacțiune cu vestiarul (metri)' },
        { key: 'police.mdt_key', value: 'F6', description: 'Tasta pentru deschiderea MDT-ului' },
        { key: 'police.handcuff_distance', value: '2.5', description: 'Distanța maximă pentru încătușare (metri)' },
        { key: 'police.armory_weapons', value: '[{"itemName":"weapon_pistol","label":"Pistol","ammoItem":"ammo_pistol","ammoAmount":50},{"itemName":"weapon_stungun","label":"Taser","ammoItem":null,"ammoAmount":0},{"itemName":"weapon_nightstick","label":"Bată","ammoItem":null,"ammoAmount":0},{"itemName":"weapon_smg","label":"SMG","ammoItem":"ammo_smg","ammoAmount":100},{"itemName":"weapon_carbinerifle","label":"Carbine Rifle","ammoItem":"ammo_rifle","ammoAmount":60}]', description: 'Lista armelor disponibile în armament (JSON)' },
        { key: 'police.armory_equipment', value: '[{"itemName":"handcuffs","label":"Cătușe","amount":1},{"itemName":"police_radio","label":"Stație radio","amount":1},{"itemName":"police_badge","label":"Legitimație","amount":1},{"itemName":"first_aid_kit","label":"Trusă prim-ajutor","amount":1}]', description: 'Lista echipamentelor disponibile în armament (JSON)' },
        { key: 'police.uniform_male', value: '[{"componentId":11,"drawableId":55,"textureId":0},{"componentId":4,"drawableId":35,"textureId":0},{"componentId":6,"drawableId":25,"textureId":0}]', description: 'Componente uniformă masculină poliție (JSON)' },
        { key: 'police.uniform_female', value: '[{"componentId":11,"drawableId":48,"textureId":0},{"componentId":4,"drawableId":34,"textureId":0},{"componentId":6,"drawableId":25,"textureId":0}]', description: 'Componente uniformă feminină poliție (JSON)' },
        { key: 'police.garage_coords', value: '{"x":453.2,"y":-989.3,"z":30.7,"heading":355.0}', description: 'Coordonate garaj poliție (x,y,z,heading)' },
        { key: 'police.garage_radius', value: '5.0', description: 'Raza de interacțiune garaj poliție (metri)' },
        { key: 'police.garage_spawn', value: '{"x":453.2,"y":-994.3,"z":30.7,"heading":355.0}', description: 'Punct de spawn vehicule garaj poliție (x,y,z,heading)' },
        { key: 'police.fleet_models', value: '[{"model":"police","label":"Patrulă Standard","category":"emergency","price":45000},{"model":"police2","label":"Patrulă Rapidă","category":"emergency","price":60000},{"model":"policeb","label":"Motocicletă Poliție","category":"emergency","price":30000}]', description: 'Modelele de vehicule disponibile în flota poliției (JSON)' },
        { key: 'police.vehicle_sell_ratio', value: '0.6', description: 'Procentul din preț recuperat la vânzarea unui vehicul (0.0-1.0)' },
        { key: 'police.vehicle_price_currency', value: '1', description: 'ID-ul valutei pentru achiziția vehiculelor' },
        { key: 'police.mileage_unit', value: 'km', description: 'Unitatea de măsură a kilometrajului (km sau miles)' },
        { key: 'police.station_blip', value: '{"x":428.0,"y":-981.0,"z":30.7,"sprite":60,"color":29,"scale":0.8,"label":"Secție Poliție"}', description: 'Configurare blip secție de poliție (JSON)' },
        { key: 'police.jail_blip', value: '{"x":1651.0,"y":2570.0,"z":45.5,"sprite":123,"color":3,"scale":0.8,"label":"Închisoare"}', description: 'Configurare blip închisoare (JSON)' },
        { key: 'ems.respawn_timer', value: '600', description: 'Secunde până la opțiunea de respawn la spital' },
        { key: 'ems.hospital_bill', value: '5000', description: 'Cost spitalizare la respawn (RON)' },
        { key: 'ems.hospital_x', value: '295.5', description: 'Coord X spital spawn' },
        { key: 'ems.hospital_y', value: '-1446.8', description: 'Coord Y spital spawn' },
        { key: 'ems.hospital_z', value: '29.9', description: 'Coord Z spital spawn' },
        { key: 'ems.hospital_heading', value: '180.0', description: 'Heading spawn spital' },
        { key: 'ems.revive_hp', value: '150', description: 'HP acordat după resuscitare' },
        { key: 'ems.ambulance_radius', value: '5.0', description: 'Raza acces inventar ambulanță (GTA units)' },
        { key: 'ems.patient_scan_interval', value: '2', description: 'Secunde între scan-uri proximity EMS' },
        { key: 'ems.patient_scan_range', value: '3.5', description: 'Raza interacțiune pacient (GTA units)' },
        { key: 'ems.stretcher_range', value: '2.0', description: 'Raza ridicare pacient cu targă' },
        { key: 'ems.blip_update_interval', value: '5', description: 'Secunde între update-uri poziții blipuri ambulanțe' },
        { key: 'ems.mdt_key', value: 'F6', description: 'Tasta deschidere MDT medical' },
        { key: 'ems.ambulance_models', value: '["ambulance","lguard"]', description: 'Modele vehicule recunoscute ca ambulanțe (JSON array)' },
        { key: 'ems.default_stock', value: '[{"item":"bandage","amount":10},{"item":"morphine","amount":5},{"item":"iv_fluids","amount":5},{"item":"defibrillator","amount":1},{"item":"morphine_iv","amount":3}]', description: 'Stoc implicit ambulanță la aprovizionare' },
        { key: 'ems.iv_treatments', value: '[{"item":"iv_fluids","label":"IV Fluids","restoreHP":50},{"item":"morphine_iv","label":"Morfina IV","suppressDuration":600,"injuryBleedSuppress":600}]', description: 'Tratamente IV disponibile în ambulanță' },
        { key: 'medical.sneeze_radius', value: '5.0', description: 'Raza transmitere infecție la strănut (GTA units)' },
        { key: 'medical.mask_protection', value: '0.10', description: 'Multiplicator șansă infectare cu mască chirurgicală (0.0-1.0)' },
        { key: 'medical.vitamin_immunity_multiplier', value: '0.50', description: 'Reducere șansă infectare când imunitatea e activă (0.0-1.0)' },
        { key: 'medical.vitamin_effect_duration', value: '3600', description: 'Durata efect imunitate vitamine (secunde)' },
        { key: 'medical.progression_interval', value: '300', description: 'Interval verificare progresie boli (secunde)' },
        { key: 'medical.severe_damage_per_tick', value: '2', description: 'HP pierdut per tick la sângerare din boli' },
        { key: 'medical.severe_damage_interval', value: '30', description: 'Interval damage sângerare din boli (secunde)' },
        { key: 'medical.critical_damage_per_tick', value: '5', description: 'HP pierdut per tick la stadiu critic (5)' },
        { key: 'medical.critical_damage_interval', value: '15', description: 'Interval damage stadiu critic (secunde)' },
        { key: 'medical.injury_bleed_loop_interval', value: '5', description: 'Interval loop bleeding răni (secunde)' },
        { key: 'medical.stage_progression_time', value: '{"1":600,"2":900,"3":1200,"4":1800}', description: 'Timp până la progresie per stadiu (secunde)' },
        { key: 'medical.stage_labels', value: '{"1":"Incubatie","2":"Usoara","3":"Moderata","4":"Severa","5":"Critica"}', description: 'Etichete afișate pentru fiecare stadiu boală' },
    ].map(s => ({ ...s, updated_at: new Date().toISOString() }));

    const DUMMY_PLAYERS = [
        { id: 1, license: 'license:a1b2c3d4e5f6a1b2', name: 'Ion Popescu', steam: 'steam:110000101234567', character_count: 2, playtime: 7320, created_at: '2024-01-15T10:30:00Z', last_seen: new Date(Date.now() - 90000).toISOString(), online: true, banned: false },
        { id: 2, license: 'license:b2c3d4e5f6a1b2c3', name: 'Maria Ionescu', steam: null, character_count: 1, playtime: 3600, created_at: '2024-02-20T14:00:00Z', last_seen: new Date(Date.now() - 800000).toISOString(), online: false, banned: false },
        { id: 3, license: 'license:c3d4e5f6a1b2c3d4', name: 'Andrei Constantin', steam: 'steam:110000109876543', character_count: 3, playtime: 18000, created_at: '2024-01-01T08:00:00Z', last_seen: new Date(Date.now() - 86400000).toISOString(), online: false, banned: false },
        { id: 4, license: 'license:d4e5f6a1b2c3d4e5', name: 'Elena Gheorghe', steam: 'steam:110000102345678', character_count: 2, playtime: 1800, created_at: '2024-03-01T16:00:00Z', last_seen: new Date(Date.now() - 120000).toISOString(), online: true, banned: false },
        { id: 5, license: 'license:e5f6a1b2c3d4e5f6', name: 'Mihai Dumitrescu', steam: null, character_count: 1, playtime: 900, created_at: '2024-03-10T11:00:00Z', last_seen: new Date(Date.now() - 3600000).toISOString(), online: false, banned: true },
        { id: 6, license: 'license:f6a1b2c3d4e5f6a1', name: 'Cristina Stoica', steam: 'steam:110000103456789', character_count: 2, playtime: 5400, created_at: '2024-02-05T09:00:00Z', last_seen: new Date(Date.now() - 200000).toISOString(), online: false, banned: false },
        { id: 7, license: 'license:a7b8c9d0e1f2a3b4', name: 'Alexandru Popa', steam: 'steam:110000104567890', character_count: 1, playtime: 10800, created_at: '2023-12-20T12:00:00Z', last_seen: new Date(Date.now() - 172800000).toISOString(), online: false, banned: false },
    ];

    const pool = new Pool(config.database);
    let useDummy = false;

    let dummyStore = DUMMY_SETTINGS.map(s => ({ ...s }));

    function dummyGetAll() {
        return [...dummyStore].sort((a, b) => a.key.localeCompare(b.key));
    }

    function dummyUpdate(key, value) {
        const row = dummyStore.find(s => s.key === key);
        if (!row) return null;
        row.value = value;
        row.updated_at = new Date().toISOString();
        return row;
    }

    async function initDbSchema() {
        try {
            await pool.query(`
            CREATE TABLE IF NOT EXISTS panel_users (
                username     VARCHAR(50) PRIMARY KEY,
                password_hash TEXT NOT NULL,
                role         VARCHAR(20) NOT NULL DEFAULT 'staff',
                created_at   TIMESTAMP DEFAULT NOW(),
                last_login   TIMESTAMP
            )
        `);
            await pool.query(`
            CREATE TABLE IF NOT EXISTS panel_audit_log (
                id         SERIAL PRIMARY KEY,
                username   VARCHAR(50) NOT NULL,
                action     VARCHAR(100) NOT NULL,
                target     TEXT,
                old_value  TEXT,
                new_value  TEXT,
                timestamp  TIMESTAMP DEFAULT NOW()
            )
        `);
            await pool.query(`
            CREATE TABLE IF NOT EXISTS player_bans (
                id         SERIAL PRIMARY KEY,
                license    VARCHAR(100) NOT NULL,
                reason     TEXT,
                banned_by  VARCHAR(50),
                expires_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT NOW()
            )
        `);
            await pool.query(`
            CREATE TABLE IF NOT EXISTS kick_queue (
                id         SERIAL PRIMARY KEY,
                license    VARCHAR(100) NOT NULL,
                reason     TEXT,
                kicked_by  VARCHAR(50),
                processed  BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT NOW()
            )
        `);

            const { rowCount } = await pool.query('SELECT 1 FROM panel_users LIMIT 1');
            if (rowCount === 0) {
                await pool.query(
                    'INSERT INTO panel_users (username, password_hash, role) VALUES ($1, $2, $3)',
                    [config.admin.username, bcrypt.hashSync(config.admin.password, 12), 'superadmin']
                );
                console.log('[PANEL] User admin default creat în DB');
            }

            console.log('[PANEL] Schema panel inițializată');
        } catch (err) {
            console.error('[PANEL] Eroare schema:', err.message);
        }
    }

    const app = express();
    app.use(express.json());

    // CORS whitelist din config. Daca config.corsOrigins lipseste sau e gol,
    // permite doar same-origin (no CORS header -> blocheaza cross-origin).
    const allowedOrigins = Array.isArray(config.corsOrigins) && config.corsOrigins.length
        ? config.corsOrigins
        : (config.corsOrigin ? [config.corsOrigin] : []);

    app.use(cors({
        origin: (origin, callback) => {
            if (!origin) return callback(null, true);
            if (allowedOrigins.includes('*')) return callback(null, true);
            if (allowedOrigins.includes(origin)) return callback(null, true);
            return callback(new Error('CORS: origin not allowed'), false);
        },
        credentials: true
    }));
    app.use(express.static(path.join(__dirname, 'public')));

    function requireAuth(req, res, next) {
        const header = req.headers.authorization || '';
        const token = header.startsWith('Bearer ') ? header.slice(7) : null;
        if (!token) return res.status(401).json({ error: 'Autentificare necesară' });
        try {
            req.user = jwt.verify(token, config.jwtSecret);
            next();
        } catch (err) {
            const msg = err.name === 'TokenExpiredError'
                ? 'Sesiunea a expirat, reconectează-te'
                : 'Token invalid';
            return res.status(401).json({ error: msg });
        }
    }

    function requireRole(minRole) {
        return (req, res, next) => {
            const userLevel = ROLE_LEVELS[req.user.role] || 0;
            const minLevel = ROLE_LEVELS[minRole] || 0;
            if (userLevel < minLevel) {
                return res.status(403).json({ error: 'Permisiuni insuficiente pentru această acțiune' });
            }
            next();
        };
    }

    app.post('/api/auth/login', async (req, res) => {
        const { username, password } = req.body || {};
        if (!username || !password)
            return res.status(400).json({ error: 'Username și parolă obligatorii' });

        let user = null;

        if (!useDummy) {
            try {
                const { rows } = await pool.query(
                    'SELECT username, password_hash, role, created_at, last_login FROM panel_users WHERE username = $1',
                    [username]
                );
                if (rows[0]) {
                    user = { ...rows[0], passwordHash: rows[0].password_hash };
                }
            } catch { }
        }

        if (!user) {
            user = adminUsers.find(u => u.username === username);
        }

        if (!user || !bcrypt.compareSync(password, user.passwordHash || user.password_hash))
            return res.status(401).json({ error: 'Credențiale incorecte' });

        const now = new Date().toISOString();
        if (!useDummy) {
            pool.query('UPDATE panel_users SET last_login = NOW() WHERE username = $1', [username]).catch(() => { });
        }
        const inMem = adminUsers.find(u => u.username === username);
        if (inMem) inMem.last_login = now;

        const token = jwt.sign(
            { username, role: user.role },
            config.jwtSecret,
            { expiresIn: config.jwtExpiry || '24h' }
        );

        addAuditEntry(username, 'LOGIN', 'panel');
        res.json({ token, username, role: user.role, dummyMode: useDummy });
    });

    app.get('/api/auth/me', requireAuth, (req, res) => {
        res.json({ username: req.user.username, role: req.user.role, dummyMode: useDummy });
    });

    app.get('/api/settings', requireAuth, async (req, res) => {
        if (useDummy) return res.json(dummyGetAll());
        try {
            const { rows } = await pool.query(
                'SELECT key, value, description, updated_at FROM settings ORDER BY key'
            );
            res.json(rows);
        } catch (err) {
            console.error('[PANEL] DB error, serving dummy data:', err.message);
            res.json(dummyGetAll());
        }
    });

    app.get('/api/settings/groups', requireAuth, async (req, res) => {
        if (useDummy) {
            const counts = {};
            for (const s of dummyStore) {
                const g = s.key.split('.')[0];
                counts[g] = (counts[g] || 0) + 1;
            }
            return res.json(Object.entries(counts).sort().map(([name, count]) => ({ name, count })));
        }
        try {
            const { rows } = await pool.query(`
            SELECT split_part(key, '.', 1) AS name, COUNT(*)::int AS count
            FROM settings GROUP BY name ORDER BY name
        `);
            res.json(rows);
        } catch (err) {
            const counts = {};
            for (const s of dummyStore) {
                const g = s.key.split('.')[0];
                counts[g] = (counts[g] || 0) + 1;
            }
            res.json(Object.entries(counts).sort().map(([name, count]) => ({ name, count })));
        }
    });

    app.put('/api/settings/:key', requireAuth, async (req, res) => {
        const { key } = req.params;
        const { value } = req.body || {};
        if (value === undefined) return res.status(400).json({ error: 'Câmpul value este obligatoriu' });

        if (useDummy) {
            const row = dummyUpdate(key, String(value));
            if (!row) return res.status(404).json({ error: `Cheia '${key}' nu există` });
            const oldVal = dummyStore.find(s => s.key === key)?.value;
            addAuditEntry(req.user.username, 'UPDATE_SETTING', key, oldVal, value);
            console.log(`[PANEL][DUMMY] ${req.user.username} → ${key} = ${value}`);
            return res.json(row);
        }
        try {
            const old = await pool.query('SELECT value FROM settings WHERE key = $1', [key]);
            const oldVal = old.rows[0]?.value ?? null;

            const result = await pool.query(
                'UPDATE settings SET value = $1, updated_at = NOW() WHERE key = $2 RETURNING key, value, updated_at',
                [String(value), key]
            );
            if (result.rowCount === 0) return res.status(404).json({ error: `Cheia '${key}' nu există` });

            addAuditEntry(req.user.username, 'UPDATE_SETTING', key, oldVal, value);
            console.log(`[PANEL] ${req.user.username} → ${key} = ${value}`);
            res.json(result.rows[0]);
        } catch (err) {
            console.error('[PANEL] DB error on update, using dummy:', err.message);
            const row = dummyUpdate(key, String(value));
            res.json(row || { key, value, updated_at: new Date().toISOString() });
        }
    });

    app.put('/api/settings', requireAuth, async (req, res) => {
        const changes = req.body;
        if (!changes || typeof changes !== 'object' || Array.isArray(changes))
            return res.status(400).json({ error: 'Body trebuie să fie un obiect { key: value }' });

        if (useDummy) {
            const updated = [];
            for (const [key, value] of Object.entries(changes)) {
                const row = dummyStore.find(s => s.key === key);
                if (row) {
                    addAuditEntry(req.user.username, 'UPDATE_SETTING', key, row.value, value);
                    dummyUpdate(key, String(value));
                    updated.push(key);
                }
            }
            console.log(`[PANEL][DUMMY] ${req.user.username} bulk saved ${updated.length} keys`);
            return res.json({ updated, count: updated.length });
        }
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            const updated = [];
            for (const [key, value] of Object.entries(changes)) {
                const old = await client.query('SELECT value FROM settings WHERE key = $1', [key]);
                const r = await client.query(
                    'UPDATE settings SET value = $1, updated_at = NOW() WHERE key = $2 RETURNING key',
                    [String(value), key]
                );
                if (r.rowCount > 0) {
                    addAuditEntry(req.user.username, 'UPDATE_SETTING', key, old.rows[0]?.value ?? null, value);
                    updated.push(key);
                }
            }
            await client.query('COMMIT');
            console.log(`[PANEL] ${req.user.username} bulk saved: ${updated.join(', ')}`);
            res.json({ updated, count: updated.length });
        } catch (err) {
            await client.query('ROLLBACK');
            const updated = [];
            for (const [key, value] of Object.entries(changes)) {
                if (dummyUpdate(key, String(value))) updated.push(key);
            }
            res.json({ updated, count: updated.length });
        } finally {
            client.release();
        }
    });

    app.get('/api/users', requireAuth, requireRole('admin'), async (req, res) => {
        if (!useDummy) {
            try {
                const { rows } = await pool.query(
                    'SELECT username, role, created_at, last_login FROM panel_users ORDER BY created_at'
                );
                return res.json(rows);
            } catch { }
        }
        res.json(adminUsers.map(({ passwordHash, ...u }) => u));
    });

    app.post('/api/users', requireAuth, requireRole('superadmin'), async (req, res) => {
        const { username, password, role } = req.body || {};
        if (!username || !password || !role)
            return res.status(400).json({ error: 'Username, parolă și rol sunt obligatorii' });
        if (!ROLE_LEVELS[role])
            return res.status(400).json({ error: 'Rol invalid. Valori: staff, moderator, admin, superadmin' });
        if (ROLE_LEVELS[role] >= ROLE_LEVELS[req.user.role])
            return res.status(403).json({ error: 'Nu poți crea un utilizator cu rol superior sau egal cu al tău' });

        const passwordHash = bcrypt.hashSync(password, 12);
        const now = new Date().toISOString();

        if (!useDummy) {
            try {
                await pool.query(
                    'INSERT INTO panel_users (username, password_hash, role) VALUES ($1, $2, $3)',
                    [username, passwordHash, role]
                );
            } catch (err) {
                if (err.code === '23505') return res.status(409).json({ error: 'Username-ul există deja' });
                return res.status(500).json({ error: 'Internal server error' });
            }
        } else {
            if (adminUsers.find(u => u.username === username))
                return res.status(409).json({ error: 'Username-ul există deja' });
            adminUsers.push({ username, passwordHash, role, created_at: now, last_login: null });
        }

        addAuditEntry(req.user.username, 'CREATE_USER', username, null, role);
        res.status(201).json({ username, role, created_at: now, last_login: null });
    });

    app.put('/api/users/:username', requireAuth, requireRole('superadmin'), async (req, res) => {
        const { username } = req.params;
        const { password, role } = req.body || {};

        if (!password && !role)
            return res.status(400).json({ error: 'Nimic de actualizat (password sau role)' });
        if (role && !ROLE_LEVELS[role])
            return res.status(400).json({ error: 'Rol invalid' });
        if (role && ROLE_LEVELS[role] >= ROLE_LEVELS[req.user.role])
            return res.status(403).json({ error: 'Nu poți seta un rol superior sau egal cu al tău' });

        if (!useDummy) {
            try {
                const sets = [];
                const vals = [];
                let i = 1;
                if (role) { sets.push(`role = $${i++}`); vals.push(role); }
                if (password) { sets.push(`password_hash = $${i++}`); vals.push(bcrypt.hashSync(password, 12)); }
                vals.push(username);
                const r = await pool.query(`UPDATE panel_users SET ${sets.join(', ')} WHERE username = $${i}`, vals);
                if (r.rowCount === 0) return res.status(404).json({ error: 'Utilizator negăsit' });
            } catch (err) {
                return res.status(500).json({ error: 'Internal server error' });
            }
        } else {
            const user = adminUsers.find(u => u.username === username);
            if (!user) return res.status(404).json({ error: 'Utilizator negăsit' });
            if (role) user.role = role;
            if (password) user.passwordHash = bcrypt.hashSync(password, 12);
        }

        const desc = [role && `rol → ${role}`, password && 'parola schimbata'].filter(Boolean).join(', ');
        addAuditEntry(req.user.username, 'UPDATE_USER', username, null, desc);
        res.json({ success: true });
    });

    app.delete('/api/users/:username', requireAuth, requireRole('superadmin'), async (req, res) => {
        const { username } = req.params;
        if (username === req.user.username)
            return res.status(400).json({ error: 'Nu te poți șterge pe tine însuți' });

        if (!useDummy) {
            try {
                const r = await pool.query('DELETE FROM panel_users WHERE username = $1', [username]);
                if (r.rowCount === 0) return res.status(404).json({ error: 'Utilizator negăsit' });
            } catch (err) {
                return res.status(500).json({ error: 'Internal server error' });
            }
        } else {
            const idx = adminUsers.findIndex(u => u.username === username);
            if (idx === -1) return res.status(404).json({ error: 'Utilizator negăsit' });
            adminUsers.splice(idx, 1);
        }

        addAuditEntry(req.user.username, 'DELETE_USER', username);
        res.json({ success: true });
    });

    app.get('/api/players', requireAuth, async (req, res) => {
        const { search } = req.query;

        if (!useDummy) {
            try {
                let whereClause = '';
                const vals = [];
                if (search) {
                    whereClause = `WHERE p.name ILIKE $1 OR EXISTS (SELECT 1 FROM player_identifiers pi2 WHERE pi2.player_id = p.id AND pi2.value ILIKE $1)`;
                    vals.push(`%${search}%`);
                }
                const { rows } = await pool.query(`
                WITH top_players AS (
                    SELECT p.id, p.name, p.playtime, p.created_at, p.updated_at
                    FROM players p
                    ${whereClause}
                    ORDER BY p.updated_at DESC NULLS LAST
                    LIMIT 500
                )
                SELECT
                    tp.id,
                    MAX(CASE WHEN pi.type = 'license' THEN pi.value END)         AS license,
                    tp.name,
                    MAX(CASE WHEN pi.type = 'steam' THEN pi.value END)           AS steam,
                    COALESCE(tp.playtime, 0)::int                                AS playtime,
                    tp.created_at,
                    tp.updated_at                                                AS last_seen,
                    (SELECT COUNT(c.id)::int FROM characters c WHERE c.player_id = tp.id) AS character_count,
                    (EXTRACT(EPOCH FROM (NOW() - tp.updated_at)) < 300)::bool    AS online,
                    EXISTS(
                        SELECT 1 FROM bans b
                        WHERE b.player_id = tp.id
                          AND b.is_active = true
                          AND (b.expires_at IS NULL OR b.expires_at > NOW())
                    )                                                            AS banned
                FROM top_players tp
                LEFT JOIN player_identifiers pi ON pi.player_id = tp.id AND pi.type IN ('license', 'steam')
                GROUP BY tp.id, tp.name, tp.playtime, tp.created_at, tp.updated_at
                ORDER BY tp.updated_at DESC NULLS LAST
            `, vals);

                const online = rows.filter(r => r.online).length;
                const banned = rows.filter(r => r.banned).length;
                return res.json({ players: rows, total: rows.length, online, banned, dummyMode: false });
            } catch (err) {
                console.error('[PANEL] Error fetching players:', err.message);
            }
        }

        let players = DUMMY_PLAYERS;
        if (search) {
            const q = search.toLowerCase();
            players = players.filter(p => p.name.toLowerCase().includes(q) || p.license.includes(q));
        }
        const online = players.filter(p => p.online).length;
        const banned = players.filter(p => p.banned).length;
        res.json({ players, total: players.length, online, banned, dummyMode: true });
    });

    app.post('/api/players/:license/ban', requireAuth, requireRole('moderator'), async (req, res) => {
        const { license } = req.params;
        const { reason, duration_hours } = req.body || {};
        const expires_at = duration_hours ? new Date(Date.now() + duration_hours * 3600000) : null;

        if (!useDummy) {
            try {
                const { rows: pr } = await pool.query(
                    `SELECT p.id FROM players p
                 JOIN player_identifiers pi ON pi.player_id = p.id
                 WHERE pi.type = 'license' AND pi.value = $1 LIMIT 1`,
                    [license]
                );
                if (!pr.length) return res.status(404).json({ error: 'Jucătorul nu a fost găsit' });
                await pool.query(
                    'INSERT INTO bans (player_id, reason, expires_at) VALUES ($1, $2, $3)',
                    [pr[0].id, reason || 'Fără motiv specificat', expires_at]
                );
            } catch (err) {
                return res.status(500).json({ error: 'Internal server error' });
            }
        } else {
            const p = DUMMY_PLAYERS.find(p => p.license === license);
            if (p) p.banned = true;
        }

        const durDesc = duration_hours ? `${duration_hours}h` : 'permanent';
        addAuditEntry(req.user.username, 'BAN_PLAYER', license, null, `${reason || 'fara motiv'} (${durDesc})`);
        res.json({ success: true });
    });

    app.post('/api/players/:license/kick', requireAuth, requireRole('moderator'), async (req, res) => {
        const { license } = req.params;
        const { reason } = req.body || {};

        if (!useDummy) {
            try {
                const { rows: pr } = await pool.query(
                    `SELECT p.id FROM players p
                 JOIN player_identifiers pi ON pi.player_id = p.id
                 WHERE pi.type = 'license' AND pi.value = $1 LIMIT 1`,
                    [license]
                );
                if (pr.length) {
                    await pool.query(
                        'INSERT INTO kick_logs (player_id, reason) VALUES ($1, $2)',
                        [pr[0].id, reason || 'Kick de admin']
                    );
                }
            } catch (err) {
                return res.status(500).json({ error: 'Internal server error' });
            }
        }

        addAuditEntry(req.user.username, 'KICK_PLAYER', license, null, reason || 'fara motiv');
        res.json({ success: true });
    });

    // GET /api/players/kick-queue - stub (kick-urile sunt logate în kick_logs, nu au queue)
    app.get('/api/players/kick-queue', requireAuth, async (req, res) => {
        res.json([]);
    });

    // PUT /api/players/kick-queue/:id/done - stub
    app.put('/api/players/kick-queue/:id/done', requireAuth, async (req, res) => {
        res.json({ success: true });
    });

    app.delete('/api/players/:license/ban', requireAuth, requireRole('moderator'), async (req, res) => {
        if (!useDummy) {
            try {
                const { rows: pr } = await pool.query(
                    `SELECT p.id FROM players p
                 JOIN player_identifiers pi ON pi.player_id = p.id
                 WHERE pi.type = 'license' AND pi.value = $1 LIMIT 1`,
                    [req.params.license]
                );
                if (!pr.length) return res.status(404).json({ error: 'Jucătorul nu a fost găsit' });
                await pool.query(
                    'UPDATE bans SET is_active = false WHERE player_id = $1 AND is_active = true',
                    [pr[0].id]
                );
            } catch (err) {
                return res.status(500).json({ error: 'Internal server error' });
            }
        } else {
            const p = DUMMY_PLAYERS.find(p => p.license === req.params.license);
            if (p) p.banned = false;
        }

        addAuditEntry(req.user.username, 'UNBAN_PLAYER', req.params.license);
        res.json({ success: true });
    });

    app.get('/api/audit', requireAuth, requireRole('admin'), async (req, res) => {
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(100, parseInt(req.query.limit) || 50);
        const offset = (page - 1) * limit;
        const { username, action } = req.query;

        if (!useDummy) {
            try {
                const where = [];
                const vals = [];
                let i = 1;
                if (username) { where.push(`username = $${i++}`); vals.push(username); }
                if (action) { where.push(`action = $${i++}`); vals.push(action); }
                const w = where.length ? `WHERE ${where.join(' AND ')}` : '';

                const [data, cnt] = await Promise.all([
                    pool.query(
                        `SELECT * FROM panel_audit_log ${w} ORDER BY timestamp DESC LIMIT $${i++} OFFSET $${i++}`,
                        [...vals, limit, offset]
                    ),
                    pool.query(`SELECT COUNT(*)::int AS total FROM panel_audit_log ${w}`, vals)
                ]);
                return res.json({ entries: data.rows, total: cnt.rows[0].total, page, limit });
            } catch { }
        }

        let entries = [...auditLog];
        if (username) entries = entries.filter(e => e.username === username);
        if (action) entries = entries.filter(e => e.action === action);
        const total = entries.length;
        entries = entries.slice(offset, offset + limit);
        res.json({ entries, total, page, limit });
    });

    app.get('/api/audit/actions', requireAuth, requireRole('admin'), async (req, res) => {
        if (!useDummy) {
            try {
                const { rows } = await pool.query(
                    'SELECT DISTINCT action FROM panel_audit_log ORDER BY action'
                );
                return res.json(rows.map(r => r.action));
            } catch { }
        }
        const actions = [...new Set(auditLog.map(e => e.action))].sort();
        res.json(actions);
    });

    app.get('/api/jobs', requireAuth, requireRole('admin'), async (req, res) => {
        if (useDummy) return res.json([
            { name: 'police', label: 'Poliție', type: 'whitelisted' },
            { name: 'ems', label: 'EMS', type: 'whitelisted' },
            { name: 'taxi', label: 'Taxi', type: 'self_serve' },
            { name: 'ballas', label: 'Ballas', type: 'illegal' },
        ]);
        try {
            const { rows } = await pool.query(
                'SELECT name, label, type, is_active FROM jobs WHERE is_active = TRUE ORDER BY name'
            );
            res.json(rows);
        } catch (err) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    app.get('/api/jobs/:jobName/roster', requireAuth, requireRole('admin'), async (req, res) => {
        const { jobName } = req.params;
        if (useDummy) return res.json([]);
        try {
            const { rows } = await pool.query(`
            SELECT c.id, c.first_name, c.last_name,
                   cj.grade, cj.is_on_duty, cj.hired_at,
                   jg.label AS grade_label, jg.can_manage
            FROM character_jobs cj
            JOIN characters c  ON c.id        = cj.character_id
            JOIN job_grades jg ON jg.job_name = cj.job_name AND jg.grade = cj.grade
            WHERE cj.job_name = $1
            ORDER BY cj.grade DESC, c.last_name ASC
        `, [jobName]);
            res.json(rows);
        } catch (err) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    app.get('/api/jobs/:jobName/grades', requireAuth, requireRole('admin'), async (req, res) => {
        const { jobName } = req.params;
        if (useDummy) return res.json([]);
        try {
            const { rows } = await pool.query(
                'SELECT * FROM job_grades WHERE job_name = $1 ORDER BY grade ASC',
                [jobName]
            );
            res.json(rows);
        } catch (err) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    app.post('/api/jobs/assign', requireAuth, requireRole('admin'), async (req, res) => {
        const { characterId, jobName, grade } = req.body || {};
        if (!characterId || !jobName) return res.status(400).json({ error: 'characterId și jobName obligatorii' });
        if (useDummy) return res.json({ success: true, dummy: true });
        try {
            await pool.query(`
            INSERT INTO character_jobs (character_id, job_name, grade, is_on_duty, hired_at)
            VALUES ($1, $2, $3, FALSE, NOW())
            ON CONFLICT (character_id) DO UPDATE
                SET job_name = EXCLUDED.job_name, grade = EXCLUDED.grade,
                    is_on_duty = FALSE, hired_at = NOW()
        `, [characterId, jobName, grade || 0]);
            addAuditEntry(req.user.username, 'JOB_ASSIGN', `char:${characterId}`, null, `${jobName}:${grade || 0}`);
            res.json({ success: true });
        } catch (err) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    app.post('/api/jobs/grade', requireAuth, requireRole('admin'), async (req, res) => {
        const { characterId, grade } = req.body || {};
        if (characterId === undefined || grade === undefined) return res.status(400).json({ error: 'characterId și grade obligatorii' });
        if (useDummy) return res.json({ success: true, dummy: true });
        try {
            await pool.query(
                'UPDATE character_jobs SET grade = $1 WHERE character_id = $2',
                [grade, characterId]
            );
            addAuditEntry(req.user.username, 'JOB_GRADE', `char:${characterId}`, null, String(grade));
            res.json({ success: true });
        } catch (err) {
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    app.get('/jobs', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'jobs.html')));
    app.get('/dashboard', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'dashboard.html')));
    app.get('/players', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'players.html')));
    app.get('/users', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'users.html')));
    app.get('/audit', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'audit.html')));
    app.get('/docs', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'docs.html')));
    app.get('/', (_req, res) =>
        res.sendFile(path.join(__dirname, 'public', 'login.html')));

    const PORT = config.port || 8080;
    app.listen(PORT, () => {
        console.log('');
        console.log('  ╔══════════════════════════════════════╗');
        console.log('  ║    SwitCore Admin Panel              ║');
        console.log(`  ║    http://localhost:${PORT}             ║`);
        console.log('  ║    Schimbă parola din config.js      ║');
        console.log('  ╚══════════════════════════════════════╝');
        console.log('');
    });

    pool.query('SELECT 1').then(async () => {
        console.log('  ✓ PostgreSQL conectat - date reale din DB');
        await initDbSchema();
        initDefaultUser();
    }).catch(err => {
        useDummy = true;
        initDefaultUser();
        console.log('  ⚠ PostgreSQL indisponibil - mod DEMO cu date dummy');
        console.log('   ', err.message);
    });
}
