
OrgManager = {}

local function getOrgBalance(account, currencyId)
    if not account then return 0.0 end
    local balance = BankingHelpers.parseBalance(account.balance)
    return tonumber(balance[tostring(currencyId)]) or 0.0
end

local function setOrgBalance(account, currencyId, amount)
    local balance = BankingHelpers.parseBalance(account.balance)
    balance[tostring(currencyId)] = amount
    return BankingDatabase.updateOrgAccountBalance(account.id, balance)
end

local function generateOrgAccountNumber(bankCode, orgId, sequence)
    local part1 = string.format('%04d', orgId % 10000)
    local part2 = string.format('%04d', sequence % 10000)
    return string.format('ORG-%s-%s-%s', bankCode, part1, part2)
end

function OrgManager.getOrg(code)
    return BankingDatabase.getOrgByCode(code)
end

function OrgManager.getOrgById(orgId)
    return BankingDatabase.getOrgById(orgId)
end

function OrgManager.getOrgAccount(orgId)
    return BankingDatabase.getOrgAccountByOrg(orgId)
end

-- Param este orgId (nu accountId) - export pastreaza numele pentru compatibilitate
function OrgManager.getOrgAccountBalance(accountId, currencyId)
    local account = BankingDatabase.getOrgAccountByOrg(accountId)
    if not account then return 0.0 end
    return getOrgBalance(account, currencyId)
end

function OrgManager.getOrgBalanceByCode(orgCode, currencyId)
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return 0.0 end
    local account = BankingDatabase.getOrgAccountByOrg(org.id)
    if not account then return 0.0 end
    return getOrgBalance(account, currencyId)
end

function OrgManager.createOrgAccount(orgCode, bankCode)
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return false, 'Organizatie negasita: ' .. orgCode, nil end

    local bank = BankingDatabase.getBankByCode(bankCode)
    if not bank then return false, 'Banca negasita: ' .. bankCode, nil end

    -- Double-check dupa fetch org/bank, pentru race conditions
    local existing = BankingDatabase.getOrgAccountByOrg(org.id)
    if existing then return true, nil, existing end

    local seq    = BankingDatabase.getNextOrgAccountSequence(bankCode)
    local accNum = generateOrgAccountNumber(bankCode, org.id, seq)
    local account = BankingDatabase.createOrgAccount(org.id, bank.id, 'current', accNum)

    if not account then return false, 'Eroare la creare cont organizatie', nil end
    return true, nil, account
end

function OrgManager.ensureOrgAccount(orgCode, bankCode)
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then
        print('[BANKING] ensureOrgAccount: organizatie negasita: ' .. orgCode)
        return nil
    end
    local existing = BankingDatabase.getOrgAccountByOrg(org.id)
    if existing then return existing end

    local ok, err, account = OrgManager.createOrgAccount(orgCode, bankCode)
    if ok then
        print(string.format('[BANKING] Cont organizatie creat: %s (%s)', orgCode, account.account_number))
        return account
    else
        print('[BANKING] Eroare creare cont org ' .. orgCode .. ': ' .. (err or ''))
        return nil
    end
end

-- orgSystemCredit/Debit: tranzactii server-to-server fara caracter (ex: cautiune, achizitie vehicul)
function OrgManager.orgSystemCredit(orgCode, amount, currencyId, description)
    if not amount or amount <= 0 then return false, 'Suma invalida' end
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return false, 'Organizatie negasita: ' .. orgCode end
    local account = BankingDatabase.getOrgAccountByOrg(org.id)
    if not account then return false, 'Cont org negasit pentru: ' .. orgCode end

    local current = getOrgBalance(account, currencyId)
    local newBal  = current + amount

    local ok = setOrgBalance(account, currencyId, newBal)
    if not ok then return false, 'Eroare actualizare sold' end

    BankingDatabase.createOrgTransaction(org.id, account.id, nil, 'system', amount, currencyId, newBal, description or 'Credit sistem')
    return true, nil
end

function OrgManager.orgSystemDebit(orgCode, amount, currencyId, description)
    if not amount or amount <= 0 then return false, 'Suma invalida' end
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return false, 'Organizatie negasita: ' .. orgCode end
    local account = BankingDatabase.getOrgAccountByOrg(org.id)
    if not account then return false, 'Cont org negasit pentru: ' .. orgCode end

    local current = getOrgBalance(account, currencyId)
    if current < amount then return false, 'Fonduri insuficiente' end

    local newBal = current - amount
    local ok = setOrgBalance(account, currencyId, newBal)
    if not ok then return false, 'Eroare actualizare sold' end

    BankingDatabase.createOrgTransaction(org.id, account.id, nil, 'system', -amount, currencyId, newBal, description or 'Debit sistem')
    return true, nil
end

function OrgManager.orgDeposit(characterId, orgCode, amount, currencyId, description)
    if not amount or amount <= 0 then return false, 'Suma invalida' end

    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return false, 'Organizatie negasita' end
    local account = BankingDatabase.getOrgAccountByOrg(org.id)
    if not account then return false, 'Cont org negasit' end

    local cash = BankingDatabase.getCharacterCash(characterId, currencyId)
    if cash < amount then return false, 'Cash insuficient' end

    BankingDatabase.addCharacterCash(characterId, currencyId, -amount)

    local current = getOrgBalance(account, currencyId)
    local newBal  = current + amount
    setOrgBalance(account, currencyId, newBal)
    BankingDatabase.createOrgTransaction(org.id, account.id, characterId, 'deposit', amount, currencyId, newBal, description or 'Depunere')
    return true, nil
end

function OrgManager.orgWithdraw(characterId, orgCode, amount, currencyId, description)
    if not amount or amount <= 0 then return false, 'Suma invalida' end

    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return false, 'Organizatie negasita' end
    local account = BankingDatabase.getOrgAccountByOrg(org.id)
    if not account then return false, 'Cont org negasit' end

    local member = BankingDatabase.getOrgMember(org.id, characterId)
    if not member or not member.can_withdraw then
        return false, 'Acces refuzat'
    end

    local current = getOrgBalance(account, currencyId)
    if current < amount then return false, 'Fonduri insuficiente' end

    local newBal = current - amount
    setOrgBalance(account, currencyId, newBal)
    BankingDatabase.addCharacterCash(characterId, currencyId, amount)
    BankingDatabase.createOrgTransaction(org.id, account.id, characterId, 'withdrawal', -amount, currencyId, newBal, description or 'Retragere')
    return true, nil
end

function OrgManager.getOrgTransactions(orgCode, limit)
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return {} end
    return BankingDatabase.getOrgTransactions(org.id, limit or 20)
end

function OrgManager.isOrgMember(characterId, orgCode, permission)
    local org = BankingDatabase.getOrgByCode(orgCode)
    if not org then return false end
    local member = BankingDatabase.getOrgMember(org.id, characterId)
    if not member then return false end
    if permission == 'view'     then return member.can_view     == true end
    if permission == 'deposit'  then return member.can_deposit  == true end
    if permission == 'withdraw' then return member.can_withdraw == true end
    if permission == 'manage'   then return member.can_manage   == true end
    return false
end
