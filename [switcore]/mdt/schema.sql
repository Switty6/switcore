-- ==================== MDT SCHEMA ====================

CREATE TABLE IF NOT EXISTS police_citations (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    officer_id  INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    suspect_id  INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    offense     TEXT NOT NULL,
    fine_amount INTEGER NOT NULL DEFAULT 500,
    is_paid     BOOLEAN NOT NULL DEFAULT FALSE,
    issued_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS police_bolos (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    officer_id   INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    subject_name TEXT NOT NULL,
    description  TEXT NOT NULL,
    vehicle_info TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at    TIMESTAMPTZ,
    closed_by    INTEGER REFERENCES characters(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS police_incidents (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    officer_id          INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    title               TEXT NOT NULL,
    description         TEXT NOT NULL,
    location            JSONB,
    involved_characters JSONB NOT NULL DEFAULT '[]',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS police_impounds (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    officer_id   INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    owner_id     INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    plate        VARCHAR(8) NOT NULL,
    model        VARCHAR(100),
    reason       TEXT NOT NULL,
    fee          INTEGER NOT NULL DEFAULT 2500,
    is_retrieved BOOLEAN NOT NULL DEFAULT FALSE,
    impounded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    retrieved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_citations_suspect ON police_citations(suspect_id);
CREATE INDEX IF NOT EXISTS idx_citations_officer ON police_citations(officer_id);
CREATE INDEX IF NOT EXISTS idx_bolos_active      ON police_bolos(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_incidents_recent  ON police_incidents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_impounds_plate    ON police_impounds(plate);
CREATE INDEX IF NOT EXISTS idx_impounds_active   ON police_impounds(is_retrieved) WHERE is_retrieved = FALSE;
