-- ==================== TUNING SCHEMA ====================

-- Magazine de tuning (LS Customs locations)
CREATE TABLE IF NOT EXISTS tuning_shops (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    code        VARCHAR(30) UNIQUE NOT NULL,
    coords      JSONB NOT NULL,
    is_active   BOOLEAN DEFAULT true NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tuning_shops_code     ON tuning_shops(code);
CREATE INDEX IF NOT EXISTS idx_tuning_shops_active   ON tuning_shops(is_active);

-- Prețuri per categorie și tier (editabile din PostgreSQL / admin panel)
CREATE TABLE IF NOT EXISTS tuning_prices (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category    VARCHAR(50) NOT NULL,
    tier        INTEGER NOT NULL,
    price       NUMERIC(12,2) NOT NULL,
    vip_only    BOOLEAN DEFAULT false NOT NULL,
    CONSTRAINT  unique_tuning_price UNIQUE (category, tier)
);

CREATE INDEX IF NOT EXISTS idx_tuning_prices_category ON tuning_prices(category);

-- Istoric upgrade-uri per vehicul / personaj
CREATE TABLE IF NOT EXISTS tuning_logs (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    vehicle_id      BIGINT  NOT NULL REFERENCES owned_vehicles(id) ON DELETE CASCADE,
    shop_id         INTEGER REFERENCES tuning_shops(id) ON DELETE SET NULL,
    category        VARCHAR(50) NOT NULL,
    tier_before     INTEGER,
    tier_after      INTEGER NOT NULL,
    price_paid      NUMERIC(12,2) NOT NULL,
    applied_at      TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tuning_logs_character_id ON tuning_logs(character_id);
CREATE INDEX IF NOT EXISTS idx_tuning_logs_vehicle_id   ON tuning_logs(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_tuning_logs_applied_at   ON tuning_logs(applied_at);

COMMENT ON TABLE tuning_shops  IS 'Locații magazine de tuning (LS Customs)';
COMMENT ON TABLE tuning_prices IS 'Prețuri per categorie și tier de upgrade; editabile runtime';
COMMENT ON TABLE tuning_logs   IS 'Istoric tuning per vehicul și personaj cu cost plătit';
