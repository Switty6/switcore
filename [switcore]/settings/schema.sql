-- =====================================================
-- switcore-settings: Configurare centralizată key-value
-- =====================================================

CREATE TABLE IF NOT EXISTS settings (
    key         VARCHAR(100) PRIMARY KEY,
    value       TEXT         NOT NULL DEFAULT '',
    type        VARCHAR(20)  NOT NULL DEFAULT 'string',
    label       VARCHAR(200),
    category    VARCHAR(50)  NOT NULL DEFAULT 'general',
    options     TEXT,
    readonly    BOOLEAN      NOT NULL DEFAULT false,
    description TEXT,
    created_at  TIMESTAMPTZ  DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- Seed-uri default (nu suprascrie valorile modificate de admin)
INSERT INTO settings (key, value, description) VALUES

-- Core
('core.playtime_update_interval', '60',    'Cât de des se salvează playtime-ul în DB (secunde)'),
('core.default_language',         'ro',    'Limba implicită a serverului (ro/en)'),
('core.log_commands',             'true',  'Activează logarea comenzilor admin'),
('core.log_level',                'info',  'Nivel minim de logare afișat: debug, info, warn, error'),
('core.ratelimit_enabled',        'true',  'Activează rate limiting-ul pe evenimentele de rețea'),

-- Characters
('characters.max_per_player',          '3',                  'Numărul maxim de personaje per cont'),
('characters.min_age',                 '18',                 'Vârsta minimă a personajului'),
('characters.max_age',                 '80',                 'Vârsta maximă a personajului'),
('characters.enable_deletion',         'true',               'Permite ștergerea personajelor'),
('characters.first_name_min_length',   '2',                  'Lungimea minimă a prenumelui'),
('characters.first_name_max_length',   '20',                 'Lungimea maximă a prenumelui'),
('characters.last_name_min_length',    '2',                  'Lungimea minimă a numelui de familie'),
('characters.last_name_max_length',    '20',                 'Lungimea maximă a numelui de familie'),
('characters.name_pattern',            '^[%w%s%-%''%.]+$',   'Pattern Lua pentru validarea numelui'),
('characters.spawn_x',                 '-269.4',             'Coordonata X a spawn-ului implicit'),
('characters.spawn_y',                 '-955.3',             'Coordonata Y a spawn-ului implicit'),
('characters.spawn_z',                 '31.2',               'Coordonata Z a spawn-ului implicit'),
('characters.spawn_heading',           '205.8',              'Direcția personajului la spawn'),
('characters.spawn',
    '{"x":-269.4,"y":-955.3,"z":31.2,"heading":205.8}',
    'Spawn implicit personaj - cheie compusă {x,y,z,heading} (prioritară față de spawn_x/y/z/heading)'),

-- Inventory
('inventory.max_weight',              '30.0', 'Greutatea maximă a inventarului (kg)'),
('inventory.max_slots',               '40',   'Numărul de sloturi al inventarului'),
('inventory.hotbar_slots',            '5',    'Numărul de sloturi hotbar'),
('inventory.drop_interaction_range',  '2.0',  'Raza de interacțiune cu item-urile droplate (m)'),

-- Banking
('banking.inflation_calculation_interval',          '3600',          'Interval recalculare inflație (secunde)'),
('banking.interest_calculation_interval',           '3600',          'Interval calcul dobânzi (secunde)'),
('banking.log_transactions',                        'true',          'Activează logarea tranzacțiilor'),
('banking.dynamic_exchange_rate_update_interval',   '300',           'Interval actualizare rate de schimb (secunde)'),
('banking.max_dynamic_exchange_rate_fluctuation',   '5.0',           'Fluctuația maximă a ratei de schimb (%)'),
('banking.min_transaction_amount',                  '0.01',          'Suma minimă a unei tranzacții'),
('banking.max_transaction_amount',                  '999999999.99',  'Suma maximă a unei tranzacții'),
('banking.auto_calculate_interest',                 'true',          'Calculează dobânzile automat'),
('banking.inflation_multiplier_enabled',            'true',          'Aplică multiplicatorul de inflație'),
('banking.min_loan_term_months',                    '6',             'Durata minimă a unui credit (luni)'),
('banking.max_loan_term_months',                    '60',            'Durata maximă a unui credit (luni)'),
('banking.min_deposit_term_days',                   '30',            'Durata minimă a unui depozit (zile)'),
('banking.max_deposit_term_days',                   '365',           'Durata maximă a unui depozit (zile)'),
('banking.atm_distance',                            '1.5',           'Distanța de interacțiune ATM (m)'),
('banking.bank_distance',                           '2.0',           'Distanța de interacțiune bancă (m)'),
('banking.account_number_sequence_length',          '12',            'Lungimea secvenței din numărul de cont'),

-- Notifications
('notifications.max_notifications',  '5',             'Numărul maxim de notificări simultane'),
('notifications.default_duration',   '5000',          'Durata implicită a notificărilor (ms)'),
('notifications.position',           'right-middle',  'Poziția notificărilor pe ecran'),

-- HUD
('hud.primary_currency',       'USD',   'Moneda principală afișată în HUD'),
('hud.primary_symbol',         '$',     'Simbolul monedei principale'),
('hud.max_speed',              '240',   'Viteza maximă a vitezometrului (km/h)'),
('hud.tick_interval',          '333',   'Intervalul de actualizare a HUD-ului (ms)'),
('hud.hide_native_hud',        'true',  'Ascunde HUD-ul nativ FiveM'),
('hud.component_stats',        'true',  'Afișează bara de stats (HP/armor/hunger/thirst)'),
('hud.component_cash',         'true',  'Afișează cash-ul în HUD'),
('hud.component_time',         'true',  'Afișează ceasul în HUD'),
('hud.component_speedometer',  'true',  'Afișează vitezometrul în vehicul'),

-- Proximity
('proximity.proximity_distance',  '2.0',   'Distanța de detecție proximity (m)'),
('proximity.show_marker',         'true',  'Afișează markere la punctele de interacțiune'),
('proximity.show_text',           'true',  'Afișează text la punctele de interacțiune'),
('proximity.debug',               'false', 'Modul debug proximity'),

-- Needs
('needs.hunger_decay_rate',   '0.5',  'Cât scade hunger-ul per interval'),
('needs.thirst_decay_rate',   '0.8',  'Cât scade thirst-ul per interval'),
('needs.damage_threshold',    '10.0', 'Sub ce valoare se aplică damage (HP)'),
('needs.damage_amount',       '2',    'HP scos per interval când hunger/thirst e critic'),
('needs.update_interval',     '60',   'Intervalul de scădere hunger/thirst (secunde)'),
('needs.save_interval',       '300',  'Intervalul de salvare în DB (secunde)'),

-- ── Blips ─────────────────────────────────────────────────────────────────────
('blips.enabled',              'true',  'Activează sistemul de blipuri pe hartă'),
('blips.marker_draw_distance', '30.0',  'Distanța de desenare a markerelor 3D (GTA units)'),
('blips.banking',
    '{"sprite":108,"color":34,"scale":0.8,"label":"Bancă","showMarker":true,"markerType":1,"markerColor":{"r":0,"g":180,"b":255,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
    'Configurație blip bancă (sprite/color/scale/label/marker)'),
('blips.garages',
    '{"sprite":357,"color":2,"scale":0.8,"label":"Garaj","showMarker":true,"markerType":1,"markerColor":{"r":0,"g":255,"b":100,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
    'Configurație blip garaj (sprite/color/scale/label/marker)'),
('blips.impound',
    '{"sprite":68,"color":1,"scale":0.8,"label":"Sechestru","showMarker":true,"markerType":1,"markerColor":{"r":255,"g":60,"b":60,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
    'Configurație blip sechestru (sprite/color/scale/label/marker)'),
('blips.showroom',
    '{"sprite":326,"color":5,"scale":0.8,"label":"Showroom","showMarker":true,"markerType":1,"markerColor":{"r":255,"g":200,"b":0,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
    'Configurație blip showroom/dealership (sprite/color/scale/label/marker)'),

-- ── Garages ───────────────────────────────────────────────────────────────────
('garages.interaction_distance',     '2.5',          'Raza de interacțiune cu garajul (metri)'),
('garages.impound_release_fee',      '2500',         'Taxă de ridicare vehicul din sechestru (RON)'),
('garages.parking_ticket_base_fine', '500',          'Amendă de bază pentru parcare neregulamentară (RON)'),
('garages.impound_garage_code',      'IMPOUND_LSIA', 'Codul garajului de sechestru (din tabela garages)'),
('garages.locations',
    '[{"code":"PUBLIC_MROW","name":"Garaj Public - Mission Row","type":"public","coords":{"x":215.36,"y":-809.56,"z":29.73},"spawnPoint":{"x":213.0,"y":-816.0,"z":29.73,"heading":0.0}},{"code":"PUBLIC_MWOOD","name":"Garaj Public - Morningwood","type":"public","coords":{"x":-1085.02,"y":-328.57,"z":13.94},"spawnPoint":{"x":-1088.0,"y":-335.0,"z":13.94,"heading":180.0}},{"code":"PUBLIC_AIRP","name":"Garaj Public - Aeroport","type":"public","coords":{"x":-1037.0,"y":-2738.0,"z":20.17},"spawnPoint":{"x":-1040.0,"y":-2745.0,"z":20.17,"heading":90.0}},{"code":"IMPOUND_LSIA","name":"Parc Sechestru LSIA","type":"impound","coords":{"x":444.12,"y":-1020.38,"z":28.39},"spawnPoint":{"x":448.0,"y":-1027.0,"z":28.39,"heading":90.0}}]',
    'Lista locațiilor de garaje (JSON array - se populează automat din tabela garages)'),

-- ── Showroom / Dealership ─────────────────────────────────────────────────────
('showroom.default_loan_type',           'personal', 'Tipul implicit de credit la finanțare showroom'),
('showroom.default_finance_bank_code',   'MAZE',     'Codul băncii implicite pentru finanțare'),
('showroom.default_finance_term_months', '24',       'Numărul implicit de luni pentru credit showroom'),
('showroom.finance_interest_rate',       '0.08',     'Rata dobânzii implicită la finanțare (0.0–1.0)'),
('showroom.finance_min_price',           '5000',     'Prețul minim al vehiculului pentru a permite finanțarea (RON)'),
('showroom.test_drive_duration_minutes', '5',        'Durata test drive (minute)'),
('showroom.dealership_locations',
    '[{"code":"PDM","name":"Premium Deluxe Motorsport","coords":{"x":-47.09,"y":-1098.67,"z":26.42},"npcModel":"a_m_m_business_01","testDriveSpawn":{"x":-33.0,"y":-1095.0,"z":26.42,"heading":340.0}},{"code":"LEGACY","name":"Legacy Motorsport","coords":{"x":-1393.1,"y":-626.5,"z":30.9},"npcModel":"a_m_m_business_02","testDriveSpawn":{"x":-1380.0,"y":-630.0,"z":30.9,"heading":200.0}}]',
    'Locațiile dealershipurilor (JSON array cu {name, coords: {x,y,z,heading}})'),
('showroom.vehicle_catalog',
    '[]',
    'Catalogul vehiculelor disponibile în showroom (JSON array cu {model, label, price, category})'),

-- ── Jobs ──────────────────────────────────────────────────────────────────────
('jobs.default_job',     'unemployed', 'Jobul implicit la crearea unui personaj'),
('jobs.default_grade',   '0',          'Gradul implicit la atribuirea jobului implicit'),
('jobs.salary_interval', '1800000',    'Intervalul de plată a salariului (ms - 1800000 = 30 min)'),

-- ── Vehicles ──────────────────────────────────────────────────────────────────
('vehicles.save_interval',         '30000', 'Intervalul de salvare a stării vehiculelor în DB (ms)'),
('vehicles.fuel_price_per_liter',  '3.5',   'Prețul combustibilului per litru (RON)'),
('vehicles.default_currency_code', 'RON',   'Codul valutei implicite pentru tranzacții vehicule'),
('vehicles.plate.pattern',         'SW-%05d',   'Pattern plăcuțe: %05d (număr secvențial), ^ (literă random), # (cifră random)'),


-- ── Tuning ────────────────────────────────────────────────────────────────────
('tuning.vip_discount',       '0.15', 'Discount pentru jucătorii VIP la tuning (0.0–1.0)'),
('tuning.color_change_cost',  '500',  'Costul schimbării culorii vehiculului (RON)'),
('tuning.livery_change_cost', '1000', 'Costul schimbării livery-ului vehiculului (RON)'),
('tuning.reset_mods_cost',    '1500', 'Costul resetării tuturor modificărilor (RON)'),

-- ── Banking ──────────────────────────────────
('banking.atm_models',
    '["prop_atm_01","prop_atm_02","prop_atm_03","prop_fleeca_atm"]',
    'Modelele de prop ATM recunoscute pe hartă (JSON array)'),
('banking.bank_locations',
    '[{"x":149.47,"y":-1040.46,"z":29.37,"heading":0,"label":"Fleeca Bank - Hawick","bankCode":"FLEC"},{"x":314.19,"y":-278.73,"z":54.16,"heading":0,"label":"Fleeca Bank - Burton","bankCode":"FLEC"},{"x":-350.99,"y":-49.99,"z":49.04,"heading":0,"label":"Fleeca Bank - Rockford Hills","bankCode":"FLEC"},{"x":-1212.98,"y":-330.77,"z":37.79,"heading":0,"label":"Fleeca Bank - Morningwood","bankCode":"FLEC"},{"x":-2962.58,"y":482.63,"z":15.70,"heading":0,"label":"Fleeca Bank - Great Ocean Highway","bankCode":"FLEC"},{"x":1175.07,"y":2706.42,"z":38.09,"heading":0,"label":"Fleeca Bank - Route 68","bankCode":"FLEC"},{"x":247.03,"y":223.78,"z":106.29,"heading":0,"label":"Maze Bank Tower","bankCode":"MAZE"},{"x":-75.01,"y":-818.22,"z":326.18,"heading":0,"label":"Maze Bank West","bankCode":"MAZE"}]',
    'Locațiile fizice ale băncilor pe hartă (JSON array cu {x,y,z,label})'),
('banking.default_banks',
    '[{"name":"Maze Bank","code":"MAZE","is_active":true},{"name":"Fleeca Bank","code":"FLEC","is_active":true}]',
    'Băncile create automat la prima pornire (JSON array)'),
('banking.default_currencies',
    '[{"code":"RON","name":"Leu Românesc","symbol":"RON"},{"code":"EUR","name":"Euro","symbol":"€"}]',
    'Valutele create automat la prima pornire (JSON array)'),
('banking.default_bank_fees',
    '{"transfer_same_bank":{"fee_type_value":"fixed","fee_amount":0},"transfer_different_bank":{"fee_type_value":"percentage","fee_amount":1.5},"withdrawal":{"fee_type_value":"fixed","fee_amount":5},"deposit":{"fee_type_value":"fixed","fee_amount":0},"currency_exchange":{"fee_type_value":"percentage","fee_amount":2}}',
    'Comisioanele implicite ale băncilor la prima pornire (JSON object pe tip de comision)')

ON CONFLICT (key) DO NOTHING;

-- ── Trigger: auto-update settings.updated_at la fiecare modificare ───────────
CREATE OR REPLACE FUNCTION fn_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_settings_updated_at ON settings;
CREATE TRIGGER trg_settings_updated_at
    BEFORE UPDATE ON settings
    FOR EACH ROW
    EXECUTE FUNCTION fn_settings_updated_at();

