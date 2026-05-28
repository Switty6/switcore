-- ==================== VEHICLES SCHEMA ====================

-- Vehicule deținute de caractere
CREATE TABLE IF NOT EXISTS owned_vehicles (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id    INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    plate           VARCHAR(8) UNIQUE NOT NULL,
    model           VARCHAR(100) NOT NULL,
    label           VARCHAR(100),
    category        VARCHAR(30) NOT NULL DEFAULT 'sedans',
    fuel            NUMERIC(5,2) DEFAULT 100.0 NOT NULL,
    mileage         NUMERIC(12,2) DEFAULT 0.0 NOT NULL,
    body_health     NUMERIC(7,2) DEFAULT 1000.0 NOT NULL,
    engine_health   NUMERIC(7,2) DEFAULT 1000.0 NOT NULL,
    modifications   JSONB DEFAULT '{}'::jsonb NOT NULL,
    components      JSONB DEFAULT '{"oil":100,"battery":100,"brakes":100,"exhaust":100,"tires":{"fl":100,"fr":100,"rl":100,"rr":100},"suspension":{"fl":100,"fr":100,"rl":100,"rr":100}}'::jsonb NOT NULL,
    stored          BOOLEAN DEFAULT true NOT NULL,
    impounded       BOOLEAN DEFAULT false NOT NULL,
    last_position   JSONB,
    purchased_at    TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMP
);

CREATE SEQUENCE IF NOT EXISTS plate_number_seq START WITH 1 INCREMENT BY 1;

CREATE INDEX IF NOT EXISTS idx_owned_vehicles_character_id ON owned_vehicles(character_id);
CREATE INDEX IF NOT EXISTS idx_owned_vehicles_plate        ON owned_vehicles(plate);
CREATE INDEX IF NOT EXISTS idx_owned_vehicles_stored       ON owned_vehicles(stored);
CREATE INDEX IF NOT EXISTS idx_owned_vehicles_impounded    ON owned_vehicles(impounded);

-- Chei vehicule (mai mulți utilizatori pot avea cheie la același vehicul)
CREATE TABLE IF NOT EXISTS vehicle_keys (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_id      BIGINT NOT NULL REFERENCES owned_vehicles(id) ON DELETE CASCADE,
    character_id    INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    key_type        VARCHAR(20) DEFAULT 'standard' NOT NULL
                        CHECK (key_type IN ('owner', 'standard')),
    given_at        TIMESTAMP DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_vehicle_key UNIQUE (vehicle_id, character_id)
);

CREATE INDEX IF NOT EXISTS idx_vehicle_keys_vehicle_id   ON vehicle_keys(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_keys_character_id ON vehicle_keys(character_id);

COMMENT ON TABLE owned_vehicles IS 'Vehicule cumpărate sau acordate caracterelor';
COMMENT ON TABLE vehicle_keys   IS 'Chei vehicule acordate între caractere';
