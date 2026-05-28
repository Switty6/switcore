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
('police.armory_coords',     '{"x":462.5,"y":-993.6,"z":26.7}',                  'Coordonate dulap armament'),
('police.armory_radius',     '1.5',                                               'Raza de interactiune cu armamentul (metri)'),
('police.cloakroom_coords',  '{"x":458.8,"y":-1000.2,"z":26.7}',                 'Coordonate vestiar politie'),
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
 '{"x":453.2,"y":-989.3,"z":30.7,"heading":355.0}',
 'Coordonate garaj politie (x,y,z,heading)'),
('police.garage_radius',  '5.0', 'Raza de interactiune garaj politie (metri)'),
('police.garage_spawn',
 '{"x":453.2,"y":-994.3,"z":30.7,"heading":355.0}',
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
 'Configurare blip inchisoare (JSON)')

ON CONFLICT (key) DO NOTHING;
