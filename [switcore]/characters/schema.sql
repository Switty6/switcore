-- Schema pentru Sistemul de Caractere
-- Extinde tabela players cu suport pentru caractere

-- Tabela pentru Caractere
CREATE TABLE IF NOT EXISTS characters (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    age INTEGER NOT NULL CHECK (age >= 18 AND age <= 80),
    position JSONB,
    appearance JSONB,
    stats JSONB,
    metadata JSONB,
    playtime INTEGER DEFAULT 0 NOT NULL,
    last_played TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP
);

-- Indexari pentru tabela characters
CREATE INDEX IF NOT EXISTS idx_characters_player_id ON characters(player_id);
CREATE INDEX IF NOT EXISTS idx_characters_first_name ON characters(first_name);
CREATE INDEX IF NOT EXISTS idx_characters_last_name ON characters(last_name);
CREATE INDEX IF NOT EXISTS idx_characters_last_played ON characters(last_played);
CREATE INDEX IF NOT EXISTS idx_characters_player_id_last_played ON characters(player_id, last_played DESC);

-- Tabela pentru Statistici ale Caracterelor
CREATE TABLE IF NOT EXISTS character_statistics (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    stat_name VARCHAR(100) NOT NULL,
    stat_value NUMERIC DEFAULT 0 NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_character_stat UNIQUE (character_id, stat_name)
);

-- Indexari pentru tabela character_statistics
CREATE INDEX IF NOT EXISTS idx_character_statistics_character_id ON character_statistics(character_id);
CREATE INDEX IF NOT EXISTS idx_character_statistics_stat_name ON character_statistics(stat_name);

COMMENT ON TABLE characters IS 'Datele caracterului legate de contul jucatorului';
COMMENT ON TABLE character_statistics IS 'Statistici de tracking pentru caractere (playtime, distance_traveled, etc.)';

