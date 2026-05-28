-- ============================================================
-- MEDICAL SYSTEM SCHEMA
-- [switcore]/medical/schema.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS medical_conditions (
    id                    SERIAL PRIMARY KEY,
    name                  VARCHAR(50) UNIQUE NOT NULL,
    label                 VARCHAR(100) NOT NULL,
    type                  VARCHAR(20) NOT NULL DEFAULT 'virus',
    contagious            BOOLEAN NOT NULL DEFAULT TRUE,
    base_infection_chance DECIMAL(5,4) NOT NULL DEFAULT 0.15,
    description           TEXT
);

CREATE TABLE IF NOT EXISTS medical_symptoms (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50) UNIQUE NOT NULL,
    label       VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS condition_symptoms (
    id             SERIAL PRIMARY KEY,
    condition_name VARCHAR(50) NOT NULL REFERENCES medical_conditions(name) ON DELETE CASCADE,
    symptom_name   VARCHAR(50) NOT NULL REFERENCES medical_symptoms(name) ON DELETE CASCADE,
    min_stage      SMALLINT NOT NULL DEFAULT 2,
    max_stage      SMALLINT NOT NULL DEFAULT 5,
    UNIQUE(condition_name, symptom_name)
);

CREATE TABLE IF NOT EXISTS medical_items (
    item_name                VARCHAR(50) PRIMARY KEY,
    label                    VARCHAR(100) NOT NULL,
    treats_condition         VARCHAR(50) REFERENCES medical_conditions(name) ON DELETE SET NULL,
    treats_symptom           VARCHAR(50) REFERENCES medical_symptoms(name) ON DELETE SET NULL,
    stage_reduction          SMALLINT NOT NULL DEFAULT 0,
    symptom_suppress_duration INT NOT NULL DEFAULT 0,
    cooldown_seconds         INT NOT NULL DEFAULT 60,
    description              TEXT
);

CREATE TABLE IF NOT EXISTS character_conditions (
    id              SERIAL PRIMARY KEY,
    character_id    INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    condition_name  VARCHAR(50) NOT NULL REFERENCES medical_conditions(name) ON DELETE CASCADE,
    current_stage   SMALLINT NOT NULL DEFAULT 1,
    contracted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_progressed TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    cured_at        TIMESTAMPTZ,
    UNIQUE(character_id, condition_name)
);

CREATE INDEX IF NOT EXISTS idx_char_conditions_active
    ON character_conditions(character_id, is_active);

CREATE TABLE IF NOT EXISTS character_medication_log (
    id             SERIAL PRIMARY KEY,
    character_id   INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    item_name      VARCHAR(50) NOT NULL,
    used_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    stage_before   SMALLINT,
    stage_after    SMALLINT,
    condition_name VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_med_log_character
    ON character_medication_log(character_id, item_name, used_at DESC);

CREATE TABLE IF NOT EXISTS character_injuries (
    id           SERIAL PRIMARY KEY,
    character_id INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    injury_type  VARCHAR(50) NOT NULL,
    location     VARCHAR(30) NOT NULL DEFAULT 'generic',
    severity     SMALLINT NOT NULL DEFAULT 1,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    treated_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_char_injuries_active
    ON character_injuries(character_id, is_active);

-- ============================================================
-- SEED DATA
-- ============================================================

INSERT INTO medical_conditions (name, label, type, contagious, base_infection_chance, description) VALUES
('common_cold',    'Raceala Comuna',          'virus',    TRUE,  0.20, 'Virus respirator comun.'),
('influenza',      'Gripa',                   'virus',    TRUE,  0.25, 'Gripa sezoniera. Progresie rapida.'),
('covid_like',     'Virus Respirator XB1',    'virus',    TRUE,  0.30, 'Virus respirator agresiv.'),
('salmonella',     'Salmoneloza',             'bacteria', FALSE, 0.05, 'Infectie bacteriana din alimente contaminate.'),
('food_poisoning', 'Toxiinfectie Alimentara', 'bacteria', FALSE, 0.00, 'Cauzata de alimente stricate.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO medical_symptoms (name, label) VALUES
('fever',      'Febra'),
('cough',      'Tuse'),
('sneezing',   'Stranut'),
('nausea',     'Greata'),
('weakness',   'Slabiciune'),
('headache',   'Durere de Cap'),
('bleeding',   'Sangerare'),
('vomiting',   'Varsaturi'),
('chills',     'Frisoane'),
('chest_pain', 'Durere in Piept')
ON CONFLICT (name) DO NOTHING;

INSERT INTO condition_symptoms (condition_name, symptom_name, min_stage, max_stage) VALUES
('common_cold', 'sneezing', 2, 5),
('common_cold', 'cough',    2, 5),
('common_cold', 'headache', 3, 5),
('common_cold', 'fever',    3, 5),
('common_cold', 'weakness', 4, 5),
('influenza', 'fever',      2, 5),
('influenza', 'chills',     2, 5),
('influenza', 'cough',      2, 5),
('influenza', 'sneezing',   2, 4),
('influenza', 'headache',   2, 5),
('influenza', 'weakness',   3, 5),
('influenza', 'nausea',     4, 5),
('influenza', 'chest_pain', 5, 5),
('covid_like', 'fever',      2, 5),
('covid_like', 'cough',      2, 5),
('covid_like', 'weakness',   2, 5),
('covid_like', 'sneezing',   2, 3),
('covid_like', 'headache',   3, 5),
('covid_like', 'chest_pain', 4, 5),
('covid_like', 'nausea',     4, 5),
('covid_like', 'bleeding',   5, 5),
('salmonella', 'nausea',    2, 5),
('salmonella', 'vomiting',  3, 5),
('salmonella', 'weakness',  3, 5),
('salmonella', 'fever',     4, 5),
('salmonella', 'bleeding',  5, 5),
('food_poisoning', 'nausea',   1, 5),
('food_poisoning', 'vomiting', 2, 5),
('food_poisoning', 'weakness', 3, 5),
('food_poisoning', 'fever',    4, 5)
ON CONFLICT DO NOTHING;

INSERT INTO items (name, label, weight, type, usable, stackable, description) VALUES
('aspirin',       'Aspirina',              0.05, 'consumable', TRUE, TRUE, 'Reduce febra si durerile usoare.'),
('paracetamol',   'Paracetamol',           0.05, 'consumable', TRUE, TRUE, 'Calmant si antipiretic.'),
('antibiotics',   'Antibiotice',           0.10, 'consumable', TRUE, TRUE, 'Tratament pentru infectii bacteriene.'),
('antivirals',    'Antivirale',            0.10, 'consumable', TRUE, TRUE, 'Reduce progresia infectiilor virale.'),
('cough_syrup',   'Sirop de Tuse',         0.20, 'consumable', TRUE, TRUE, 'Suprima tusea pentru o perioada.'),
('vitamins',      'Vitamine',              0.05, 'consumable', TRUE, TRUE, 'Intareste imunitatea.'),
('bandage',       'Bandaj',                0.15, 'consumable', TRUE, TRUE, 'Opreste sangerarea temporar.'),
('surgical_mask', 'Masca Chirurgicala',    0.05, 'medical',    TRUE, TRUE, 'Reduce transmiterea bolilor respiratorii.'),
('antiemetic',    'Antiemetic',            0.05, 'consumable', TRUE, TRUE, 'Reduce greata si varsaturile.'),
('splint',        'Atela Ortopedica',      0.30, 'consumable', TRUE, TRUE, 'Imobilizeaza osul rupt. Reduce durerea.'),
('morphine',      'Morfina',               0.10, 'consumable', TRUE, TRUE, 'Analgezic puternic. Suprima durerea severa.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO medical_items (item_name, label, treats_condition, treats_symptom, stage_reduction, symptom_suppress_duration, cooldown_seconds) VALUES
('aspirin',      'Aspirina',         NULL,          'fever',     0, 600,  60),
('paracetamol',  'Paracetamol',      NULL,          'headache',  0, 600,  60),
('antibiotics',  'Antibiotice',      'salmonella',  NULL,        1, 0,    3600),
('antivirals',   'Antivirale',       NULL,          NULL,        1, 0,    7200),
('cough_syrup',  'Sirop de Tuse',    NULL,          'cough',     0, 900,  120),
('vitamins',     'Vitamine',         NULL,          NULL,        0, 0,    3600),
('bandage',      'Bandaj',           NULL,          'bleeding',  0, 600,  30),
('antiemetic',   'Antiemetic',       NULL,          'nausea',    0, 600,  60),
('splint',       'Atela Ortopedica', NULL,          NULL,        0, 0,    60),
('morphine',     'Morfina',          NULL,          NULL,        0, 0,    1800)
ON CONFLICT (item_name) DO NOTHING;

-- ============================================================
-- SETTINGS - toate valorile configurabile (fara config.lua)
-- ============================================================

INSERT INTO settings (key, value, description) VALUES
('medical.sneeze_radius',              '5.0',   'Raza transmitere infectie la stranut (GTA units)'),
('medical.mask_protection',            '0.10',  'Multiplicator sansa infectare cu masca chirurgicala (0.0-1.0)'),
('medical.vitamin_immunity_multiplier','0.50',  'Reducere sansa infectare cand imunitatea e activa (0.0-1.0)'),
('medical.vitamin_effect_duration',    '3600',  'Durata efect imunitate vitamine (secunde)'),
('medical.progression_interval',       '300',   'Interval verificare progresie boli (secunde)'),
('medical.severe_damage_per_tick',     '2',     'HP pierdut per tick la sangerare din boli'),
('medical.severe_damage_interval',     '30',    'Interval damage sangerare din boli (secunde)'),
('medical.critical_damage_per_tick',   '5',     'HP pierdut per tick la stadiu critic (5)'),
('medical.critical_damage_interval',   '15',    'Interval damage stadiu critic (secunde)'),
('medical.injury_bleed_loop_interval', '5',     'Interval loop bleeding rani (secunde)'),
('medical.stage_progression_time',
    '{"1":600,"2":900,"3":1200,"4":1800}',
    'Timp pana la progresie per stadiu (secunde). Chei: 1=incubatie→usoara, 2=usoara→moderata, 3=moderata→severa, 4=severa→critica'),
('medical.stage_labels',
    '{"1":"Incubatie","2":"Usoara","3":"Moderata","4":"Severa","5":"Critica"}',
    'Etichete afisate pentru fiecare stadiu boala'),
('medical.conditions',
    '{"common_cold":{"label":"Raceala Comuna","type":"virus","contagious":true,"baseChance":0.20,"symptoms":{"2":["sneezing","cough"],"3":["sneezing","cough","headache","fever"],"4":["sneezing","cough","headache","fever","weakness"],"5":["sneezing","cough","headache","fever","weakness"]}},"influenza":{"label":"Gripa","type":"virus","contagious":true,"baseChance":0.25,"symptoms":{"2":["fever","chills","cough","sneezing","headache"],"3":["fever","chills","cough","sneezing","headache","weakness"],"4":["fever","chills","cough","headache","weakness","nausea"],"5":["fever","chills","cough","headache","weakness","nausea","chest_pain"]}},"covid_like":{"label":"Virus Respirator XB1","type":"virus","contagious":true,"baseChance":0.30,"symptoms":{"2":["fever","cough","weakness","sneezing"],"3":["fever","cough","weakness","sneezing","headache"],"4":["fever","cough","weakness","headache","chest_pain","nausea"],"5":["fever","cough","weakness","headache","chest_pain","nausea","bleeding"]}},"salmonella":{"label":"Salmoneloza","type":"bacteria","contagious":false,"baseChance":0.05,"symptoms":{"2":["nausea"],"3":["nausea","vomiting","weakness"],"4":["nausea","vomiting","weakness","fever"],"5":["nausea","vomiting","weakness","fever","bleeding"]}},"food_poisoning":{"label":"Toxiinfectie Alimentara","type":"bacteria","contagious":false,"baseChance":0.0,"symptoms":{"1":["nausea"],"2":["nausea","vomiting"],"3":["nausea","vomiting","weakness"],"4":["nausea","vomiting","weakness","fever"],"5":["nausea","vomiting","weakness","fever"]}}}',
    'Configuratie boli: simptome per stadiu, tip (virus/bacteria), sansa infectare'),
('medical.symptom_effects',
    '{"fever":{"timecycle":"heat_exhaustion","timecycleStrength":0.3,"screenEffect":"DrugsMichaelAliensFight","screenStrength":0.2,"intervalSeconds":120},"nausea":{"screenEffect":"DrugsMichaelAliensFight","screenStrength":0.4,"screenDuration":3000,"intervalSeconds":60},"weakness":{"staminaValue":30.0},"bleeding":{"screenEffect":"DeathFailOut","screenDuration":1500,"intervalSeconds":15},"headache":{"screenEffect":"SwitchHUDIn","screenStrength":0.15,"screenDuration":1500,"intervalSeconds":90},"cough":{"animDict":"mp_common_ambient","animName":"amb_rest_inhale","duration":3000,"intervalSeconds":45},"sneezing":{"animDict":"mp_common_ambient","animName":"amb_rest_inhale","duration":2500,"intervalSeconds":30},"vomiting":{"animDict":"mp_arresting","animName":"a_uncuff","duration":4000,"intervalSeconds":90},"chills":{"timecycle":"damage","timecycleStrength":0.2},"chest_pain":{"screenEffect":"DeathFailOut","screenStrength":0.25,"screenDuration":2000,"intervalSeconds":120}}',
    'Efecte vizuale (AnimpostFx, timecycle, animatii) per simptom'),
('medical.medications',
    '{"aspirin":{"treatsSymptom":"fever","suppressDuration":600,"cooldown":60,"message":"Ai luat o aspirina. Febra se reduce."},"paracetamol":{"treatsSymptom":"headache","suppressDuration":600,"cooldown":60,"message":"Ai luat paracetamol. Durerea de cap se amelioreaza."},"antibiotics":{"treatsType":"bacteria","stageReduction":1,"cooldown":3600,"message":"Ai luat antibiotice. Infectia bacteriana cedeaza.","noCondMsg":"Nu ai nicio infectie bacteriana activa."},"antivirals":{"treatsType":"virus","stageReduction":1,"cooldown":7200,"message":"Ai luat antivirale. Virusul pierde teren.","noCondMsg":"Nu ai nicio infectie virala activa."},"cough_syrup":{"treatsSymptom":"cough","suppressDuration":900,"cooldown":120,"message":"Ai luat sirop de tuse. Tusea se calmeaza."},"vitamins":{"immunityBoost":true,"immunityDuration":3600,"cooldown":3600,"message":"Ai luat vitamine. Sistemul imunitar este mai rezistent."},"bandage":{"treatsSymptom":"bleeding","suppressDuration":600,"cooldown":30,"injuryBleedSupress":600,"message":"Ai aplicat un bandaj. Sangerarea s-a oprit."},"antiemetic":{"treatsSymptom":"nausea","suppressDuration":600,"cooldown":60,"message":"Ai luat un antiemetic. Greata s-a redus."},"surgical_mask":{"message":"Masca a fost echipata/scoasa."},"splint":{"treatsInjury":"broken_bone","cooldown":60,"message":"Ai aplicat atela. Durerea s-a redus.","noInjMsg":"Nu ai niciun os rupt activ."},"morphine":{"suppressAllPain":true,"suppressDuration":300,"injuryBleedSupress":300,"cooldown":1800,"message":"Ai administrat morfina. Durerea dispare."}}',
    'Configuratie medicamente: simptome tratate, cooldown, durata suprimare'),
('medical.weapon_categories',
    '{"gun":2,"blunt":3,"blade":4}',
    'Categorii arme GTA5 (HasEntityBeenDamagedByWeapon type). gun=2, blunt=3, blade=4'),
('medical.bone_zones',
    '{"leg_left":[36864,40269,63931],"leg_right":[51826,57597,14201],"spine":[24818,24819,24820,24821,11816],"arm_left":[61163,2108,58271],"arm_right":[28252,43017,61163]}',
    'Bone indices GTA5 per zona corpului (GetPedLastDamageBone)'),
('medical.injury_effects',
    '{"gunshot_leg":{"movementClipset":"move_m@injured@","bleedingPerTick":3,"bleedInterval":8},"gunshot_chest":{"ragdollOnHit":true,"ragdollDuration":2000,"bleedingPerTick":5,"bleedInterval":6,"requiresNoArmor":true},"bruise":{"screenEffect":"DrugsMichaelAliensFight","onSprint":true,"painInterval":45},"broken_bone":{"staminaValue":20.0,"screenEffect":"DeathFailOut","painInterval":30},"stab":{"bleedingPerTick":4,"bleedInterval":7,"screenEffect":"DeathFailOut","screenInterval":10}}',
    'Efecte client-side per tip rana (clipset, ragdoll, bleeding, screen effects)')
ON CONFLICT (key) DO NOTHING;
