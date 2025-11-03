CREATE TABLE IF NOT EXISTS players (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP,
    last_seen TIMESTAMP,
    playtime INTEGER DEFAULT 0 NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_players_name ON players(name);

CREATE TABLE IF NOT EXISTS player_identifiers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    value VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_identifier UNIQUE (type, value)
);

-- Index non-unique pe value pentru căutări rapide (dar nu e unique - un identifier poate aparține unui singur jucător)
CREATE INDEX IF NOT EXISTS idx_player_identifiers_value ON player_identifiers(value);
CREATE INDEX IF NOT EXISTS idx_player_identifiers_player_id ON player_identifiers(player_id);
CREATE INDEX IF NOT EXISTS idx_player_identifiers_type ON player_identifiers(type);

CREATE TABLE IF NOT EXISTS player_activity_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    command VARCHAR(255),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_player_activity_log_player_id ON player_activity_log(player_id);
CREATE INDEX IF NOT EXISTS idx_player_activity_log_created_at ON player_activity_log(created_at);
CREATE INDEX IF NOT EXISTS idx_player_activity_log_event_type ON player_activity_log(event_type);

COMMENT ON TABLE players IS 'Informații de bază despre jucători';
COMMENT ON TABLE player_identifiers IS 'Stocare TOATE identifiers pentru fiecare jucător (license, steam, discord, etc.)';
COMMENT ON TABLE player_activity_log IS 'Logging activitate: join, quit, comenzi executate';

