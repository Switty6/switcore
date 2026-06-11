-- ==================== POLICE SCHEMA ====================

CREATE TABLE IF NOT EXISTS police_jail_sentences (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id      INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    arrested_by       INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    reason            TEXT NOT NULL DEFAULT '',
    sentence_minutes  INT NOT NULL DEFAULT 10,
    remaining_seconds INT NOT NULL,
    bail_amount       INT NOT NULL DEFAULT 0,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    arrested_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at       TIMESTAMPTZ,
    release_reason    VARCHAR(32)
);

CREATE TABLE IF NOT EXISTS police_warrants (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    issued_by    INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    charges      TEXT NOT NULL,
    bail_amount  INT NOT NULL DEFAULT 0,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    issued_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at    TIMESTAMPTZ,
    closed_by    INTEGER REFERENCES characters(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS police_armory_logs (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    item_name    VARCHAR(64) NOT NULL,
    amount       INT NOT NULL DEFAULT 1,
    taken_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_jail_active      ON police_jail_sentences(character_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_jail_char        ON police_jail_sentences(character_id);
CREATE INDEX IF NOT EXISTS idx_warrants_active  ON police_warrants(character_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_warrants_char    ON police_warrants(character_id);
CREATE INDEX IF NOT EXISTS idx_armory_logs_char ON police_armory_logs(character_id);

COMMENT ON TABLE police_jail_sentences IS 'Pedepse de inchisoare active si istorice';
COMMENT ON TABLE police_warrants       IS 'Mandate de arest (active/inchise)';
COMMENT ON TABLE police_armory_logs    IS 'Log preluari echipament din armament';

-- ==================== FLEET VEHICLES ====================

CREATE TABLE IF NOT EXISTS police_fleet (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model           VARCHAR(100) NOT NULL,
    label           VARCHAR(100) NOT NULL,
    category        VARCHAR(30) NOT NULL DEFAULT 'emergency',
    plate           VARCHAR(8) UNIQUE NOT NULL,
    fuel            NUMERIC(5,2) NOT NULL DEFAULT 100.0,
    mileage         NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    body_health     NUMERIC(7,2) NOT NULL DEFAULT 1000.0,
    engine_health   NUMERIC(7,2) NOT NULL DEFAULT 1000.0,
    modifications   JSONB NOT NULL DEFAULT '{}',
    is_available    BOOLEAN NOT NULL DEFAULT TRUE,
    checked_out_by  INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    checked_out_at  TIMESTAMPTZ,
    purchase_price  NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS police_fleet_logs (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id   BIGINT NOT NULL REFERENCES police_fleet(id) ON DELETE CASCADE,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    action       VARCHAR(20) NOT NULL CHECK (action IN ('checkout','return','impound')),
    mileage_at   NUMERIC(12,2),
    fuel_at      NUMERIC(5,2),
    logged_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fleet_available   ON police_fleet(is_available);
CREATE INDEX IF NOT EXISTS idx_fleet_checkout    ON police_fleet(checked_out_by);
CREATE INDEX IF NOT EXISTS idx_fleet_logs_char   ON police_fleet_logs(character_id);
CREATE INDEX IF NOT EXISTS idx_fleet_logs_veh    ON police_fleet_logs(vehicle_id);

COMMENT ON TABLE police_fleet      IS 'Flota vehiculelor politiei';
COMMENT ON TABLE police_fleet_logs IS 'Log-ul preluarilor/returnarilor de vehicule';

-- ==================== SETTINGS SEEDS ====================

INSERT INTO settings (key, value, description) VALUES

-- Locatii
('police.jail_cell',         '{"x":1651.0,"y":2570.0,"z":45.5,"heading":90.0}',  'Coordonate celula inchisoare (x,y,z,heading)'),
('police.jail_release',      '{"x":1845.0,"y":2586.0,"z":45.7,"heading":270.0}', 'Coordonate iesire inchisoare (x,y,z,heading)'),
('police.armory_coords',     '{"x":461.2,"y":-982.6,"z":30.65}',                 'Coordonate dulap armament'),
('police.armory_radius',     '1.5',                                               'Raza de interactiune cu armamentul (metri)'),
('police.cloakroom_coords',  '{"x":461.2,"y":-987.4,"z":30.65}',                 'Coordonate vestiar politie'),
('police.cloakroom_radius',  '1.5',                                               'Raza de interactiune cu vestiarul (metri)'),

-- Gameplay
('police.mdt_key',           'F6',  'Tasta pentru deschiderea MDT-ului'),
('police.handcuff_distance', '2.5', 'Distanta maxima pentru incatusare (metri)'),

-- Arme armament
('police.armory_weapons',
 '[{"itemName":"weapon_pistol","label":"Pistol","ammoItem":"ammo_pistol","ammoAmount":50},{"itemName":"weapon_stungun","label":"Taser","ammoItem":null,"ammoAmount":0},{"itemName":"weapon_nightstick","label":"Bata","ammoItem":null,"ammoAmount":0},{"itemName":"weapon_smg","label":"SMG","ammoItem":"ammo_smg","ammoAmount":100},{"itemName":"weapon_carbinerifle","label":"Carbine Rifle","ammoItem":"ammo_rifle","ammoAmount":60}]',
 'Lista armelor disponibile in armament (JSON)'),

-- Echipament armament
('police.armory_equipment',
 '[{"itemName":"handcuffs","label":"Catuse","amount":1},{"itemName":"police_radio","label":"Statie radio","amount":1},{"itemName":"police_badge","label":"Legitimatie","amount":1},{"itemName":"first_aid_kit","label":"Trusa prim-ajutor","amount":1}]',
 'Lista echipamentelor disponibile in armament (JSON)'),

-- Uniforme (componente ped GTA V)
('police.uniform_male',
 '[{"componentId":11,"drawableId":55,"textureId":0},{"componentId":4,"drawableId":35,"textureId":0},{"componentId":6,"drawableId":25,"textureId":0},{"componentId":8,"drawableId":58,"textureId":0},{"componentId":3,"drawableId":7,"textureId":0}]',
 'Componente uniforma masculina politie (JSON)'),
('police.uniform_female',
 '[{"componentId":11,"drawableId":48,"textureId":0},{"componentId":4,"drawableId":34,"textureId":0},{"componentId":6,"drawableId":25,"textureId":0},{"componentId":8,"drawableId":35,"textureId":0},{"componentId":3,"drawableId":7,"textureId":0}]',
 'Componente uniforma feminina politie (JSON)'),

-- Garaj vehicule
('police.garage_coords',
 '{"x":454.6,"y":-1017.4,"z":28.4,"heading":90.0}',
 'Coordonate garaj politie (x,y,z,heading)'),
('police.garage_radius',  '5.0', 'Raza de interactiune garaj politie (metri)'),
('police.garage_spawn',
 '{"x":447.6,"y":-1022.0,"z":28.4,"heading":90.0}',
 'Punct de spawn vehicule garaj politie (x,y,z,heading)'),

-- Modele flota vehicule (definesc ce modele pot fi in flota)
('police.fleet_models',
 '[{"model":"police","label":"Patrula Standard","category":"emergency","price":45000},{"model":"police2","label":"Patrula Rapida","category":"emergency","price":60000},{"model":"police3","label":"Patrula Interceptor","category":"emergency","price":85000},{"model":"policeb","label":"Motocicleta Politie","category":"emergency","price":30000},{"model":"policet","label":"Transport Detinut","category":"transport","price":50000}]',
 'Modelele de vehicule disponibile in flota politiei (JSON, include price)'),

-- Buget vehicule
('police.vehicle_sell_ratio',     '0.6', 'Procentul din pret recuperat la vanzarea unui vehicul (0.0 - 1.0)'),
('police.vehicle_price_currency', '1',   'ID-ul valutei pentru achizitia vehiculelor'),

-- Kilometraj
('police.mileage_unit', 'km', 'Unitatea de masura a kilometrajului (km sau miles)'),

-- Blips
('police.station_blip',
 '{"x":428.0,"y":-981.0,"z":30.7,"sprite":60,"color":29,"scale":0.8,"label":"Sectie Politie"}',
 'Configurare blip sectie de politie (JSON)'),
('police.jail_blip',
 '{"x":1651.0,"y":2570.0,"z":45.5,"sprite":123,"color":3,"scale":0.8,"label":"Inchisoare"}',
 'Configurare blip inchisoare (JSON)'),

-- Blip-uri facilitati interne (vizibile doar pentru politisti). Label-uri fara diacritice.
('police.armory_blip',
 '{"x":461.2,"y":-982.6,"z":30.65,"sprite":110,"color":29,"scale":0.7,"label":"Armament"}',
 'Configurare blip armament (JSON)'),
('police.cloakroom_blip',
 '{"x":461.2,"y":-987.4,"z":30.65,"sprite":73,"color":29,"scale":0.7,"label":"Vestiar"}',
 'Configurare blip vestiar (JSON)'),
('police.garage_blip',
 '{"x":454.6,"y":-1017.4,"z":28.4,"sprite":357,"color":29,"scale":0.7,"label":"Garaj Politie"}',
 'Configurare blip garaj politie (JSON)')

ON CONFLICT (key) DO NOTHING;

-- ==================== MIGRATII COORDONATE (servere existente) ====================
-- INSERT-ul de mai sus nu suprascrie cheile existente (ON CONFLICT DO NOTHING),
-- asa ca mutam coordonatele de la valorile vechi (subsol, z=26.7) la parter.
-- Conditia "value = <vechi>" => NU suprascrie daca ai modificat deja din panoul de settings.
UPDATE settings SET value = '{"x":461.2,"y":-982.6,"z":30.65}'
    WHERE key = 'police.armory_coords'    AND value = '{"x":462.5,"y":-993.6,"z":26.7}';
UPDATE settings SET value = '{"x":461.2,"y":-987.4,"z":30.65}'
    WHERE key = 'police.cloakroom_coords' AND value = '{"x":458.8,"y":-1000.2,"z":26.7}';
UPDATE settings SET value = '{"x":454.6,"y":-1017.4,"z":28.4,"heading":90.0}'
    WHERE key = 'police.garage_coords'    AND value = '{"x":453.2,"y":-989.3,"z":30.7,"heading":355.0}';
UPDATE settings SET value = '{"x":447.6,"y":-1022.0,"z":28.4,"heading":90.0}'
    WHERE key = 'police.garage_spawn'     AND value = '{"x":453.2,"y":-994.3,"z":30.7,"heading":355.0}';

-- ==================== ITEMS ARMAMENT POLITIE ====================
-- Item-urile cerute de armament trebuie sa existe in registrul `items` (inventory),
-- altfel AddItem respinge cu "Invalid item" si nu se adauga nimic in inventar.
-- weapon_pistol exista deja in seed-ul inventory; restul le adaugam aici.
INSERT INTO items (name, label, weight, type, usable, stackable, description) VALUES
('weapon_stungun',      'Taser',             1.0,  'weapon',  TRUE,  FALSE, 'Arma cu electrosocuri pentru imobilizare.'),
('weapon_nightstick',   'Baston',            0.8,  'weapon',  TRUE,  FALSE, 'Baston de cauciuc pentru autoaparare.'),
('weapon_smg',          'SMG',               2.5,  'weapon',  TRUE,  FALSE, 'Pistol-mitraliera. Necesita munitie SMG.'),
('weapon_carbinerifle', 'Carabina',          3.5,  'weapon',  TRUE,  FALSE, 'Pusca de asalt. Necesita munitie de pusca.'),
('ammo_pistol',         'Munitie Pistol',    0.01, 'ammo',    FALSE, TRUE,  'Cartuse pentru pistol.'),
('ammo_smg',            'Munitie SMG',       0.01, 'ammo',    FALSE, TRUE,  'Cartuse pentru pistol-mitraliera.'),
('ammo_rifle',          'Munitie Pusca',     0.02, 'ammo',    FALSE, TRUE,  'Cartuse pentru pusca.'),
('handcuffs',           'Catuse',            0.3,  'misc',    TRUE,  FALSE, 'Catuse metalice pentru imobilizarea suspectilor.'),
('police_radio',        'Statie Radio',      0.4,  'misc',    TRUE,  TRUE,  'Statie radio pentru comunicatii politie.'),
('police_badge',        'Legitimatie',       0.1,  'misc',    TRUE,  TRUE,  'Legitimatie de politist.'),
('first_aid_kit',       'Trusa Prim-Ajutor', 0.8,  'medical', TRUE,  FALSE, 'Trusa de prim-ajutor.')
ON CONFLICT (name) DO NOTHING;
