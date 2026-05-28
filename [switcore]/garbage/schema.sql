-- ==================== GARBAGE SCHEMA ====================

CREATE TABLE IF NOT EXISTS garbage_sessions (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    route_id        INT NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','completed','abandoned')),
    collected_count INT NOT NULL DEFAULT 0,
    total_waypoints INT NOT NULL DEFAULT 0,
    pay_amount      NUMERIC(10,2),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS garbage_stats (
    character_id     INT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    total_sessions   INT NOT NULL DEFAULT 0,
    total_collected  INT NOT NULL DEFAULT 0,
    total_earned     NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_garbage_sessions_char   ON garbage_sessions(character_id);
CREATE INDEX IF NOT EXISTS idx_garbage_sessions_status ON garbage_sessions(status);

-- Grade
INSERT INTO job_grades (job_name, grade, label, salary, can_manage, permissions) VALUES
    ('garbage', 0, 'Muncitor',   0, FALSE, '[]'),
    ('garbage', 1, 'Operator',   0, FALSE, '["drive"]'),
    ('garbage', 2, 'Supervizor', 0, TRUE,  '["drive","manage"]')
ON CONFLICT (job_name, grade) DO UPDATE SET
    label       = EXCLUDED.label,
    permissions = EXCLUDED.permissions,
    can_manage  = EXCLUDED.can_manage;

-- Settings
INSERT INTO settings (key, value, description) VALUES
    ('garbage.pay_per_point_0', '50',                                'Plata per container grade 0 (lei)'),
    ('garbage.pay_per_point_1', '65',                                'Plata per container grade 1 (lei)'),
    ('garbage.pay_per_point_2', '80',                                'Plata per container grade 2 (lei)'),
    ('garbage.route_bonus_0',   '200',                               'Bonus ruta completa grade 0 (lei)'),
    ('garbage.route_bonus_2',   '350',                               'Bonus ruta completa grade 2 (lei)'),
    ('garbage.hiring_coords',   '{"x":716.3,"y":-2007.5,"z":29.3}', 'Coordonate depou salubritate'),
    ('garbage.vehicle_model',   'trash',                             'Model camion salubritate'),
    ('garbage.promo_grade_1',   '10',                                'Rute complete pentru grade 1'),
    ('garbage.promo_grade_2',   '40',                                'Rute complete pentru grade 2')
ON CONFLICT (key) DO NOTHING;
