-- ============================================================================
-- SwitCore - Modul ADMIN
-- ----------------------------------------------------------------------------
-- Schema este creată și automat la primul start al resursei (vezi server.lua),
-- dar este replicată aici pentru consistență cu restul modulelor și pentru
-- a permite rularea manuală cu `psql -f schema.sql`.
-- ============================================================================

-- Jurnal de audit pentru toate acțiunile administrative
-- (kick, ban, warn, give cash, give item, set group, teleport, etc.)
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id          BIGSERIAL PRIMARY KEY,
    admin_src   INT,              -- player source-ul admin-ului la momentul acțiunii (0 = console)
    admin_name  TEXT,              -- numele in-game al admin-ului
    admin_db_id INT,               -- id-ul din tabela `players` (NULL pentru console)
    action      TEXT NOT NULL,     -- tipul acțiunii (ex: 'kick', 'ban', 'give_cash')
    target_src  INT,               -- source-ul jucătorului țintă (NULL dacă offline / N/A)
    target_name TEXT,              -- numele jucătorului țintă
    details     JSONB,             -- payload arbitrar cu detaliile acțiunii
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS admin_audit_log_created_idx
    ON admin_audit_log (created_at DESC);

CREATE INDEX IF NOT EXISTS admin_audit_log_action_idx
    ON admin_audit_log (action);

CREATE INDEX IF NOT EXISTS admin_audit_log_admin_db_id_idx
    ON admin_audit_log (admin_db_id);
