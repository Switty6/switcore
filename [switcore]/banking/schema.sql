
-- Tabela pentru Valute
CREATE TABLE IF NOT EXISTS currencies (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(10) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_currencies_code ON currencies(code);
CREATE INDEX IF NOT EXISTS idx_currencies_is_active ON currencies(is_active);

-- Tabela pentru Istoric Cursuri de Schimb (pentru valute dinamice)
CREATE TABLE IF NOT EXISTS currency_exchange_rates (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_from_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE CASCADE,
    currency_to_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE CASCADE,
    rate NUMERIC(20, 8) NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_currency_exchange_rates_from ON currency_exchange_rates(currency_from_id);
CREATE INDEX IF NOT EXISTS idx_currency_exchange_rates_to ON currency_exchange_rates(currency_to_id);
CREATE INDEX IF NOT EXISTS idx_currency_exchange_rates_timestamp ON currency_exchange_rates(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_currency_exchange_rates_pair ON currency_exchange_rates(currency_from_id, currency_to_id, timestamp DESC);

-- Tabela pentru Bănci
CREATE TABLE IF NOT EXISTS banks (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(10) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    owner_character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_banks_code ON banks(code);
CREATE INDEX IF NOT EXISTS idx_banks_is_active ON banks(is_active);
CREATE INDEX IF NOT EXISTS idx_banks_owner ON banks(owner_character_id);

-- Tabela pentru Conturi Bancare
CREATE TABLE IF NOT EXISTS bank_accounts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    bank_id INTEGER NOT NULL REFERENCES banks(id) ON DELETE RESTRICT,
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('current', 'savings', 'deposit')),
    account_number VARCHAR(50) UNIQUE NOT NULL,
    balance JSONB DEFAULT '{}' NOT NULL,
    interest_rate NUMERIC(5, 4) DEFAULT 0.0 NOT NULL,
    deposit_term_days INTEGER,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP,
    last_interest_calculation TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_character_id ON bank_accounts(character_id);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_bank_id ON bank_accounts(bank_id);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_account_number ON bank_accounts(account_number);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_account_type ON bank_accounts(account_type);

-- Tabela pentru Comisioane Bancare
CREATE TABLE IF NOT EXISTS bank_fees (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bank_id INTEGER NOT NULL REFERENCES banks(id) ON DELETE CASCADE,
    fee_type VARCHAR(50) NOT NULL CHECK (fee_type IN ('transfer_same_bank', 'transfer_different_bank', 'withdrawal', 'deposit', 'currency_exchange')),
    fee_type_value VARCHAR(20) NOT NULL CHECK (fee_type_value IN ('percentage', 'fixed')),
    fee_amount NUMERIC(20, 8) NOT NULL,
    currency_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE RESTRICT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP,
    CONSTRAINT unique_bank_fee UNIQUE (bank_id, fee_type)
);

CREATE INDEX IF NOT EXISTS idx_bank_fees_bank_id ON bank_fees(bank_id);
CREATE INDEX IF NOT EXISTS idx_bank_fees_fee_type ON bank_fees(fee_type);
CREATE INDEX IF NOT EXISTS idx_bank_fees_is_active ON bank_fees(is_active);

-- Tabela pentru Cash per Caracter per Valută
CREATE TABLE IF NOT EXISTS character_cash (
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    currency_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE RESTRICT,
    amount NUMERIC(20, 2) DEFAULT 0.0 NOT NULL,
    CONSTRAINT pk_character_cash PRIMARY KEY (character_id, currency_id)
);

CREATE INDEX IF NOT EXISTS idx_character_cash_character_id ON character_cash(character_id);
CREATE INDEX IF NOT EXISTS idx_character_cash_currency_id ON character_cash(currency_id);

-- Tabela pentru Împrumuturi
CREATE TABLE IF NOT EXISTS loans (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    bank_id INTEGER NOT NULL REFERENCES banks(id) ON DELETE RESTRICT,
    loan_type VARCHAR(20) NOT NULL CHECK (loan_type IN ('personal', 'mortgage', 'business')),
    principal_amount NUMERIC(20, 2) NOT NULL,
    interest_rate NUMERIC(5, 4) NOT NULL,
    remaining_amount NUMERIC(20, 2) NOT NULL,
    monthly_payment NUMERIC(20, 2) NOT NULL,
    total_payments INTEGER NOT NULL,
    payments_made INTEGER DEFAULT 0 NOT NULL,
    next_payment_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active' NOT NULL CHECK (status IN ('active', 'paid', 'defaulted')),
    currency_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE RESTRICT,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_loans_character_id ON loans(character_id);
CREATE INDEX IF NOT EXISTS idx_loans_bank_id ON loans(bank_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_next_payment_date ON loans(next_payment_date);

-- Tabela pentru Istoric Plăți Credite
CREATE TABLE IF NOT EXISTS loan_payments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id BIGINT NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    amount_paid NUMERIC(20, 2) NOT NULL,
    payment_date TIMESTAMP DEFAULT NOW() NOT NULL,
    is_on_time BOOLEAN DEFAULT true NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_loan_payments_loan_id ON loan_payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_payment_date ON loan_payments(payment_date);

-- Tabela pentru Istoric Tranzacții
CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer', 'currency_exchange', 'loan_payment', 'interest', 'fee')),
    from_account_id BIGINT REFERENCES bank_accounts(id) ON DELETE SET NULL,
    to_account_id BIGINT REFERENCES bank_accounts(id) ON DELETE SET NULL,
    amount NUMERIC(20, 2) NOT NULL,
    currency_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE RESTRICT,
    fee_amount NUMERIC(20, 2) DEFAULT 0.0,
    fee_currency_id INTEGER REFERENCES currencies(id) ON DELETE SET NULL,
    description TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_transactions_character_id ON transactions(character_id);
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_type ON transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);

-- Tabela pentru Metrici Economice (pentru calcul inflație)
CREATE TABLE IF NOT EXISTS economy_metrics (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    metric_type VARCHAR(50) NOT NULL CHECK (metric_type IN ('total_money_supply', 'inflation_rate')),
    currency_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE CASCADE,
    value NUMERIC(20, 8) NOT NULL,
    calculated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_economy_metrics_metric_type ON economy_metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_economy_metrics_currency_id ON economy_metrics(currency_id);
CREATE INDEX IF NOT EXISTS idx_economy_metrics_calculated_at ON economy_metrics(calculated_at DESC);

-- Tabela pentru Istoric Inflație
CREATE TABLE IF NOT EXISTS inflation_history (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    currency_id INTEGER NOT NULL REFERENCES currencies(id) ON DELETE CASCADE,
    inflation_rate NUMERIC(10, 6) NOT NULL,
    total_money_supply NUMERIC(20, 2) NOT NULL,
    calculated_at TIMESTAMP DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_inflation_history_currency_id ON inflation_history(currency_id);
CREATE INDEX IF NOT EXISTS idx_inflation_history_calculated_at ON inflation_history(calculated_at DESC);

COMMENT ON TABLE currencies IS 'Valute disponibile în sistem (USD, EUR, etc.)';
COMMENT ON TABLE currency_exchange_rates IS 'Istoric cursuri de schimb pentru valute dinamice';
COMMENT ON TABLE banks IS 'Bănci disponibile (Maze Bank, Flecca Bank, etc.)';
COMMENT ON TABLE bank_accounts IS 'Conturi bancare ale caracterelor';
COMMENT ON TABLE bank_fees IS 'Comisioane bancare configurabile per bancă și tip operațiune';
COMMENT ON TABLE character_cash IS 'Cash per caracter per valută';
COMMENT ON TABLE loans IS 'Împrumuturi acordate caracterelor';
COMMENT ON TABLE loan_payments IS 'Istoric plăți pentru credite';
COMMENT ON TABLE transactions IS 'Istoric complet al tuturor tranzacțiilor bancare';
COMMENT ON TABLE economy_metrics IS 'Metrici economice pentru calculul inflației';
COMMENT ON TABLE inflation_history IS 'Istoric calculări inflație per valută';

-- ==================== CONTURI ORGANIZAȚII ====================

-- Organizații (instituții de stat, companii private)
CREATE TABLE IF NOT EXISTS organizations (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    label       VARCHAR(100) NOT NULL,
    type        VARCHAR(20) NOT NULL DEFAULT 'private'
                    CHECK (type IN ('state', 'government', 'private')),
    code        VARCHAR(30) UNIQUE NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_organizations_code      ON organizations(code);
CREATE INDEX IF NOT EXISTS idx_organizations_is_active ON organizations(is_active);

-- Conturi bancare ale organizațiilor
CREATE TABLE IF NOT EXISTS org_bank_accounts (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    org_id         BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    bank_id        INTEGER NOT NULL REFERENCES banks(id) ON DELETE RESTRICT,
    account_type   VARCHAR(20) NOT NULL DEFAULT 'current'
                       CHECK (account_type IN ('current', 'savings')),
    account_number VARCHAR(50) UNIQUE NOT NULL,
    balance        JSONB NOT NULL DEFAULT '{}',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_org_accounts_org    ON org_bank_accounts(org_id);
CREATE INDEX IF NOT EXISTS idx_org_accounts_number ON org_bank_accounts(account_number);

-- Membri cu acces la contul organizației
CREATE TABLE IF NOT EXISTS org_account_members (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    org_id       BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    can_view     BOOLEAN NOT NULL DEFAULT TRUE,
    can_deposit  BOOLEAN NOT NULL DEFAULT FALSE,
    can_withdraw BOOLEAN NOT NULL DEFAULT FALSE,
    can_manage   BOOLEAN NOT NULL DEFAULT FALSE,
    added_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, character_id)
);

CREATE INDEX IF NOT EXISTS idx_org_members_org  ON org_account_members(org_id);
CREATE INDEX IF NOT EXISTS idx_org_members_char ON org_account_members(character_id);

-- Istoric tranzacții organizație
CREATE TABLE IF NOT EXISTS org_transactions (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    org_id         BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    account_id     BIGINT NOT NULL REFERENCES org_bank_accounts(id) ON DELETE CASCADE,
    character_id   INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    type           VARCHAR(30) NOT NULL
                       CHECK (type IN ('deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'system')),
    amount         NUMERIC(20, 2) NOT NULL,
    currency_id    INTEGER NOT NULL REFERENCES currencies(id),
    balance_after  NUMERIC(20, 2) NOT NULL,
    description    TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_org_tx_org     ON org_transactions(org_id);
CREATE INDEX IF NOT EXISTS idx_org_tx_account ON org_transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_org_tx_created ON org_transactions(created_at DESC);

COMMENT ON TABLE organizations        IS 'Instituții de stat, guvern și companii private';
COMMENT ON TABLE org_bank_accounts    IS 'Conturi bancare ale organizațiilor';
COMMENT ON TABLE org_account_members  IS 'Membrii cu acces la conturile organizațiilor';
COMMENT ON TABLE org_transactions     IS 'Istoric tranzacții organizații';

-- Seed organizații implicite
INSERT INTO organizations (name, label, type, code) VALUES
    ('Departamentul de Politie', 'Poliție',  'state',      'police'),
    ('Guvernul Statului',        'Guvern',   'government', 'gov')
ON CONFLICT (code) DO NOTHING;

