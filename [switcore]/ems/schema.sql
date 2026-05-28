-- ============================================================
-- [switcore]/ems/schema.sql
-- Tabele EMS + seed items + seed settings
-- ============================================================

CREATE TABLE IF NOT EXISTS ems_calls (
    id           SERIAL PRIMARY KEY,
    caller_id    INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    caller_name  VARCHAR(100) NOT NULL,
    message      TEXT NOT NULL,
    coords       JSONB NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending',
    responder_id INT REFERENCES characters(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at  TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ems_medical_records (
    id          SERIAL PRIMARY KEY,
    patient_id  INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    ems_id      INT REFERENCES characters(id) ON DELETE SET NULL,
    record_type VARCHAR(30) NOT NULL,
    details     JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ems_records_patient ON ems_medical_records(patient_id, created_at DESC);

CREATE TABLE IF NOT EXISTS ems_vehicle_inventory (
    id        SERIAL PRIMARY KEY,
    plate     VARCHAR(8) NOT NULL,
    item_name VARCHAR(50) NOT NULL REFERENCES items(name) ON DELETE CASCADE,
    amount    INT NOT NULL DEFAULT 0,
    UNIQUE(plate, item_name)
);

-- ── Items EMS ────────────────────────────────────────────────

INSERT INTO items (name, label, weight, type, usable, stackable, description) VALUES
('iv_fluids',     'IV Fluids',    0.30, 'medical', FALSE, TRUE,  'Solutie IV. Restaureaza HP si hidratare.'),
('defibrillator', 'Defibrilator', 1.50, 'medical', FALSE, FALSE, 'Resuscitare cardiaca. Necesita EMS.'),
('morphine_iv',   'Morfina IV',   0.10, 'medical', FALSE, TRUE,  'Analgezic IV puternic. Suprima durerea 600s.')
ON CONFLICT (name) DO NOTHING;

-- Actualizeaza permisiunile job EMS
UPDATE job_grades SET permissions = '["diagnose"]'
WHERE job_name = 'ems' AND grade = 0;

-- ── Settings ─────────────────────────────────────────────────

INSERT INTO settings (key, value, description) VALUES
('ems.respawn_timer',         '600',     'Secunde pana la optiunea de respawn la spital'),
('ems.hospital_bill',         '5000',    'Cost spitalizare la respawn (RON)'),
('ems.hospital_x',            '295.5',   'Coord X spital spawn'),
('ems.hospital_y',            '-1446.8', 'Coord Y spital spawn'),
('ems.hospital_z',            '29.9',    'Coord Z spital spawn'),
('ems.hospital_heading',      '180.0',   'Heading spawn spital'),
('ems.revive_hp',             '150',     'HP acordat dupa resuscitare'),
('ems.ambulance_radius',      '5.0',     'Raza acces inventar ambulanta (GTA units)'),
('ems.patient_scan_interval', '2',       'Secunde intre scan-uri proximity EMS'),
('ems.patient_scan_range',    '3.5',     'Raza interactiune pacient (GTA units)'),
('ems.stretcher_range',       '2.0',     'Raza ridicare pacient cu targa'),
('ems.blip_update_interval',  '5',       'Secunde intre update pozitii blipuri ambulante'),
('ems.mdt_key',               'F6',      'Tasta deschidere MDT medical'),
('ems.ambulance_models',
    '["ambulance","lguard"]',
    'Modele vehicule recunoscute ca ambulante (JSON array)'),
('ems.default_stock',
    '[{"item":"bandage","amount":10},{"item":"morphine","amount":5},{"item":"iv_fluids","amount":5},{"item":"defibrillator","amount":1},{"item":"morphine_iv","amount":3}]',
    'Stoc implicit ambulanta la aprovizionare'),
('ems.iv_treatments',
    '[{"item":"iv_fluids","label":"IV Fluids","restoreHP":50},{"item":"morphine_iv","label":"Morfina IV","suppressDuration":600,"injuryBleedSuppress":600}]',
    'Tratamente IV disponibile in ambulanta')
ON CONFLICT (key) DO NOTHING;
