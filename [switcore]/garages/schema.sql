-- ==================== GARAGES SCHEMA ====================

-- Locații garaje/parcări/impound pe hartă
CREATE TABLE IF NOT EXISTS garages (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    code        VARCHAR(30) UNIQUE NOT NULL,
    type        VARCHAR(20) NOT NULL DEFAULT 'public'
                    CHECK (type IN ('public', 'private', 'impound', 'vip')),
    coords      JSONB NOT NULL,
    spawn_point JSONB NOT NULL,
    is_active   BOOLEAN DEFAULT true NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_garages_code      ON garages(code);
CREATE INDEX IF NOT EXISTS idx_garages_type      ON garages(type);
CREATE INDEX IF NOT EXISTS idx_garages_is_active ON garages(is_active);

-- Istoric parcare/scoatere vehicule
CREATE TABLE IF NOT EXISTS garage_logs (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id      BIGINT NOT NULL REFERENCES owned_vehicles(id) ON DELETE CASCADE,
    character_id    INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    garage_id       INTEGER NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
    action          VARCHAR(20) NOT NULL CHECK (action IN ('parked', 'retrieved')),
    fuel_at_action  NUMERIC(5,2),
    created_at      TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_garage_logs_vehicle_id   ON garage_logs(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_garage_logs_character_id ON garage_logs(character_id);
CREATE INDEX IF NOT EXISTS idx_garage_logs_created_at   ON garage_logs(created_at DESC);

-- Amenzi de parcare
CREATE TABLE IF NOT EXISTS parking_tickets (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    vehicle_id      BIGINT NOT NULL REFERENCES owned_vehicles(id) ON DELETE CASCADE,
    plate           VARCHAR(8) NOT NULL,
    fine_amount     NUMERIC(12,2) NOT NULL,
    reason          TEXT,
    paid            BOOLEAN DEFAULT false NOT NULL,
    issued_by       INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    issued_at       TIMESTAMP DEFAULT NOW() NOT NULL,
    paid_at         TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_parking_tickets_character_id ON parking_tickets(character_id);
CREATE INDEX IF NOT EXISTS idx_parking_tickets_vehicle_id   ON parking_tickets(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_parking_tickets_paid         ON parking_tickets(paid);

COMMENT ON TABLE garages          IS 'Locații garaje, parcări și impound pe hartă';
COMMENT ON TABLE garage_logs      IS 'Istoric parcare/scoatere vehicule';
COMMENT ON TABLE parking_tickets  IS 'Amenzi de parcare emise jucătorilor';
