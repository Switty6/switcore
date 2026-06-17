-- settings si core se referentiaza reciproc, asa ca nu putem garanta ca core
-- e pornit cand se incarca scriptul asta. Asteptam sa fie 'started' inainte de
-- a-i apela exportul, altfel apelul sincron arunca si opreste restul fisierului
-- (inclusiv inregistrarea exportului IsReady, de care depind toate modulele).
CreateThread(function()
    while GetResourceState('core') ~= 'started' do Wait(50) end
    exports.core:registerModuleLocales(GetCurrentResourceName())
end)

local cache    = {}
local cacheMeta = {}
local isLoaded = false

local function applySchema()
    exports.postgres:query([[
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
        )
    ]], {})

    exports.postgres:query([[
        DO $$
        BEGIN
            ALTER TABLE settings ADD COLUMN IF NOT EXISTS type        VARCHAR(20)  NOT NULL DEFAULT 'string';
            ALTER TABLE settings ADD COLUMN IF NOT EXISTS label       VARCHAR(200);
            ALTER TABLE settings ADD COLUMN IF NOT EXISTS category    VARCHAR(50)  NOT NULL DEFAULT 'general';
            ALTER TABLE settings ADD COLUMN IF NOT EXISTS options     TEXT;
            ALTER TABLE settings ADD COLUMN IF NOT EXISTS readonly    BOOLEAN      NOT NULL DEFAULT false;
        END $$;
    ]], {})
end

local function seedSettings()
    exports.postgres:query([[
        INSERT INTO settings (key, value, type, label, category, options, readonly, description) VALUES
        ('core.playtime_update_interval',                '60',             'number',  'Interval salvare playtime',              'core',          NULL,                                              false, 'Cât de des se salvează playtime-ul în DB (secunde)'),
        ('core.default_language',                        'ro',             'enum',    'Limbă implicită',                        'core',          '["ro","en"]',                                     false, 'Limba implicită a serverului'),
        ('core.log_commands',                            'true',           'boolean', 'Logare comenzi admin',                   'core',          NULL,                                              false, 'Activează logarea comenzilor admin'),
        ('characters.max_per_player',                    '3',              'number',  'Personaje per cont',                     'characters',    NULL,                                              false, 'Numărul maxim de personaje per cont'),
        ('characters.min_age',                           '18',             'number',  'Vârstă minimă personaj',                 'characters',    NULL,                                              false, 'Vârsta minimă a personajului'),
        ('characters.max_age',                           '80',             'number',  'Vârstă maximă personaj',                 'characters',    NULL,                                              false, 'Vârsta maximă a personajului'),
        ('characters.enable_deletion',                   'true',           'boolean', 'Permite ștergerea personajelor',         'characters',    NULL,                                              false, 'Permite ștergerea personajelor'),
        ('characters.first_name_min_length',             '2',              'number',  'Lungime minimă prenume',                 'characters',    NULL,                                              false, 'Lungimea minimă a prenumelui'),
        ('characters.first_name_max_length',             '20',             'number',  'Lungime maximă prenume',                 'characters',    NULL,                                              false, 'Lungimea maximă a prenumelui'),
        ('characters.last_name_min_length',              '2',              'number',  'Lungime minimă nume familie',            'characters',    NULL,                                              false, 'Lungimea minimă a numelui de familie'),
        ('characters.last_name_max_length',              '20',             'number',  'Lungime maximă nume familie',            'characters',    NULL,                                              false, 'Lungimea maximă a numelui de familie'),
        ('characters.name_pattern',                      '^[%w%s%-%''%.]+$','string', 'Pattern validare nume',                  'characters',    NULL,                                              false, 'Pattern Lua pentru validarea numelui'),
        ('characters.spawn_x',                           '-269.4',         'number',  'Spawn X',                                'characters',    NULL,                                              false, 'Coordonata X a spawn-ului implicit'),
        ('characters.spawn_y',                           '-955.3',         'number',  'Spawn Y',                                'characters',    NULL,                                              false, 'Coordonata Y a spawn-ului implicit'),
        ('characters.spawn_z',                           '31.2',           'number',  'Spawn Z',                                'characters',    NULL,                                              false, 'Coordonata Z a spawn-ului implicit'),
        ('characters.spawn_heading',                     '205.8',          'number',  'Spawn Heading',                          'characters',    NULL,                                              false, 'Direcția personajului la spawn'),
        ('inventory.max_weight',                         '30.0',           'number',  'Greutate maximă inventar (kg)',           'inventory',     NULL,                                              false, 'Greutatea maximă a inventarului'),
        ('inventory.max_slots',                          '40',             'number',  'Sloturi inventar',                       'inventory',     NULL,                                              false, 'Numărul de sloturi al inventarului'),
        ('inventory.hotbar_slots',                       '5',              'number',  'Sloturi hotbar',                         'inventory',     NULL,                                              false, 'Numărul de sloturi hotbar'),
        ('inventory.drop_interaction_range',             '2.0',            'number',  'Rază interacțiune drop (m)',             'inventory',     NULL,                                              false, 'Raza de interacțiune cu item-urile droplate'),
        ('banking.inflation_calculation_interval',       '3600',           'number',  'Interval calcul inflație (s)',           'banking',       NULL,                                              false, 'Interval recalculare inflație (secunde)'),
        ('banking.interest_calculation_interval',        '3600',           'number',  'Interval calcul dobânzi (s)',            'banking',       NULL,                                              false, 'Interval calcul dobânzi (secunde)'),
        ('banking.log_transactions',                     'true',           'boolean', 'Logare tranzacții',                     'banking',       NULL,                                              false, 'Activează logarea tranzacțiilor'),
        ('banking.dynamic_exchange_rate_update_interval','300',            'number',  'Interval actualizare curs schimb (s)',   'banking',       NULL,                                              false, 'Interval actualizare rate de schimb (secunde)'),
        ('banking.max_dynamic_exchange_rate_fluctuation','5.0',            'number',  'Fluctuație maximă curs schimb (%)',      'banking',       NULL,                                              false, 'Fluctuația maximă a ratei de schimb (%)'),
        ('banking.exchange_rate_transaction_period_hours','24',            'number',  'Perioadă volum tranzacții (ore)',         'banking',       NULL,                                              false, 'Perioada pentru calculul volumului tranzacțiilor'),
        ('banking.min_transaction_amount',               '0.01',           'number',  'Sumă minimă tranzacție',                 'banking',       NULL,                                              false, 'Suma minimă a unei tranzacții'),
        ('banking.max_transaction_amount',               '999999999.99',   'number',  'Sumă maximă tranzacție',                 'banking',       NULL,                                              false, 'Suma maximă a unei tranzacții'),
        ('banking.auto_calculate_interest',              'true',           'boolean', 'Calculare automată dobânzi',             'banking',       NULL,                                              false, 'Calculează dobânzile automat'),
        ('banking.inflation_multiplier_enabled',         'true',           'boolean', 'Multiplier inflație activat',           'banking',       NULL,                                              false, 'Aplică multiplicatorul de inflație'),
        ('banking.min_loan_term_months',                 '6',              'number',  'Termen minim credit (luni)',              'banking',       NULL,                                              false, 'Durata minimă a unui credit'),
        ('banking.max_loan_term_months',                 '60',             'number',  'Termen maxim credit (luni)',              'banking',       NULL,                                              false, 'Durata maximă a unui credit'),
        ('banking.loan_rate_personal',                   '12.0',           'number',  'Dobândă credit personal (%)',            'banking',       NULL,                                              false, 'Dobânda anuală pentru credite personale'),
        ('banking.loan_rate_mortgage',                   '6.0',            'number',  'Dobândă credit ipotecar (%)',            'banking',       NULL,                                              false, 'Dobânda anuală pentru credite ipotecare'),
        ('banking.loan_rate_business',                   '8.0',            'number',  'Dobândă credit business (%)',            'banking',       NULL,                                              false, 'Dobânda anuală pentru credite business'),
        ('banking.min_deposit_term_days',                '30',             'number',  'Termen minim depozit (zile)',             'banking',       NULL,                                              false, 'Durata minimă a unui depozit'),
        ('banking.max_deposit_term_days',                '365',            'number',  'Termen maxim depozit (zile)',             'banking',       NULL,                                              false, 'Durata maximă a unui depozit'),
        ('banking.interest_rate_current',                '0.0',            'number',  'Dobândă cont curent (%)',                'banking',       NULL,                                              false, 'Dobânda anuală pentru conturi curente'),
        ('banking.interest_rate_savings',                '2.5',            'number',  'Dobândă cont economii (%)',              'banking',       NULL,                                              false, 'Dobânda anuală pentru conturi de economii'),
        ('banking.interest_rate_deposit',                '5.0',            'number',  'Dobândă depozit (%)',                    'banking',       NULL,                                              false, 'Dobânda anuală pentru depozite'),
        ('banking.atm_distance',                         '1.5',            'number',  'Distanță interacțiune ATM (m)',          'banking',       NULL,                                              false, 'Distanța de interacțiune ATM'),
        ('banking.bank_distance',                        '2.0',            'number',  'Distanță interacțiune bancă (m)',        'banking',       NULL,                                              false, 'Distanța de interacțiune bancă'),
        ('banking.account_number_sequence_length',       '12',             'number',  'Lungime secvență număr cont',            'banking',       NULL,                                              false, 'Lungimea secvenței din numărul de cont'),
        ('notifications.max_notifications',              '5',              'number',  'Notificări simultane maxime',            'notifications', NULL,                                              false, 'Numărul maxim de notificări simultane'),
        ('notifications.default_duration',               '5000',           'number',  'Durată notificare (ms)',                 'notifications', NULL,                                              false, 'Durata implicită a notificărilor'),
        ('notifications.position',                       'right-middle',   'enum',    'Poziție notificări',                     'notifications', '["top-left","top-right","bottom-left","bottom-right","right-middle","left-middle"]', false, 'Poziția notificărilor pe ecran'),
        ('hud.primary_currency',                         'USD',            'string',  'Monedă principală',                      'hud',           NULL,                                              false, 'Moneda principală afișată în HUD'),
        ('hud.primary_symbol',                           '$',              'string',  'Simbol monedă principală',               'hud',           NULL,                                              false, 'Simbolul monedei principale'),
        ('hud.max_speed',                                '240',            'number',  'Viteză maximă vitezometru',              'hud',           NULL,                                              false, 'Viteza maximă a vitezometrului (km/h)'),
        ('hud.tick_interval',                            '333',            'number',  'Interval actualizare HUD (ms)',           'hud',           NULL,                                              false, 'Intervalul de actualizare a HUD-ului'),
        ('hud.hide_native_hud',                          'true',           'boolean', 'Ascunde HUD nativ FiveM',                'hud',           NULL,                                              false, 'Ascunde HUD-ul nativ FiveM'),
        ('hud.component_stats',                          'true',           'boolean', 'Componentă stats',                       'hud',           NULL,                                              false, 'Afișează bara de stats (HP/armor/hunger/thirst)'),
        ('hud.component_cash',                           'true',           'boolean', 'Componentă cash',                        'hud',           NULL,                                              false, 'Afișează cash-ul în HUD'),
        ('hud.component_time',                           'true',           'boolean', 'Componentă ceas',                        'hud',           NULL,                                              false, 'Afișează ceasul în HUD'),
        ('hud.component_speedometer',                    'true',           'boolean', 'Componentă vitezometru',                 'hud',           NULL,                                              false, 'Afișează vitezometrul în vehicul'),
        ('proximity.proximity_distance',                 '2.0',            'number',  'Distanță detecție proximity (m)',         'proximity',     NULL,                                              false, 'Distanța de detecție proximity'),
        ('proximity.show_marker',                        'true',           'boolean', 'Afișează markere',                      'proximity',     NULL,                                              false, 'Afișează markere la punctele de interacțiune'),
        ('proximity.show_text',                          'true',           'boolean', 'Afișează text',                          'proximity',     NULL,                                              false, 'Afișează text la punctele de interacțiune'),
        ('proximity.debug',                              'false',          'boolean', 'Modul debug proximity',                  'proximity',     NULL,                                              false, 'Modul debug proximity'),
        ('needs.hunger_decay_rate',                      '2.0',            'number',  'Rată scădere hunger',                    'needs',         NULL,                                              false, 'Cât scade hunger-ul per interval'),
        ('needs.thirst_decay_rate',                      '3.0',            'number',  'Rată scădere thirst',                    'needs',         NULL,                                              false, 'Cât scade thirst-ul per interval'),
        ('needs.damage_threshold',                       '10.0',           'number',  'Prag damage',                            'needs',         NULL,                                              false, 'Sub ce valoare se aplică damage'),
        ('needs.damage_amount',                          '2',              'number',  'HP scos per interval',                   'needs',         NULL,                                              false, 'HP scos per interval când e critic'),
        ('needs.update_interval',                        '60',             'number',  'Interval scădere hunger/thirst (s)',     'needs',         NULL,                                              false, 'Intervalul de scădere hunger/thirst'),
        ('needs.save_interval',                          '300',            'number',  'Interval salvare needs în DB (s)',        'needs',         NULL,                                              false, 'Intervalul de salvare în DB')
        ON CONFLICT (key) DO UPDATE SET
            type        = EXCLUDED.type,
            label       = EXCLUDED.label,
            category    = EXCLUDED.category,
            options     = EXCLUDED.options,
            readonly    = EXCLUDED.readonly,
            description = EXCLUDED.description
    ]], {})

    exports.postgres:query([[
        INSERT INTO settings (key, value, type, label, category, options, readonly, description) VALUES
        ('vehicles.save_interval',                   '30000',          'number',  'Interval salvare vehicule (ms)',          'vehicles',   NULL,                                              false, 'Cat de des se salveaza starea vehiculelor in DB'),
        ('vehicles.fuel_price_per_liter',            '3.5',            'number',  'Pret combustibil per litru',              'vehicles',   NULL,                                              false, 'Pretul combustibilului per litru'),
        ('vehicles.plate.pattern',                   'SW-%05d',        'plate_format', 'Format plăcuță',                          'vehicles',   NULL,                                              false, 'Pattern: %d (număr secvențial), ^ (literă random), # (cifră random)'),
        ('vehicles.categories',                      '["compacts","sedans","suvs","coupes","muscle","sports","super","motorcycles","offroad","industrial","vans","service","emergency","military","boats","helicopters","planes"]', 'json', 'Categorii vehicule', 'vehicles', NULL, false, 'Lista categoriilor de vehicule valide'),
        ('garages.impound_release_fee',              '2500',           'number',  'Taxa eliberare sechestru',                'garages',    NULL,                                              false, 'Taxa pentru eliberarea unui vehicul sechestrat'),
        ('garages.parking_ticket_base_fine',         '500',            'number',  'Amenda de baza parcare ilegala',          'garages',    NULL,                                              false, 'Amenda de baza pentru parcare ilegala'),
        ('garages.max_tickets_before_impound',       '3',              'number',  'Amenzi inainte de sechestru',             'garages',    NULL,                                              false, 'Nr. amenzi neplatite inainte de sechestru automat'),
        ('garages.impound_garage_code',              'IMPOUND_LSIA',   'string',  'Cod garaj sechestru',                     'garages',    NULL,                                              false, 'Codul garajului de sechestru'),
        ('garages.interaction_distance',             '2.5',            'number',  'Distanta interactiune garaj (m)',         'garages',    NULL,                                              false, 'Distanta de interactiune cu garajul'),
        ('garages.locations',                        '[{"code":"PUBLIC_MROW","name":"Garaj Public - Mission Row","type":"public","coords":{"x":215.36,"y":-809.56,"z":29.73},"spawnPoint":{"x":213.0,"y":-816.0,"z":29.73,"heading":0.0}},{"code":"PUBLIC_MWOOD","name":"Garaj Public - Morningwood","type":"public","coords":{"x":-1085.02,"y":-328.57,"z":13.94},"spawnPoint":{"x":-1088.0,"y":-335.0,"z":13.94,"heading":180.0}},{"code":"PUBLIC_AIRP","name":"Garaj Public - Aeroport","type":"public","coords":{"x":-1037.0,"y":-2738.0,"z":20.17},"spawnPoint":{"x":-1040.0,"y":-2745.0,"z":20.17,"heading":90.0}},{"code":"IMPOUND_LSIA","name":"Parc Sechestru LSIA","type":"impound","coords":{"x":444.12,"y":-1020.38,"z":28.39},"spawnPoint":{"x":448.0,"y":-1027.0,"z":28.39,"heading":90.0}}]', 'garage_list', 'Locatii garaje', 'garages', NULL, false, 'Locatiile garajelor publice si sechestrelor'),
        ('showroom.test_drive_duration_minutes',     '5',              'number',  'Durata test drive (min)',                 'showroom',   NULL,                                              false, 'Durata unui test drive in minute'),
        ('showroom.finance_min_price',               '5000',           'number',  'Pret minim finantare',                   'showroom',   NULL,                                              false, 'Pretul minim eligibil pentru finantare'),
        ('showroom.default_finance_bank_code',       'MAZE',           'string',  'Banca finantare implicita',               'showroom',   NULL,                                              false, 'Codul bancii folosite pentru credite auto'),
        ('showroom.default_loan_type',               'personal',       'enum',    'Tip credit implicit',                     'showroom',   '["personal","mortgage","business"]',              false, 'Tipul creditului implicit pentru finantare auto'),
        ('showroom.default_finance_term_months',     '24',             'number',  'Termen finantare implicit (luni)',        'showroom',   NULL,                                              false, 'Durata implicita a finantarii in luni'),
        ('showroom.finance_interest_rate',           '0.08',           'number',  'Dobanda finantare (0.0-1.0)',             'showroom',   NULL,                                              false, 'Rata anuala a dobanzii pentru finantare auto'),
        ('showroom.default_currency_code',           'USD',            'string',  'Valuta implicita showroom',               'showroom',   NULL,                                              false, 'Valuta folosita pentru preturi in showroom'),
        ('proximity.interaction_key_name',           'E',              'string',  'Tasta interactiune',                      'proximity',  NULL,                                              false, 'Tasta folosita pentru confirmare interactiune'),
        ('proximity.mouse_toggle_key',               'LMENU',          'string',  'Tasta toggle mouse',                      'proximity',  NULL,                                              false, 'Tasta pentru activarea navigarii cu mouse-ul'),
        ('proximity.mouse_toggle_key_description',   'Toggle Mouse Navigation', 'string', 'Descriere tasta mouse',           'proximity',  NULL,                                              false, 'Descrierea tastei de toggle mouse'),
        ('proximity.marker_color',                   '{"r":0,"g":255,"b":0,"a":200}', 'json', 'Culoare marker proximity',    'proximity',  NULL,                                              false, 'Culoarea RGBA a markerelor de interactiune'),
        ('proximity.text_offset',                    '{"x":0.0,"y":0.0,"z":0.5}',    'json', 'Offset text proximity',       'proximity',  NULL,                                              false, 'Offset-ul textului fata de pozitia de interactiune'),
        ('proximity.entity_offset',                  '{"x":0.0,"y":0.0,"z":0.5}',    'json', 'Offset entitate proximity',   'proximity',  NULL,                                              false, 'Offset-ul fata de entitate'),
        ('core.identifier_blocklist',                '["ip"]',         'json',    'Blocklist identificatori',                'core',       NULL,                                              false, 'Identificatori ignorati la autentificare'),
        ('core.default_groups',                      '[{"name":"player","display_name":"Player","priority":0,"description":"Grupul default"},{"name":"vip","display_name":"VIP","priority":10,"description":"VIP"},{"name":"moderator","display_name":"Moderator","priority":50,"description":"Moderator"},{"name":"admin","display_name":"Administrator","priority":100,"description":"Administrator"}]', 'json', 'Grupuri implicite (seed)', 'core', NULL, false, 'Grupurile create automat la prima initializare'),
        ('core.default_group_permissions',           '{"admin":["admin.all","admin.kick","admin.ban","admin.warn","admin.teleport","admin.vehicle","admin.money","admin.weapon"],"moderator":["moderator.kick","moderator.warn","moderator.ban","moderator.teleport"],"vip":["vip.vehicle","vip.weapon"],"player":[]}', 'json', 'Permisiuni grupuri (seed)', 'core', NULL, false, 'Permisiunile default per grup'),
        ('characters.creator_room',                  '{"camera":{"x":198.0,"y":-802.5,"z":32.1,"fov":50.0},"child":{"x":198.0,"y":-809.0,"z":30.6,"heading":0.0},"father":{"x":200.5,"y":-810.5,"z":30.6,"heading":343.0},"mother":{"x":195.5,"y":-810.5,"z":30.6,"heading":17.0},"lookAt":{"x":198.0,"y":-810.0,"z":31.85}}', 'json', 'Configurare camera creator personaj', 'characters', NULL, false, 'Pozitiile camerei si ped-urilor in ecranul de creare personaj'),
        ('inventory.default_drop_prop',              'prop_paper_bag_01', 'string', 'Prop drop implicit',                   'inventory',  NULL,                                              false, 'Model prop folosit la aruncarea item-urilor pe jos')
        ON CONFLICT (key) DO UPDATE SET
            type        = EXCLUDED.type,
            label       = EXCLUDED.label,
            category    = EXCLUDED.category,
            options     = EXCLUDED.options,
            readonly    = EXCLUDED.readonly,
            description = EXCLUDED.description
    ]], {})

    Wait(100)

    exports.postgres:query([[
        INSERT INTO settings (key, value, type, label, category, options, readonly, description) VALUES
        (
            'showroom.dealership_locations',
            '[{"code":"PDM","name":"Premium Deluxe Motorsport","coords":{"x":-47.09,"y":-1098.67,"z":26.42},"npcModel":"a_m_m_business_01","testDriveSpawn":{"x":-33.0,"y":-1095.0,"z":26.42,"heading":340.0}},{"code":"LEGACY","name":"Legacy Motorsport","coords":{"x":-1393.1,"y":-626.5,"z":30.9},"npcModel":"a_m_m_business_02","testDriveSpawn":{"x":-1380.0,"y":-630.0,"z":30.9,"heading":200.0}}]',
            'dealer_list', 'Locatii dealership-uri', 'showroom', NULL, false, 'Locatiile dealership-urilor si configurarea NPC-urilor'
        ),
        (
            'showroom.vehicle_catalog',
            '[{"dealership":"PDM","model":"sultan","label":"Karin Sultan RS","category":"Sport","price":35000,"financeEligible":true,"vipOnly":false,"sortOrder":1},{"dealership":"PDM","model":"jester","label":"Dinka Jester Classic","category":"Sport","price":42000,"financeEligible":true,"vipOnly":false,"sortOrder":2},{"dealership":"PDM","model":"elegy2","label":"Annis Elegy RH8","category":"Sport","price":58000,"financeEligible":true,"vipOnly":false,"sortOrder":3},{"dealership":"PDM","model":"adder","label":"Truffade Adder","category":"Super","price":150000,"financeEligible":true,"vipOnly":false,"sortOrder":10},{"dealership":"PDM","model":"entityxf","label":"Overflod Entity XF","category":"Super","price":195000,"financeEligible":true,"vipOnly":false,"sortOrder":11},{"dealership":"PDM","model":"t20","label":"Progen T20","category":"Super","price":220000,"financeEligible":true,"vipOnly":true,"sortOrder":12},{"dealership":"PDM","model":"zentorno","label":"Pegassi Zentorno","category":"Super","price":185000,"financeEligible":true,"vipOnly":false,"sortOrder":13},{"dealership":"PDM","model":"jackal","label":"Obey Jackal","category":"Sedan","price":25000,"financeEligible":true,"vipOnly":false,"sortOrder":20},{"dealership":"PDM","model":"oracle2","label":"Ubermacht Oracle XS","category":"Sedan","price":30000,"financeEligible":true,"vipOnly":false,"sortOrder":21},{"dealership":"PDM","model":"granger","label":"Declasse Granger","category":"SUV","price":32000,"financeEligible":true,"vipOnly":false,"sortOrder":30},{"dealership":"PDM","model":"baller","label":"Albany Baller","category":"SUV","price":36000,"financeEligible":true,"vipOnly":false,"sortOrder":31},{"dealership":"LEGACY","model":"bf400","label":"BF400","category":"Moto","price":14000,"financeEligible":false,"vipOnly":false,"sortOrder":1},{"dealership":"LEGACY","model":"akuma","label":"Dinka Akuma","category":"Moto","price":9000,"financeEligible":false,"vipOnly":false,"sortOrder":2},{"dealership":"LEGACY","model":"bati","label":"Pegassi Bati 801","category":"Moto","price":15000,"financeEligible":false,"vipOnly":false,"sortOrder":3},{"dealership":"LEGACY","model":"packer","label":"Jobuilt Packer","category":"Camion","price":55000,"financeEligible":true,"vipOnly":false,"sortOrder":10},{"dealership":"LEGACY","model":"phantom","label":"Jobuilt Phantom","category":"Camion","price":62000,"financeEligible":true,"vipOnly":false,"sortOrder":11}]',
            'json', 'Catalog vehicule (seed)', 'showroom', NULL, false, 'Vehiculele disponibile in showroom la prima initializare'
        )
        ON CONFLICT (key) DO UPDATE SET
            value       = CASE WHEN settings.value IS NULL OR settings.value IN ('[]', '{}', '', 'null')
                               THEN EXCLUDED.value ELSE settings.value END,
            type        = EXCLUDED.type,
            label       = EXCLUDED.label,
            category    = EXCLUDED.category,
            options     = EXCLUDED.options,
            readonly    = EXCLUDED.readonly,
            description = EXCLUDED.description
    ]], {})

    exports.postgres:query([[
        INSERT INTO settings (key, value, type, label, category, options, readonly, description) VALUES
        (
            'banking.atm_models',
            '["prop_atm_01","prop_atm_02","prop_atm_03","prop_fleeca_atm"]',
            'model_list',
            'Modele ATM',
            'banking',
            NULL,
            false,
            'Lista de modele prop pentru ATM-uri'
        ),
        (
            'banking.bank_locations',
            '[{"x":149.47,"y":-1040.46,"z":29.37,"heading":0,"label":"Fleeca Bank - Hawick","bankCode":"FLEC"},{"x":314.19,"y":-278.73,"z":54.16,"heading":0,"label":"Fleeca Bank - Burton","bankCode":"FLEC"},{"x":-350.99,"y":-49.99,"z":49.04,"heading":0,"label":"Fleeca Bank - Rockford Hills","bankCode":"FLEC"},{"x":-1212.98,"y":-330.77,"z":37.79,"heading":0,"label":"Fleeca Bank - Morningwood","bankCode":"FLEC"},{"x":-2962.58,"y":482.63,"z":15.70,"heading":0,"label":"Fleeca Bank - Great Ocean Highway","bankCode":"FLEC"},{"x":1175.07,"y":2706.42,"z":38.09,"heading":0,"label":"Fleeca Bank - Route 68","bankCode":"FLEC"},{"x":247.03,"y":223.78,"z":106.29,"heading":0,"label":"Maze Bank Tower","bankCode":"MAZE"},{"x":-75.01,"y":-818.22,"z":326.18,"heading":0,"label":"Maze Bank West","bankCode":"MAZE"}]',
            'location_list',
            'Locatii banci',
            'banking',
            NULL,
            false,
            'Coordonatele bancilor pentru interactiunea proximity'
        ),
        (
            'banking.default_banks',
            '[{"name":"Maze Bank","code":"MAZE","is_active":true},{"name":"Fleeca Bank","code":"FLEC","is_active":true}]',
            'json',
            'Banci implicite (seed)',
            'banking',
            NULL,
            false,
            'Bancile create automat la prima initializare'
        ),
        (
            'banking.default_currencies',
            '[{"code":"USD","name":"US Dollar","symbol":"$"},{"code":"EUR","name":"Euro","symbol":"EUR"}]',
            'json',
            'Valute implicite (seed)',
            'banking',
            NULL,
            false,
            'Valutele create automat la prima initializare'
        ),
        (
            'banking.default_bank_fees',
            '{"transfer_same_bank":{"fee_type_value":"fixed","fee_amount":0.0},"transfer_different_bank":{"fee_type_value":"percentage","fee_amount":1.5},"withdrawal":{"fee_type_value":"fixed","fee_amount":5.0},"deposit":{"fee_type_value":"fixed","fee_amount":0.0},"currency_exchange":{"fee_type_value":"percentage","fee_amount":2.0}}',
            'json',
            'Comisioane implicite (seed)',
            'banking',
            NULL,
            false,
            'Comisioanele aplicate automat pentru fiecare banca la initializare'
        )
        ON CONFLICT (key) DO UPDATE SET
            value       = CASE WHEN settings.value IS NULL OR settings.value IN ('[]', '{}', '', 'null')
                               THEN EXCLUDED.value ELSE settings.value END,
            type        = EXCLUDED.type,
            label       = EXCLUDED.label,
            category    = EXCLUDED.category,
            options     = EXCLUDED.options,
            readonly    = EXCLUDED.readonly,
            description = EXCLUDED.description
    ]], {})

    exports.postgres:query([[
        INSERT INTO settings (key, value, type, label, category, options, readonly, description) VALUES
        ('blips.enabled',               'true',  'boolean', 'Activează blips-uri',                  'blips', NULL, false, 'Afișează blips-urile pe minimapă'),
        ('blips.marker_draw_distance',  '30.0',  'number',  'Distanță desenare markere 3D (m)',     'blips', NULL, false, 'Distanța maximă la care se desenează markere 3D'),
        ('blips.banking',               '{"sprite":108,"color":34,"scale":0.8,"label":"Bancă","showMarker":true,"markerType":1,"markerColor":{"r":0,"g":180,"b":255,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
                                                 'json',    'Configurare blip bănci',               'blips', NULL, false, 'Sprite, culoare și marker pentru locațiile băncilor'),
        ('blips.garages',               '{"sprite":357,"color":2,"scale":0.8,"label":"Garaj","showMarker":true,"markerType":1,"markerColor":{"r":0,"g":255,"b":100,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
                                                 'json',    'Configurare blip garaje',              'blips', NULL, false, 'Sprite, culoare și marker pentru garaje'),
        ('blips.impound',               '{"sprite":68,"color":1,"scale":0.8,"label":"Sechestru","showMarker":true,"markerType":1,"markerColor":{"r":255,"g":60,"b":60,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
                                                 'json',    'Configurare blip sechestru',           'blips', NULL, false, 'Sprite, culoare și marker pentru parcul de sechestru'),
        ('blips.showroom',              '{"sprite":326,"color":5,"scale":0.8,"label":"Showroom","showMarker":true,"markerType":1,"markerColor":{"r":255,"g":200,"b":0,"a":150},"markerScale":{"x":0.5,"y":0.5,"z":0.5}}',
                                                 'json',    'Configurare blip showroom',            'blips', NULL, false, 'Sprite, culoare și marker pentru dealership-uri')
        ON CONFLICT (key) DO UPDATE SET
            type        = EXCLUDED.type,
            label       = EXCLUDED.label,
            category    = EXCLUDED.category,
            options     = EXCLUDED.options,
            readonly    = EXCLUDED.readonly,
            description = EXCLUDED.description
    ]], {})

    exports.postgres:query([[
        UPDATE settings
        SET value = $1
        WHERE key = 'characters.creator_room'
          AND value LIKE '%-2750%'
    ]], { '{"camera":{"x":198.0,"y":-802.5,"z":32.1,"fov":50.0},"child":{"x":198.0,"y":-809.0,"z":30.6,"heading":0.0},"father":{"x":200.5,"y":-810.5,"z":30.6,"heading":343.0},"mother":{"x":195.5,"y":-810.5,"z":30.6,"heading":17.0},"lookAt":{"x":198.0,"y":-810.0,"z":31.85}}' })
end

local function loadSettings()
    local rows = exports.postgres:queryAll(
        'SELECT key, value, type, label, category, options, readonly, description FROM settings',
        {}
    )
    if not rows then
        print('[SETTINGS] Avertisment: niciun rând returnat din tabelul settings')
        return
    end

    cache     = {}
    cacheMeta = {}

    for _, row in ipairs(rows) do
        cache[row.key] = row.value
        cacheMeta[row.key] = {
            type        = row.type        or 'string',
            label       = row.label       or row.key,
            category    = row.category    or 'general',
            options     = row.options,
            readonly    = row.readonly    or false,
            description = row.description or '',
        }
    end

    isLoaded = true
    print('[SETTINGS] ' .. #rows .. ' setări încărcate în cache')
end

local function getSetting(key, default)
    local v = cache[key]
    if v == nil then return default end
    return v
end

local function getSettingNumber(key, default)
    local v = cache[key]
    if v == nil then return default end
    local n = tonumber(v)
    return n ~= nil and n or default
end

local function getSettingBool(key, default)
    local v = cache[key]
    if v == nil then return default end
    return v == 'true' or v == '1'
end

local function getSettingJSON(key, default)
    local v = cache[key]
    if v == nil then return default end
    local ok, result = pcall(json.decode, v)
    return ok and result or default
end

local function getSettingList(key, default)
    return getSettingJSON(key, default or {})
end

local function setSetting(key, value)
    if key == nil or value == nil then return false end
    local strVal = tostring(value)
    cache[key] = strVal
    exports.postgres:query(
        'INSERT INTO settings (key, value) VALUES ($1, $2) ' ..
        'ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()',
        { key, strVal }
    )
    return true
end

local categoryKeys = {
    'core', 'characters', 'inventory', 'banking', 'vehicles', 'garages',
    'showroom', 'notifications', 'hud', 'proximity', 'needs', 'blips', 'general',
}

local function categoryLabel(cat)
    for _, k in ipairs(categoryKeys) do
        if k == cat then
            return Sw.T('settings.category.' .. cat)
        end
    end
    return cat
end

local categoryIcons = {
    core          = 'settings',
    characters    = 'user',
    inventory     = 'package',
    banking       = 'landmark',
    vehicles      = 'car',
    garages       = 'parking-square',
    showroom      = 'store',
    notifications = 'bell',
    hud           = 'monitor',
    proximity     = 'radio',
    needs         = 'heart',
    blips         = 'map-pin',
    general       = 'sliders',
}

local function buildSettingsPayload()
    local rows = exports.postgres:queryAll(
        'SELECT key, value, type, label, category, options, readonly, description FROM settings ORDER BY category, key',
        {}
    )
    if not rows then return { categories = {}, settings = {} } end

    local categoriesSet = {}
    local settingsList  = {}

    for _, row in ipairs(rows) do
        local cat = row.category or 'general'
        if not categoriesSet[cat] then
            categoriesSet[cat] = true
        end
        table.insert(settingsList, {
            key         = row.key,
            value       = row.value,
            type        = row.type        or 'string',
            label       = row.label       or row.key,
            category    = cat,
            options     = row.options,
            readonly    = row.readonly    or false,
            description = row.description or '',
        })
    end

    local orderedCats = { 'core', 'characters', 'inventory', 'banking', 'vehicles', 'garages', 'showroom', 'notifications', 'hud', 'proximity', 'needs', 'blips' }
    local categories  = {}
    for _, c in ipairs(orderedCats) do
        if categoriesSet[c] then
            table.insert(categories, {
                id    = c,
                label = categoryLabel(c),
                icon  = categoryIcons[c]  or 'sliders',
            })
            categoriesSet[c] = nil
        end
    end
    for c in pairs(categoriesSet) do
        table.insert(categories, {
            id    = c,
            label = categoryLabel(c),
            icon  = categoryIcons[c]  or 'sliders',
        })
    end

    return { categories = categories, settings = settingsList }
end

RegisterNetEvent('settings:server:getAll', function()
    local src = source
    if not IsPlayerAceAllowed(tostring(src), 'admin.settings') and
       not IsPlayerAceAllowed(tostring(src), 'admin.all') then
        return
    end
    local payload = buildSettingsPayload()
    TriggerClientEvent('settings:client:allSettings', src, payload)
end)

RegisterNetEvent('settings:server:save', function(key, value)
    local src = source
    if not IsPlayerAceAllowed(tostring(src), 'admin.settings') and
       not IsPlayerAceAllowed(tostring(src), 'admin.all') then
        TriggerClientEvent('settings:client:saveResult', src, { key = key, success = false, error = Sw.TP(src, 'settings.error_permission_denied') })
        return
    end
    if not key or value == nil then
        TriggerClientEvent('settings:client:saveResult', src, { key = key, success = false, error = Sw.TP(src, 'settings.error_invalid_data') })
        return
    end
    local meta = cacheMeta[key]
    if meta and meta.readonly then
        TriggerClientEvent('settings:client:saveResult', src, { key = key, success = false, error = Sw.TP(src, 'settings.error_readonly') })
        return
    end
    local ok = setSetting(key, value)
    TriggerClientEvent('settings:client:saveResult', src, { key = key, success = ok })
end)

RegisterNetEvent('settings:server:reload', function()
    local src = source
    if not IsPlayerAceAllowed(tostring(src), 'admin.settings') and
       not IsPlayerAceAllowed(tostring(src), 'admin.all') then
        return
    end
    loadSettings()
    TriggerClientEvent('settings:client:reloaded', src)
end)

CreateThread(function()
    while not exports.postgres:isReady() do
        Wait(100)
    end

    applySchema()
    Wait(300)

    seedSettings()
    Wait(300)

    loadSettings()
    print('[SETTINGS] Modul settings inițializat')
end)

exports('GetSetting',       getSetting)
exports('GetSettingNumber', getSettingNumber)
exports('GetSettingBool',   getSettingBool)
exports('GetSettingJSON',   getSettingJSON)
exports('GetSettingList',   getSettingList)
exports('SetSetting',       setSetting)
exports('ReloadSettings',   loadSettings)
exports('IsReady',          function() return isLoaded end)
