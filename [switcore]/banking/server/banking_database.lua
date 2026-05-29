BankingDatabase = {}

local function db() return exports.postgres end

local function serializeJson(data) return json.encode(data) end

local function safeDB(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        exports.core:log('error', 'BANKING', tostring(label) .. ': ' .. tostring(err))
    end
    return ok, err
end

function BankingDatabase.createCurrency(code, name, symbol)
    local result = db():query(
        'INSERT INTO currencies (code, name, symbol, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING *',
        {code, name, symbol}
    )
    return result and result.rows and result.rows[1] or nil
end

function BankingDatabase.getCurrencyByCode(code)
    return db():queryOne('SELECT * FROM currencies WHERE code = $1', {code})
end

function BankingDatabase.getCurrencyById(currencyId)
    return db():queryOne('SELECT * FROM currencies WHERE id = $1', {currencyId})
end

function BankingDatabase.getActiveCurrencies()
    return db():queryAll('SELECT * FROM currencies WHERE is_active = true ORDER BY code')
end

function BankingDatabase.updateCurrency(currencyId, updates)
    local updateParts = {}
    local params = {}
    local paramCount = 0

    if updates.name then
        paramCount = paramCount + 1
        table.insert(updateParts, 'name = $' .. paramCount)
        table.insert(params, updates.name)
    end
    if updates.symbol then
        paramCount = paramCount + 1
        table.insert(updateParts, 'symbol = $' .. paramCount)
        table.insert(params, updates.symbol)
    end
    if updates.is_active ~= nil then
        paramCount = paramCount + 1
        table.insert(updateParts, 'is_active = $' .. paramCount)
        table.insert(params, updates.is_active)
    end

    if #updateParts == 0 then return false end

    table.insert(updateParts, 'updated_at = NOW()')
    paramCount = paramCount + 1
    table.insert(params, currencyId)

    local query = 'UPDATE currencies SET ' .. table.concat(updateParts, ', ') .. ' WHERE id = $' .. paramCount
    local success = pcall(function() db():query(query, params) end)
    return success
end

function BankingDatabase.addExchangeRate(currencyFromId, currencyToId, rate)
    local success = pcall(function()
        db():query(
            'INSERT INTO currency_exchange_rates (currency_from_id, currency_to_id, rate, timestamp) VALUES ($1, $2, $3, NOW())',
            {currencyFromId, currencyToId, rate}
        )
    end)
    return success
end

function BankingDatabase.getAverageExchangeRate(currencyFromId, currencyToId, hours)
    hours = math.max(1, math.min(tonumber(hours) or 24, 8760))
    local result = db():queryOne(
        'SELECT AVG(rate) as avg_rate FROM currency_exchange_rates WHERE currency_from_id = $1 AND currency_to_id = $2 AND timestamp > NOW() - make_interval(hours => $3)',
        {currencyFromId, currencyToId, hours}
    )
    return result and tonumber(result.avg_rate) or nil
end

function BankingDatabase.createBank(name, code, ownerCharacterId)
    local result
    if ownerCharacterId ~= nil then
        result = db():query(
            'INSERT INTO banks (name, code, owner_character_id, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING *',
            {name, code, ownerCharacterId}
        )
    else
        result = db():query(
            'INSERT INTO banks (name, code, created_at, updated_at) VALUES ($1, $2, NOW(), NOW()) RETURNING *',
            {name, code}
        )
    end
    return result and result.rows and result.rows[1] or nil
end

function BankingDatabase.getBankByCode(code)
    return db():queryOne('SELECT * FROM banks WHERE code = $1', {code})
end

function BankingDatabase.getBankById(bankId)
    return db():queryOne('SELECT * FROM banks WHERE id = $1', {bankId})
end

function BankingDatabase.getActiveBanks()
    return db():queryAll('SELECT * FROM banks WHERE is_active = true ORDER BY name')
end

function BankingDatabase.createBankAccount(characterId, bankId, accountType, accountNumber, interestRate, depositTermDays)
    local result
    if depositTermDays then
        result = db():query(
            [[
                INSERT INTO bank_accounts (character_id, bank_id, account_type, account_number, balance, interest_rate, deposit_term_days, created_at, updated_at)
                VALUES ($1, $2, $3, $4, '{}'::jsonb, $5, $6, NOW(), NOW())
                RETURNING *
            ]],
            {characterId, bankId, accountType, accountNumber, interestRate or 0.0, depositTermDays}
        )
    else
        result = db():query(
            [[
                INSERT INTO bank_accounts (character_id, bank_id, account_type, account_number, balance, interest_rate, created_at, updated_at)
                VALUES ($1, $2, $3, $4, '{}'::jsonb, $5, NOW(), NOW())
                RETURNING *
            ]],
            {characterId, bankId, accountType, accountNumber, interestRate or 0.0}
        )
    end
    return result and result.rows and result.rows[1] or nil
end

function BankingDatabase.getAccountByNumber(accountNumber)
    return db():queryOne('SELECT * FROM bank_accounts WHERE account_number = $1', {accountNumber})
end

function BankingDatabase.getAccountById(accountId)
    return db():queryOne('SELECT * FROM bank_accounts WHERE id = $1', {accountId})
end

function BankingDatabase.getCharacterAccounts(characterId)
    return db():queryAll(
        'SELECT ba.*, b.name as bank_name, b.code as bank_code FROM bank_accounts ba JOIN banks b ON ba.bank_id = b.id WHERE ba.character_id = $1 ORDER BY ba.created_at DESC',
        {characterId}
    )
end

function BankingDatabase.updateAccountBalance(accountId, balanceJson)
    local success = pcall(function()
        db():query(
            'UPDATE bank_accounts SET balance = $1::jsonb, updated_at = NOW() WHERE id = $2',
            {serializeJson(balanceJson), accountId}
        )
    end)
    return success
end

function BankingDatabase.getNextAccountSequence(bankCode)
    local result = db():queryOne(
        'SELECT account_number FROM bank_accounts ba JOIN banks b ON ba.bank_id = b.id WHERE b.code = $1 ORDER BY ba.id DESC LIMIT 1',
        {bankCode}
    )
    if not result or not result.account_number then return 1 end
    local sequence = result.account_number:match('%-%d+%-%d+%-(%d+)')
    return sequence and tonumber(sequence) + 1 or 1
end

function BankingDatabase.setBankFee(bankId, feeType, feeTypeValue, feeAmount, currencyId)
    local success = pcall(function()
        db():query(
            [[
                INSERT INTO bank_fees (bank_id, fee_type, fee_type_value, fee_amount, currency_id, is_active, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, true, NOW(), NOW())
                ON CONFLICT (bank_id, fee_type)
                DO UPDATE SET fee_type_value = $3, fee_amount = $4, currency_id = $5, updated_at = NOW()
            ]],
            {bankId, feeType, feeTypeValue, feeAmount, currencyId}
        )
    end)
    return success
end

function BankingDatabase.getBankFee(bankId, feeType)
    return db():queryOne(
        'SELECT * FROM bank_fees WHERE bank_id = $1 AND fee_type = $2 AND is_active = true',
        {bankId, feeType}
    )
end

function BankingDatabase.getBankFees(bankId)
    return db():queryAll('SELECT * FROM bank_fees WHERE bank_id = $1 AND is_active = true', {bankId})
end

function BankingDatabase.getCharacterCash(characterId, currencyId)
    local result = db():queryOne(
        'SELECT amount FROM character_cash WHERE character_id = $1 AND currency_id = $2',
        {characterId, currencyId}
    )
    return result and tonumber(result.amount) or 0.0
end

function BankingDatabase.setCharacterCash(characterId, currencyId, amount)
    if not amount or amount < 0 then return false, 'amount invalid' end
    return safeDB('setCharacterCash', function()
        db():query(
            [[
                INSERT INTO character_cash (character_id, currency_id, amount)
                VALUES ($1, $2, $3)
                ON CONFLICT (character_id, currency_id)
                DO UPDATE SET amount = $3
            ]],
            {characterId, currencyId, amount}
        )
    end)
end

function BankingDatabase.addCharacterCash(characterId, currencyId, amount)
    if not amount or amount < 0 then return false, 'amount invalid' end
    return safeDB('addCharacterCash', function()
        db():query(
            [[
                INSERT INTO character_cash (character_id, currency_id, amount)
                VALUES ($1, $2, $3)
                ON CONFLICT (character_id, currency_id)
                DO UPDATE SET amount = character_cash.amount + $3
            ]],
            {characterId, currencyId, amount}
        )
    end)
end

function BankingDatabase.atomicSubtractCharacterCash(characterId, currencyId, amount)
    if not amount or amount <= 0 then return false end
    local row = db():queryOne(
        [[
            UPDATE character_cash
            SET amount = amount - $3
            WHERE character_id = $1 AND currency_id = $2 AND amount >= $3
            RETURNING amount
        ]],
        {characterId, currencyId, amount}
    )
    return row ~= nil
end

function BankingDatabase.atomicAddAccountBalance(accountId, currencyId, delta)
    if not delta then return false end
    local key = tostring(currencyId)
    local row = db():queryOne(
        [[
            UPDATE bank_accounts
            SET balance = jsonb_set(
                    COALESCE(balance, '{}'::jsonb),
                    ARRAY[$2],
                    to_jsonb(COALESCE((balance->>$2)::numeric, 0) + $3)
                ),
                updated_at = NOW()
            WHERE id = $1
            RETURNING id
        ]],
        {accountId, key, delta}
    )
    return row ~= nil
end

function BankingDatabase.atomicSubtractAccountBalance(accountId, currencyId, amount)
    if not amount or amount <= 0 then return false end
    local key = tostring(currencyId)
    local row = db():queryOne(
        [[
            UPDATE bank_accounts
            SET balance = jsonb_set(
                    COALESCE(balance, '{}'::jsonb),
                    ARRAY[$2],
                    to_jsonb(COALESCE((balance->>$2)::numeric, 0) - $3)
                ),
                updated_at = NOW()
            WHERE id = $1 AND COALESCE((balance->>$2)::numeric, 0) >= $3
            RETURNING id
        ]],
        {accountId, key, amount}
    )
    return row ~= nil
end

function BankingDatabase.atomicDepositSameCurrency(characterId, accountId, currencyId, amount, fee)
    local key = tostring(currencyId)
    local totalDeduct = amount + (fee or 0)
    local row = db():queryOne(
        [[
            WITH s AS (
                UPDATE character_cash
                SET amount = amount - $4
                WHERE character_id = $1 AND currency_id = $2 AND amount >= $4
                RETURNING 1
            ),
            a AS (
                UPDATE bank_accounts
                SET balance = jsonb_set(
                        COALESCE(balance, '{}'::jsonb),
                        ARRAY[$3],
                        to_jsonb(COALESCE((balance->>$3)::numeric, 0) + $5)
                    ),
                    updated_at = NOW()
                WHERE id = $6 AND EXISTS (SELECT 1 FROM s)
                RETURNING 1
            )
            SELECT
                (SELECT COUNT(*) FROM s) > 0 AS cash_ok,
                (SELECT COUNT(*) FROM a) > 0 AS bal_ok
        ]],
        {characterId, currencyId, key, totalDeduct, amount, accountId}
    )
    if not row then return false, 'eroare DB' end
    if not row.cash_ok then return false, 'Fonduri insuficiente' end
    if not row.bal_ok then return false, 'Cont inexistent' end
    return true
end

function BankingDatabase.atomicWithdrawSameCurrency(characterId, accountId, currencyId, amount, fee)
    local key = tostring(currencyId)
    local totalDeduct = amount + (fee or 0)
    local row = db():queryOne(
        [[
            WITH a AS (
                UPDATE bank_accounts
                SET balance = jsonb_set(
                        COALESCE(balance, '{}'::jsonb),
                        ARRAY[$3],
                        to_jsonb(COALESCE((balance->>$3)::numeric, 0) - $5)
                    ),
                    updated_at = NOW()
                WHERE id = $4 AND COALESCE((balance->>$3)::numeric, 0) >= $5
                RETURNING 1
            ),
            c AS (
                INSERT INTO character_cash (character_id, currency_id, amount)
                SELECT $1, $2, $6 WHERE EXISTS (SELECT 1 FROM a)
                ON CONFLICT (character_id, currency_id)
                DO UPDATE SET amount = character_cash.amount + EXCLUDED.amount
                RETURNING 1
            )
            SELECT
                (SELECT COUNT(*) FROM a) > 0 AS bal_ok,
                (SELECT COUNT(*) FROM c) > 0 AS cash_ok
        ]],
        {characterId, currencyId, key, accountId, totalDeduct, amount}
    )
    if not row then return false, 'eroare DB' end
    if not row.bal_ok then return false, 'Fonduri insuficiente' end
    return true
end

function BankingDatabase.atomicExchangeInAccount(accountId, currencyFromId, currencyToId, fromAmount, toAmount)
    local keyFrom = tostring(currencyFromId)
    local keyTo = tostring(currencyToId)
    local row = db():queryOne(
        [[
            UPDATE bank_accounts
            SET balance = jsonb_set(
                    jsonb_set(
                        COALESCE(balance, '{}'::jsonb),
                        ARRAY[$2],
                        to_jsonb(COALESCE((balance->>$2)::numeric, 0) - $4)
                    ),
                    ARRAY[$3],
                    to_jsonb(COALESCE((balance->>$3)::numeric, 0) + $5)
                ),
                updated_at = NOW()
            WHERE id = $1 AND COALESCE((balance->>$2)::numeric, 0) >= $4
            RETURNING id
        ]],
        {accountId, keyFrom, keyTo, fromAmount, toAmount}
    )
    if not row then return false, 'Fonduri insuficiente sau cont inexistent' end
    return true
end

function BankingDatabase.atomicTransferSameCurrency(fromAccountId, toAccountId, currencyId, amount, fee)
    if fromAccountId == toAccountId then return false, 'Conturi identice' end
    local key = tostring(currencyId)
    local totalDeduct = amount + (fee or 0)
    local row = db():queryOne(
        [[
            WITH src AS (
                UPDATE bank_accounts
                SET balance = jsonb_set(
                        COALESCE(balance, '{}'::jsonb),
                        ARRAY[$3],
                        to_jsonb(COALESCE((balance->>$3)::numeric, 0) - $4)
                    ),
                    updated_at = NOW()
                WHERE id = $1 AND COALESCE((balance->>$3)::numeric, 0) >= $4
                RETURNING 1
            ),
            dst AS (
                UPDATE bank_accounts
                SET balance = jsonb_set(
                        COALESCE(balance, '{}'::jsonb),
                        ARRAY[$3],
                        to_jsonb(COALESCE((balance->>$3)::numeric, 0) + $5)
                    ),
                    updated_at = NOW()
                WHERE id = $2 AND EXISTS (SELECT 1 FROM src)
                RETURNING 1
            )
            SELECT
                (SELECT COUNT(*) FROM src) > 0 AS src_ok,
                (SELECT COUNT(*) FROM dst) > 0 AS dst_ok
        ]],
        {fromAccountId, toAccountId, key, totalDeduct, amount}
    )
    if not row then return false, 'eroare DB' end
    if not row.src_ok then return false, 'Fonduri insuficiente' end
    if not row.dst_ok then return false, 'Cont destinatie inexistent' end
    return true
end

function BankingDatabase.getCharacterAllCash(characterId)
    local results = db():queryAll(
        'SELECT cc.*, c.code as currency_code, c.symbol as currency_symbol FROM character_cash cc JOIN currencies c ON cc.currency_id = c.id WHERE cc.character_id = $1',
        {characterId}
    )
    local cash = {}
    for _, row in ipairs(results) do
        cash[row.currency_id] = {
            amount = tonumber(row.amount) or 0.0,
            currency_code = row.currency_code,
            currency_symbol = row.currency_symbol
        }
    end
    return cash
end

function BankingDatabase.createLoan(characterId, bankId, loanType, principalAmount, interestRate, remainingAmount, monthlyPayment, totalPayments, nextPaymentDate, currencyId)
    local result = db():query(
        [[
            INSERT INTO loans (character_id, bank_id, loan_type, principal_amount, interest_rate, remaining_amount, monthly_payment, total_payments, payments_made, next_payment_date, status, currency_id, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0, $9, 'active', $10, NOW(), NOW())
            RETURNING *
        ]],
        {characterId, bankId, loanType, principalAmount, interestRate, remainingAmount, monthlyPayment, totalPayments, nextPaymentDate, currencyId}
    )
    return result and result.rows and result.rows[1] or nil
end

function BankingDatabase.getLoanById(loanId)
    return db():queryOne('SELECT * FROM loans WHERE id = $1', {loanId})
end

function BankingDatabase.getCharacterActiveLoans(characterId)
    return db():queryAll(
        "SELECT l.*, b.name as bank_name FROM loans l JOIN banks b ON l.bank_id = b.id WHERE l.character_id = $1 AND l.status = 'active' ORDER BY l.next_payment_date",
        {characterId}
    )
end

function BankingDatabase.updateLoan(loanId, updates)
    local updateParts = {}
    local params = {}
    local paramCount = 0

    if updates.remaining_amount then
        paramCount = paramCount + 1
        table.insert(updateParts, 'remaining_amount = $' .. paramCount)
        table.insert(params, updates.remaining_amount)
    end
    if updates.payments_made then
        paramCount = paramCount + 1
        table.insert(updateParts, 'payments_made = $' .. paramCount)
        table.insert(params, updates.payments_made)
    end
    if updates.next_payment_date then
        paramCount = paramCount + 1
        table.insert(updateParts, 'next_payment_date = $' .. paramCount)
        table.insert(params, updates.next_payment_date)
    end
    if updates.status then
        paramCount = paramCount + 1
        table.insert(updateParts, 'status = $' .. paramCount)
        table.insert(params, updates.status)
    end

    if #updateParts == 0 then return false end

    paramCount = paramCount + 1
    table.insert(updateParts, 'updated_at = NOW()')
    table.insert(params, loanId)

    local query = 'UPDATE loans SET ' .. table.concat(updateParts, ', ') .. ' WHERE id = $' .. paramCount
    local success = pcall(function() db():query(query, params) end)
    return success
end

function BankingDatabase.addLoanPayment(loanId, amountPaid, isOnTime)
    local success = pcall(function()
        db():query(
            'INSERT INTO loan_payments (loan_id, amount_paid, payment_date, is_on_time) VALUES ($1, $2, NOW(), $3)',
            {loanId, amountPaid, isOnTime}
        )
    end)
    return success
end

function BankingDatabase.createTransaction(characterId, transactionType, fromAccountId, toAccountId, amount, currencyId, feeAmount, feeCurrencyId, description, metadata)
    local result = db():query(
        [[
            INSERT INTO transactions (character_id, transaction_type, from_account_id, to_account_id, amount, currency_id, fee_amount, fee_currency_id, description, metadata, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, NOW())
            RETURNING *
        ]],
        {characterId, transactionType, fromAccountId, toAccountId, amount, currencyId, feeAmount or 0.0, feeCurrencyId, description, metadata and serializeJson(metadata) or nil}
    )
    return result and result.rows and result.rows[1] or nil
end

function BankingDatabase.getCharacterTransactions(characterId, limit)
    limit = math.max(1, math.min(tonumber(limit) or 50, 1000))
    return db():queryAll(
        'SELECT * FROM transactions WHERE character_id = $1 ORDER BY created_at DESC LIMIT $2',
        {characterId, limit}
    )
end

function BankingDatabase.saveEconomyMetric(metricType, currencyId, value)
    local success = pcall(function()
        db():query(
            'INSERT INTO economy_metrics (metric_type, currency_id, value, calculated_at) VALUES ($1, $2, $3, NOW())',
            {metricType, currencyId, value}
        )
    end)
    return success
end

function BankingDatabase.getLatestEconomyMetric(metricType, currencyId)
    return db():queryOne(
        'SELECT * FROM economy_metrics WHERE metric_type = $1 AND currency_id = $2 ORDER BY calculated_at DESC LIMIT 1',
        {metricType, currencyId}
    )
end

function BankingDatabase.saveInflationHistory(currencyId, inflationRate, totalMoneySupply)
    local success = pcall(function()
        db():query(
            'INSERT INTO inflation_history (currency_id, inflation_rate, total_money_supply, calculated_at) VALUES ($1, $2, $3, NOW())',
            {currencyId, inflationRate, totalMoneySupply}
        )
    end)
    return success
end

function BankingDatabase.getLatestInflation(currencyId)
    return db():queryOne(
        'SELECT * FROM inflation_history WHERE currency_id = $1 ORDER BY calculated_at DESC LIMIT 1',
        {currencyId}
    )
end

function BankingDatabase.calculateTotalMoneySupply(currencyId)
    local key = tostring(currencyId)
    local row = db():queryOne(
        [[
            SELECT
                COALESCE((SELECT SUM(amount) FROM character_cash WHERE currency_id = $1), 0) AS cash_total,
                COALESCE((SELECT SUM((balance->>$2)::numeric) FROM bank_accounts WHERE balance ? $2), 0) AS account_total
        ]],
        {currencyId, key}
    )
    if not row then return 0.0 end
    return (tonumber(row.cash_total) or 0.0) + (tonumber(row.account_total) or 0.0)
end

function BankingDatabase.getOrgByCode(code)
    return db():queryOne('SELECT * FROM organizations WHERE code = $1 AND is_active = TRUE', {code})
end

function BankingDatabase.getOrgById(orgId)
    return db():queryOne('SELECT * FROM organizations WHERE id = $1', {orgId})
end

function BankingDatabase.getOrgAccountByOrg(orgId)
    return db():queryOne('SELECT * FROM org_bank_accounts WHERE org_id = $1 LIMIT 1', {orgId})
end

function BankingDatabase.getOrgAccountByNumber(accountNumber)
    return db():queryOne('SELECT * FROM org_bank_accounts WHERE account_number = $1', {accountNumber})
end

function BankingDatabase.createOrgAccount(orgId, bankId, accountType, accountNumber)
    local result = db():query(
        [[
            INSERT INTO org_bank_accounts (org_id, bank_id, account_type, account_number, balance, created_at, updated_at)
            VALUES ($1, $2, $3, $4, '{}'::jsonb, NOW(), NOW())
            ON CONFLICT (account_number) DO NOTHING
            RETURNING *
        ]],
        {orgId, bankId, accountType or 'current', accountNumber}
    )
    if result and result.rows and result.rows[1] then return result.rows[1] end
    return db():queryOne('SELECT * FROM org_bank_accounts WHERE org_id = $1 LIMIT 1', {orgId})
end

function BankingDatabase.updateOrgAccountBalance(accountId, balanceJson)
    local success = pcall(function()
        db():query(
            'UPDATE org_bank_accounts SET balance = $1::jsonb, updated_at = NOW() WHERE id = $2',
            {serializeJson(balanceJson), accountId}
        )
    end)
    return success
end

function BankingDatabase.createOrgTransaction(orgId, accountId, characterId, txType, amount, currencyId, balanceAfter, description)
    local success = pcall(function()
        db():query(
            [[INSERT INTO org_transactions
                (org_id, account_id, character_id, type, amount, currency_id, balance_after, description, created_at)
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())]],
            {orgId, accountId, characterId, txType, amount, currencyId, balanceAfter, description}
        )
    end)
    return success
end

function BankingDatabase.getOrgTransactions(orgId, limit)
    limit = math.max(1, math.min(tonumber(limit) or 20, 200))
    return db():queryAll(
        'SELECT * FROM org_transactions WHERE org_id = $1 ORDER BY created_at DESC LIMIT $2',
        {orgId, limit}
    )
end

function BankingDatabase.getOrgMember(orgId, characterId)
    return db():queryOne(
        'SELECT * FROM org_account_members WHERE org_id = $1 AND character_id = $2',
        {orgId, characterId}
    )
end

function BankingDatabase.getNextOrgAccountSequence(bankCode)
    local result = db():queryOne(
        [[SELECT oba.account_number FROM org_bank_accounts oba
          JOIN banks b ON oba.bank_id = b.id
          WHERE b.code = $1 ORDER BY oba.id DESC LIMIT 1]],
        {bankCode}
    )
    if not result or not result.account_number then return 1 end
    local sequence = result.account_number:match('%-%d+%-%d+%-(%d+)')
    return sequence and tonumber(sequence) + 1 or 1
end

return BankingDatabase
