-- ==================== MECANIC SCHEMA ====================

-- Cererile de asistenta rutiera
CREATE TABLE IF NOT EXISTS mechanic_service_calls (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_char_id   INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    vehicle_id       BIGINT REFERENCES owned_vehicles(id) ON DELETE SET NULL,
    problem_type     VARCHAR(30) NOT NULL,
    location         JSONB NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','accepted','in_progress','completed','cancelled')),
    mechanic_char_id INT REFERENCES characters(id) ON DELETE SET NULL,
    price            NUMERIC(10,2),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_msc_client   ON mechanic_service_calls(client_char_id);
CREATE INDEX IF NOT EXISTS idx_msc_mechanic ON mechanic_service_calls(mechanic_char_id);
CREATE INDEX IF NOT EXISTS idx_msc_status   ON mechanic_service_calls(status);

-- Log servicii (audit + statistici firma)
CREATE TABLE IF NOT EXISTS mechanic_service_log (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    mechanic_char_id INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    client_char_id   INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    vehicle_id       BIGINT REFERENCES owned_vehicles(id) ON DELETE SET NULL,
    service_type     VARCHAR(40) NOT NULL,
    price            NUMERIC(10,2) NOT NULL,
    bonus_paid       NUMERIC(10,2) NOT NULL DEFAULT 0,
    completed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_msl_mechanic ON mechanic_service_log(mechanic_char_id);
CREATE INDEX IF NOT EXISTS idx_msl_client   ON mechanic_service_log(client_char_id);

-- Piese auto
INSERT INTO items (name, label, weight, stackable, usable, description) VALUES
    ('ulei_motor',      'Ulei Motor',       0.5, true, false, 'Schimb ulei motor'),
    ('placute_frana',   'Placute Frana',    1.0, true, false, 'Schimb placute frana'),
    ('anvelopa',        'Anvelopa',         5.0, true, false, 'Schimb anvelopa'),
    ('piesa_suspensie', 'Piesa Suspensie',  3.0, true, false, 'Reparatie suspensie'),
    ('baterie_auto',    'Baterie Auto',     8.0, true, false, 'Inlocuire baterie'),
    ('piesa_motor',     'Piesa Motor',      4.0, true, false, 'Reparatie motor'),
    ('piesa_caroserie', 'Piesa Caroserie',  6.0, true, false, 'Reparatie caroserie')
ON CONFLICT (name) DO NOTHING;

-- Job
INSERT INTO jobs (name, label, type, blip_sprite, blip_color, blip_coords)
VALUES ('mecanic_auto', 'Mecanic Auto', 'whitelisted', 446, 5, '{"x":375.84,"y":-1888.77,"z":29.41}')
ON CONFLICT (name) DO NOTHING;

INSERT INTO job_grades (job_name, grade, label, salary, can_manage, permissions) VALUES
    ('mecanic_auto', 0, 'Ucenic Mecanic',  1200, false,
        '["inspect","oil_change","brakes","tires","battery","bodywork"]'),
    ('mecanic_auto', 1, 'Mecanic',          2200, false,
        '["inspect","oil_change","brakes","tires","battery","bodywork","engine","suspension"]'),
    ('mecanic_auto', 2, 'Mecanic Sef',      3200, false,
        '["inspect","oil_change","brakes","tires","battery","bodywork","engine","suspension","roadside"]'),
    ('mecanic_auto', 3, 'Manager Service',  4500, true,
        '["inspect","oil_change","brakes","tires","battery","bodywork","engine","suspension","roadside","manage","buy_parts"]')
ON CONFLICT (job_name, grade) DO NOTHING;

-- Organizatie firma
INSERT INTO organizations (name, label, type, code)
VALUES ('Service Auto Central', 'Service Auto', 'private', 'mec_auto')
ON CONFLICT (code) DO NOTHING;

-- Setari
INSERT INTO settings (key, value, type, label, category) VALUES
    ('mecanic.inspect_price',          '200',   'number', 'Pret diagnoza',                  'Mecanic'),
    ('mecanic.oil_change_price',       '400',   'number', 'Pret schimb ulei',               'Mecanic'),
    ('mecanic.brakes_price',           '500',   'number', 'Pret placute frana',             'Mecanic'),
    ('mecanic.tire_price',             '300',   'number', 'Pret anvelopa (per bucata)',      'Mecanic'),
    ('mecanic.suspension_price',       '800',   'number', 'Pret reparatie suspensie/ax',    'Mecanic'),
    ('mecanic.battery_price',          '600',   'number', 'Pret baterie',                   'Mecanic'),
    ('mecanic.engine_price',           '1500',  'number', 'Pret reparatie motor',           'Mecanic'),
    ('mecanic.bodywork_price',         '800',   'number', 'Pret reparatie caroserie',       'Mecanic'),
    ('mecanic.roadside_engine_price',  '2000',  'number', 'Pret urgenta motor (rutier)',    'Mecanic'),
    ('mecanic.roadside_tire_price',    '600',   'number', 'Pret anvelopa (rutier)',         'Mecanic'),
    ('mecanic.roadside_battery_price', '500',   'number', 'Pret jump start baterie',       'Mecanic'),
    ('mecanic.roadside_tow_price',     '1500',  'number', 'Pret tractare la atelier',      'Mecanic'),
    ('mecanic.oil_deg_per_500km',      '5',     'number', 'Degradare ulei la 500km (%)',   'Mecanic'),
    ('mecanic.tire_deg_per_500km',     '1',     'number', 'Degradare anvelope la 500km (%)','Mecanic'),
    ('mecanic.workshop_coords',        '{"x":375.84,"y":-1888.77,"z":29.41}', 'json', 'Coordonate atelier', 'Mecanic'),
    ('mecanic.bonus_grade_0',          '8',     'number', 'Bonus serviciu grade 0 (%)',    'Mecanic'),
    ('mecanic.bonus_grade_1',          '12',    'number', 'Bonus serviciu grade 1 (%)',    'Mecanic'),
    ('mecanic.bonus_grade_2',          '18',    'number', 'Bonus serviciu grade 2 (%)',    'Mecanic'),
    ('mecanic.bonus_grade_3',          '25',    'number', 'Bonus serviciu grade 3 (%)',    'Mecanic')
ON CONFLICT (key) DO NOTHING;

COMMENT ON TABLE mechanic_service_calls IS 'Cereri active de asistenta rutiera';
COMMENT ON TABLE mechanic_service_log   IS 'Audit trail servicii mecanic';
