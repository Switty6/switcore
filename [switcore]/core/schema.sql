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

-- ==================== PERMISIUNI ȘI GRUPURI ====================

-- Grupurile (roluri) - ex: admin, moderator, vip, player
CREATE TABLE IF NOT EXISTS groups (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    priority INTEGER DEFAULT 0 NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_groups_name ON groups(name);
CREATE INDEX IF NOT EXISTS idx_groups_priority ON groups(priority);

-- Permisiunile individuale
CREATE TABLE IF NOT EXISTS permissions (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_permissions_name ON permissions(name);

-- Relație many-to-many: Grupuri -> Permisiuni
CREATE TABLE IF NOT EXISTS group_permissions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_group_permission UNIQUE (group_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_group_permissions_group_id ON group_permissions(group_id);
CREATE INDEX IF NOT EXISTS idx_group_permissions_permission_id ON group_permissions(permission_id);

-- Relație many-to-many: Jucători -> Grupuri (un jucător poate avea mai multe grupuri)
CREATE TABLE IF NOT EXISTS player_groups (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT NOW() NOT NULL,
    assigned_by INTEGER REFERENCES players(id),
    expires_at TIMESTAMP,
    CONSTRAINT unique_player_group UNIQUE (player_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_player_groups_player_id ON player_groups(player_id);
CREATE INDEX IF NOT EXISTS idx_player_groups_group_id ON player_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_player_groups_expires_at ON player_groups(expires_at);

COMMENT ON TABLE groups IS 'Grupurile de utilizatori (roluri): admin, moderator, vip, player, etc.';
COMMENT ON TABLE permissions IS 'Permisiunile individuale care pot fi atribuite grupuri';
COMMENT ON TABLE group_permissions IS 'Relație many-to-many între grupuri și permisiuni';
COMMENT ON TABLE player_groups IS 'Grupurile atribuite jucătorilor (un jucător poate avea mai multe grupuri)';

