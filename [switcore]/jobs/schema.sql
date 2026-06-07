-- ==================== JOBS SCHEMA ====================

CREATE TABLE IF NOT EXISTS jobs (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(64) UNIQUE NOT NULL,
    label       VARCHAR(128) NOT NULL,
    type        VARCHAR(32) NOT NULL DEFAULT 'whitelisted'
                    CHECK (type IN ('whitelisted', 'self_serve', 'illegal')),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    blip_sprite INT,
    blip_color  INT,
    blip_coords JSONB,
    created_at  TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS job_grades (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_name    VARCHAR(64) NOT NULL REFERENCES jobs(name) ON DELETE CASCADE,
    grade       INT NOT NULL,
    label       VARCHAR(128) NOT NULL,
    salary      INT NOT NULL DEFAULT 0,
    can_manage  BOOLEAN NOT NULL DEFAULT FALSE,
    permissions JSONB NOT NULL DEFAULT '[]',
    UNIQUE(job_name, grade)
);

CREATE TABLE IF NOT EXISTS character_jobs (
    character_id INT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    job_name     VARCHAR(64) NOT NULL REFERENCES jobs(name),
    grade        INT NOT NULL DEFAULT 0,
    is_on_duty   BOOLEAN NOT NULL DEFAULT FALSE,
    hired_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS job_duty_logs (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    job_name     VARCHAR(64) NOT NULL,
    clocked_in   TIMESTAMPTZ NOT NULL,
    clocked_out  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_character_jobs_job_name   ON character_jobs(job_name);
CREATE INDEX IF NOT EXISTS idx_character_jobs_is_on_duty ON character_jobs(is_on_duty);
CREATE INDEX IF NOT EXISTS idx_job_duty_logs_char        ON job_duty_logs(character_id);
CREATE INDEX IF NOT EXISTS idx_job_duty_logs_open        ON job_duty_logs(character_id) WHERE clocked_out IS NULL;

-- ==================== SEED DEFAULT JOBS ====================

INSERT INTO jobs (name, label, type, blip_sprite, blip_color) VALUES
    ('unemployed', 'Șomer',     'self_serve',  NULL, NULL),
    ('police',     'Poliție',   'whitelisted',   60,   29),
    ('ems',        'EMS',       'whitelisted',   61,    1),
    ('mechanic',   'Mecanic',   'whitelisted',  446,    5),
    ('taxi',       'Taxi',      'self_serve',   198,    2),
    ('garbage',    'Salubritate','self_serve',  318,    4),
    ('ballas',     'Ballas',    'illegal',       84,   22),
    ('lost_mc',    'Lost MC',   'illegal',       74,   27)
ON CONFLICT (name) DO NOTHING;

-- Sedii joburi (punct de proximitate pentru tableta + tura de serviciu).
-- Idempotent: completeaza doar daca nu a fost setat deja (serverele noi il primesc tot prin acest UPDATE).
-- Fara coordonate aici, jobul nu are punct de sediu => tableta nu se poate deschide si nu se poate intra in tura.
UPDATE jobs SET blip_coords = '{"x":441.7,"y":-978.3,"z":30.67}'
    WHERE name = 'police'
      AND (blip_coords IS NULL OR blip_coords = '{"x":428.0,"y":-981.0,"z":30.7}'::jsonb);

INSERT INTO job_grades (job_name, grade, label, salary, can_manage, permissions) VALUES
    ('unemployed', 0, 'Fără loc de muncă', 0,    false, '[]'),

    ('police',  0, 'Ofițer',       2000, false, '[]'),
    ('police',  1, 'Sergent',      3000, false, '["arrest"]'),
    ('police',  2, 'Locotenent',   4000, false, '["arrest","armory"]'),
    ('police',  3, 'Căpitan',      5000, true,  '["arrest","armory","manage"]'),

    ('ems',     0, 'Paramedic',    2000, false, '[]'),
    ('ems',     1, 'Medic',        3000, false, '["revive"]'),
    ('ems',     2, 'Medic Șef',    4500, true,  '["revive","manage"]'),

    ('mechanic',0, 'Ucenic',       1500, false, '[]'),
    ('mechanic',1, 'Mecanic',      2500, false, '["repair"]'),
    ('mechanic',2, 'Șef Atelier',  3500, true,  '["repair","manage"]'),

    ('taxi',    0, 'Șofer Taxi',      0, false, '[]'),

    ('garbage', 0, 'Muncitor',        0, false, '[]'),

    ('ballas',  0, 'Asociat',         0, false, '[]'),
    ('ballas',  1, 'Soldier',         0, false, '[]'),
    ('ballas',  2, 'OG',              0, true,  '["manage"]'),

    ('lost_mc', 0, 'Prospect',        0, false, '[]'),
    ('lost_mc', 1, 'Member',          0, false, '[]'),
    ('lost_mc', 2, 'Sergeant',        0, false, '[]'),
    ('lost_mc', 3, 'President',       0, true,  '["manage"]')
ON CONFLICT (job_name, grade) DO NOTHING;

COMMENT ON TABLE jobs           IS 'Definiții joburi și facțiuni';
COMMENT ON TABLE job_grades     IS 'Grade/ranguri per job cu permisiuni și salariu';
COMMENT ON TABLE character_jobs IS 'Jobul curent al fiecărui personaj';
COMMENT ON TABLE job_duty_logs  IS 'Log ture de serviciu (clock-in/out)';
