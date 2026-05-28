# Modul: banking

**Locație:** `[switcore]/banking/`
**Dependențe:** `core`, `postgres`, `characters`, `proximity`, `settings`

## Fișiere server

| Fișier | Rol |
|--------|-----|
| `server/banking_database.lua` | CRUD conturi, tranzacții, valute |
| `server/banking_helpers.lua` | Funcții utilitare (formatare, validare) |
| `server/currency_manager.lua` | Creare valute, rate schimb, conversii |
| `server/fee_manager.lua` | Comisioane bancare per tip tranzacție |
| `server/banking_manager.lua` | Deposit, withdraw, transfer logic |
| `server/loan_manager.lua` | Credite, rate lunare, rambursare |
| `server/inflation_manager.lua` | Inflație automată periodică |
| `server/org_manager.lua` | Conturi organizații (police, ems, etc.) |
| `server/exports.lua` | API publică |
| `server/callbacks.lua` | RegisterNetEvent handlers |
| `server/server.lua` | Init, seed date, ATM/bank locations |

## UI

- `ui/atm/` - interfață ATM (retragere, depunere cash)
- `ui/bank/` - interfață bancă (conturi, transfer, credite, extras)

---

## Exports (server-side)

### Cash (bani fizici, per personaj)
```lua
exports.banking:getCharacterCash(characterId, currencyCode)        → amount
exports.banking:setCharacterCash(characterId, amount, currencyCode) → bool
exports.banking:addCharacterCash(characterId, amount, currencyCode) → bool
exports.banking:getCharacterAllCash(characterId)                   → {currencyCode: amount}
```

### Conturi bancare
```lua
exports.banking:createAccount(characterId, bankCode, currencyCode, type) → account
exports.banking:getAccountByNumber(accountNumber)   → account
exports.banking:getAccountById(accountId)           → account
exports.banking:getCharacterAccounts(characterId)   → account[]
exports.banking:getAccountBalance(accountId)        → amount
```

### Operațiuni
```lua
exports.banking:deposit(accountId, amount, currencyCode, description)      → {bool, err}
exports.banking:withdraw(accountId, amount, currencyCode, description)     → {bool, err}
exports.banking:transfer(fromId, toId, amount, currencyCode, description)  → {bool, err}
```

### Valute
```lua
exports.banking:createCurrency(code, name, symbol)             → currency
exports.banking:getCurrencyByCode(code)                        → currency
exports.banking:getCurrencyById(id)                            → currency
exports.banking:getActiveCurrencies()                          → currency[]
exports.banking:setExchangeRate(fromCode, toCode, rate)        → bool
exports.banking:getExchangeRate(fromCode, toCode)              → rate
exports.banking:exchangeCurrency(accountId, fromCode, toCode, amount) → {bool, err}
```

### Comisioane
```lua
exports.banking:setBankFee(bankCode, feeType, percentage)      → bool
exports.banking:getBankFee(bankCode, feeType)                  → percentage
exports.banking:getBankFees(bankCode)                          → fees[]
exports.banking:calculateFee(bankCode, feeType, amount)        → feeAmount
```

### Credite (loans)
```lua
exports.banking:createLoan(characterId, bankCode, amount, termMonths, type) → {bool, err, loan}
exports.banking:getLoanById(loanId)                            → loan
exports.banking:getCharacterActiveLoans(characterId)           → loan[]
exports.banking:makeLoanPayment(loanId, amount)                → {bool, err}
exports.banking:getCharacterTotalDebt(characterId)             → amount
```

### Inflație
```lua
exports.banking:calculateInflation(amount, rate)    → adjustedAmount
exports.banking:getInflationRate()                  → rate
exports.banking:getInflationHistory()               → history[]
exports.banking:getTotalMoneySupply()               → amount
```

### Tranzacții
```lua
exports.banking:getCharacterTransactions(characterId, limit)   → transactions[]
exports.banking:createTransaction(fromId, toId, amount, currencyId, desc) → transaction
```

### Organizații
```lua
exports.banking:getOrg(orgId)                                  → org
exports.banking:getOrgAccountBalance(orgId, currencyCode)      → amount
exports.banking:orgDeposit(orgId, amount, currencyCode, desc)  → {bool, err}
exports.banking:orgWithdraw(orgId, amount, currencyCode, desc) → {bool, err}
exports.banking:orgSystemDebit(orgId, amount, currencyCode, desc)  -- sistem retrage
exports.banking:orgSystemCredit(orgId, amount, currencyCode, desc) -- sistem adaugă
exports.banking:getOrgTransactions(orgId, limit)               → transactions[]
exports.banking:isOrgMember(characterId, orgId)                → bool
exports.banking:createOrgAccount(orgId, bankCode, currencyCode) → account
exports.banking:ensureOrgAccount(orgId, orgName, bankCode, currencyCode) → account
```

---

## Schema DB

```sql
currencies (
    id            SERIAL PRIMARY KEY,
    code          VARCHAR(10) UNIQUE,   -- 'USD', 'RON', etc.
    name          VARCHAR(100),
    symbol        VARCHAR(10),
    exchange_rate NUMERIC(12,6) DEFAULT 1.0,
    is_active     BOOLEAN DEFAULT true
)

banks (
    id       SERIAL PRIMARY KEY,
    code     VARCHAR(30) UNIQUE,    -- 'MAZE', 'FLEECA', etc.
    name     VARCHAR(100),
    type     VARCHAR(20),           -- 'retail', 'investment', etc.
    is_active BOOLEAN DEFAULT true
)

bank_accounts (
    id             BIGSERIAL PRIMARY KEY,
    character_id   INTEGER REFERENCES characters(id),
    bank_id        INTEGER REFERENCES banks(id),
    currency_id    INTEGER REFERENCES currencies(id),
    account_number VARCHAR(20) UNIQUE,
    balance        NUMERIC(16,2) DEFAULT 0,
    type           VARCHAR(20),   -- 'checking', 'savings', 'business'
    is_active      BOOLEAN DEFAULT true,
    created_at     TIMESTAMP DEFAULT NOW()
)

transactions (
    id              BIGSERIAL PRIMARY KEY,
    from_account_id BIGINT REFERENCES bank_accounts(id),
    to_account_id   BIGINT REFERENCES bank_accounts(id),
    amount          NUMERIC(16,2),
    currency_id     INTEGER REFERENCES currencies(id),
    description     TEXT,
    fee_amount      NUMERIC(16,2) DEFAULT 0,
    created_at      TIMESTAMP DEFAULT NOW()
)

loans (
    id              BIGSERIAL PRIMARY KEY,
    character_id    INTEGER REFERENCES characters(id),
    bank_id         INTEGER REFERENCES banks(id),
    amount          NUMERIC(16,2),
    remaining       NUMERIC(16,2),
    term_months     INTEGER,
    monthly_payment NUMERIC(16,2),
    type            VARCHAR(30),    -- 'personal', 'auto', 'mortgage'
    status          VARCHAR(20),    -- 'active', 'paid', 'defaulted'
    created_at      TIMESTAMP DEFAULT NOW()
)

org_accounts (
    id          BIGSERIAL PRIMARY KEY,
    org_id      INTEGER,           -- ID organizație (police=1, ems=2, etc.)
    bank_id     INTEGER REFERENCES banks(id),
    currency_id INTEGER REFERENCES currencies(id),
    balance     NUMERIC(16,2) DEFAULT 0
)
```

---

## Pattern plată în alte module

```lua
-- Plată cash
local success = exports.banking:addCharacterCash(characterId, -amount, 'USD')
if not success then
    TriggerClientEvent('switcore:notify', source, 'error', 'Fonduri insuficiente', 5000)
    return
end

-- Plată din cont bancar
local result = exports.banking:withdraw(accountId, amount, 'USD', 'Descriere plată')
if not result then
    TriggerClientEvent('switcore:notify', source, 'error', 'Eroare bancară', 5000)
    return
end
```
