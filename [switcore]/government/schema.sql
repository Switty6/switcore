-- ============================================================
-- SwitCore Government Module - Schema
-- ============================================================

CREATE TABLE IF NOT EXISTS government_law_proposals (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    description  TEXT NOT NULL,
    category     VARCHAR(50)  NOT NULL,
    penalty      VARCHAR(200),
    fine_amount  INT          NOT NULL DEFAULT 0,
    proposed_by  INT          REFERENCES characters(id) ON DELETE SET NULL,
    status       VARCHAR(20)  NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','passed','rejected')),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS government_law_votes (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proposal_id  BIGINT       NOT NULL REFERENCES government_law_proposals(id) ON DELETE CASCADE,
    character_id INT          NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    vote         VARCHAR(5)   NOT NULL CHECK (vote IN ('yes','no')),
    voted_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (proposal_id, character_id)
);

CREATE TABLE IF NOT EXISTS government_laws (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    proposal_id  BIGINT       REFERENCES government_law_proposals(id) ON DELETE SET NULL,
    title        VARCHAR(200) NOT NULL,
    description  TEXT         NOT NULL,
    category     VARCHAR(50)  NOT NULL,
    penalty      VARCHAR(200),
    fine_amount  INT          NOT NULL DEFAULT 0,
    created_by   INT          REFERENCES characters(id) ON DELETE SET NULL,
    repealed_by  INT          REFERENCES characters(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    repealed_at  TIMESTAMPTZ,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_government_laws_active ON government_laws (is_active);

CREATE TABLE IF NOT EXISTS government_budget_log (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type          VARCHAR(10)  NOT NULL CHECK (type IN ('income','expense')),
    amount        BIGINT       NOT NULL CHECK (amount > 0),
    currency_code VARCHAR(10)  NOT NULL DEFAULT 'RON',
    description   TEXT         NOT NULL,
    category      VARCHAR(50),
    created_by    INT          REFERENCES characters(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_government_budget_log_date ON government_budget_log (created_at DESC);

CREATE TABLE IF NOT EXISTS government_parties (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         VARCHAR(100) NOT NULL UNIQUE,
    color        VARCHAR(7)   NOT NULL DEFAULT '#00b4ff',
    manifesto    TEXT,
    leader_id    INT          REFERENCES characters(id) ON DELETE SET NULL,
    founded_by   INT          REFERENCES characters(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS government_party_members (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    party_id     BIGINT       NOT NULL REFERENCES government_parties(id) ON DELETE CASCADE,
    character_id INT          NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    role         VARCHAR(30)  NOT NULL DEFAULT 'member' CHECK (role IN ('leader','vice','secretary','member')),
    joined_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (party_id, character_id)
);

CREATE INDEX IF NOT EXISTS idx_gov_party_members_char ON government_party_members (character_id);

CREATE TABLE IF NOT EXISTS government_elections (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    position             VARCHAR(100) NOT NULL,
    description          TEXT,
    started_by           INT          REFERENCES characters(id) ON DELETE SET NULL,
    started_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ended_at             TIMESTAMPTZ,
    status               VARCHAR(20)  NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed')),
    winner_character_id  INT          REFERENCES characters(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS government_election_candidates (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    election_id  BIGINT NOT NULL REFERENCES government_elections(id) ON DELETE CASCADE,
    character_id INT    NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    party_id     BIGINT REFERENCES government_parties(id) ON DELETE SET NULL,
    votes        INT    NOT NULL DEFAULT 0,
    UNIQUE (election_id, character_id)
);

CREATE TABLE IF NOT EXISTS government_election_votes (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    election_id  BIGINT NOT NULL REFERENCES government_elections(id) ON DELETE CASCADE,
    voter_id     INT    NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    candidate_id BIGINT NOT NULL REFERENCES government_election_candidates(id) ON DELETE CASCADE,
    voted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (election_id, voter_id)
);
