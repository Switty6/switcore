-- ==================== TAXI SCHEMA ====================

CREATE TABLE IF NOT EXISTS taxi_orders (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    passenger_src   INT NOT NULL,
    pickup_coords   JSONB NOT NULL,
    dropoff_coords  JSONB,
    status          VARCHAR(20) NOT NULL DEFAULT 'waiting'
                        CHECK (status IN ('waiting','accepted','in_progress','completed','cancelled')),
    driver_char_id  INT REFERENCES characters(id) ON DELETE SET NULL,
    pay_amount      NUMERIC(10,2),
    distance_km     NUMERIC(8,3),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS taxi_stats (
    character_id    INT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    total_trips     INT NOT NULL DEFAULT 0,
    total_earned    NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_taxi_orders_driver ON taxi_orders(driver_char_id);
CREATE INDEX IF NOT EXISTS idx_taxi_orders_status ON taxi_orders(status);
CREATE INDEX IF NOT EXISTS idx_taxi_orders_char   ON taxi_orders(character_id);

-- Grade (ON CONFLICT pentru a nu suprascrie daca exista)
INSERT INTO job_grades (job_name, grade, label, salary, can_manage, permissions) VALUES
    ('taxi', 0, 'Sofer Nou',  0, FALSE, '[]'),
    ('taxi', 1, 'Sofer',      0, FALSE, '["drive"]'),
    ('taxi', 2, 'Veteran',    0, FALSE, '["drive","priority"]'),
    ('taxi', 3, 'Dispecer',   0, TRUE,  '["drive","priority","manage"]')
ON CONFLICT (job_name, grade) DO UPDATE SET
    label       = EXCLUDED.label,
    permissions = EXCLUDED.permissions,
    can_manage  = EXCLUDED.can_manage;

-- Settings
INSERT INTO settings (key, value, description) VALUES
    ('taxi.rate_per_km_0',    '80',                               'Tarif per km grade 0 (lei)'),
    ('taxi.rate_per_km_1',    '100',                              'Tarif per km grade 1 (lei)'),
    ('taxi.rate_per_km_2',    '130',                              'Tarif per km grade 2+ (lei)'),
    ('taxi.dispatch_radius',  '5000',                             'Raza dispatch sofer (unitati GTA)'),
    ('taxi.hiring_coords',    '{"x":-69.0,"y":-1763.0,"z":29.0}','Coordonate angajare taxi'),
    ('taxi.vehicle_model',    'taxi',                             'Model vehicul taxi'),
    ('taxi.promo_grade_1',    '20',                               'Curse necesare pentru grade 1'),
    ('taxi.promo_grade_2',    '75',                               'Curse necesare pentru grade 2')
ON CONFLICT (key) DO NOTHING;
