-- ==================== SHOWROOM SCHEMA ====================

CREATE TABLE IF NOT EXISTS dealerships (
    id         SERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    code       TEXT        NOT NULL UNIQUE,
    coords     JSONB       NOT NULL,
    npc_model  TEXT,
    is_active  BOOLEAN     NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicle_catalog (
    id                SERIAL PRIMARY KEY,
    dealership_id     INT         NOT NULL REFERENCES dealerships(id) ON DELETE CASCADE,
    model             TEXT        NOT NULL,
    label             TEXT        NOT NULL,
    category          TEXT        NOT NULL,
    price             NUMERIC     NOT NULL CHECK (price >= 0),
    finance_eligible  BOOLEAN     NOT NULL DEFAULT true,
    vip_only          BOOLEAN     NOT NULL DEFAULT false,
    sort_order        INT         NOT NULL DEFAULT 0,
    is_active         BOOLEAN     NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicle_purchases (
    id             SERIAL PRIMARY KEY,
    character_id   INT         NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    catalog_id     INT         REFERENCES vehicle_catalog(id) ON DELETE SET NULL,
    vehicle_id     INT         NOT NULL REFERENCES owned_vehicles(id) ON DELETE CASCADE,
    price_paid     NUMERIC     NOT NULL,
    payment_method TEXT        NOT NULL CHECK (payment_method IN ('cash', 'bank', 'finance')),
    loan_id        INT,
    purchased_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS test_drives (
    id           SERIAL PRIMARY KEY,
    character_id INT         NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    catalog_id   INT         NOT NULL REFERENCES vehicle_catalog(id) ON DELETE CASCADE,
    plate        TEXT        NOT NULL,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ NOT NULL,
    returned     BOOLEAN     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_vehicle_catalog_dealership ON vehicle_catalog(dealership_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_catalog_active     ON vehicle_catalog(is_active);
CREATE INDEX IF NOT EXISTS idx_test_drives_character      ON test_drives(character_id);
CREATE INDEX IF NOT EXISTS idx_test_drives_active         ON test_drives(character_id, returned);
