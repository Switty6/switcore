
exports('createCurrency', function(code, name, symbol)
    return CurrencyManager.createCurrency(code, name, symbol)
end)

exports('getCurrencyByCode', function(code)
    return CurrencyManager.getCurrencyByCode(code)
end)

exports('getCurrencyById', function(currencyId)
    return CurrencyManager.getCurrencyById(currencyId)
end)

exports('getActiveCurrencies', function()
    return CurrencyManager.getActiveCurrencies()
end)

exports('setExchangeRate', function(currencyFromId, currencyToId, rate)
    return CurrencyManager.setExchangeRate(currencyFromId, currencyToId, rate)
end)

exports('getExchangeRate', function(currencyFromId, currencyToId)
    return CurrencyManager.getExchangeRate(currencyFromId, currencyToId)
end)

exports('exchangeCurrency', function(amount, currencyFromId, currencyToId)
    return CurrencyManager.exchangeCurrency(amount, currencyFromId, currencyToId)
end)

exports('getBankByCode', function(code)
    return BankingDatabase.getBankByCode(code)
end)

exports('getBankById', function(bankId)
    return BankingDatabase.getBankById(bankId)
end)

exports('getActiveBanks', function()
    return BankingDatabase.getActiveBanks()
end)

exports('createAccount', function(characterId, bankId, accountType, interestRate, depositTermDays)
    local ok, err, account = BankingManager.createAccount(characterId, bankId, accountType, interestRate, depositTermDays)
    if ok then return account else return nil, err end
end)

exports('getAccountByNumber', function(accountNumber)
    return BankingManager.getAccountByNumber(accountNumber)
end)

exports('getAccountById', function(accountId)
    return BankingManager.getAccountById(accountId)
end)

exports('getCharacterAccounts', function(characterId)
    return BankingManager.getCharacterAccounts(characterId)
end)

exports('getAccountBalance', function(accountId, currencyId)
    return BankingManager.getAccountBalance(accountId, currencyId)
end)

exports('removeAccountBalance', function(accountId, currencyId, amount)
    return BankingManager.removeAccountBalance(accountId, currencyId, amount)
end)

exports('addAccountBalance', function(accountId, currencyId, amount)
    return BankingDatabase.atomicAddAccountBalance(accountId, currencyId, amount)
end)

exports('deposit', function(characterId, accountId, amount, currencyId)
    return BankingManager.deposit(characterId, accountId, amount, currencyId)
end)

exports('withdraw', function(characterId, accountId, amount, currencyId)
    return BankingManager.withdraw(characterId, accountId, amount, currencyId)
end)

exports('transfer', function(characterId, fromAccountId, toAccountId, amount, currencyId)
    return BankingManager.transfer(characterId, fromAccountId, toAccountId, amount, currencyId)
end)

exports('exchangeCurrency', function(characterId, accountId, amount, currencyFromId, currencyToId)
    return BankingManager.exchangeCurrency(characterId, accountId, amount, currencyFromId, currencyToId)
end)

exports('getCharacterCash', function(characterId, currencyId)
    return BankingDatabase.getCharacterCash(characterId, currencyId)
end)

exports('setCharacterCash', function(characterId, currencyId, amount)
    return BankingDatabase.setCharacterCash(characterId, currencyId, amount)
end)

exports('addCharacterCash', function(characterId, currencyId, amount)
    return BankingDatabase.addCharacterCash(characterId, currencyId, amount)
end)

exports('tryDeductCharacterCash', function(characterId, currencyId, amount)
    return BankingDatabase.atomicSubtractCharacterCash(characterId, currencyId, amount)
end)

exports('getCharacterAllCash', function(characterId)
    return BankingDatabase.getCharacterAllCash(characterId)
end)

exports('setBankFee', function(bankId, feeType, feeTypeValue, feeAmount, currencyId)
    return FeeManager.setBankFee(bankId, feeType, feeTypeValue, feeAmount, currencyId)
end)

exports('getBankFee', function(bankId, feeType)
    return FeeManager.getBankFee(bankId, feeType)
end)

exports('getBankFees', function(bankId)
    return FeeManager.getBankFees(bankId)
end)

exports('calculateFee', function(bankId, feeType, amount, currencyId)
    return FeeManager.calculateFee(bankId, feeType, amount, currencyId)
end)

exports('createLoan', function(characterId, bankId, loanType, principalAmount, termMonths, currencyId)
    local ok, err, loan = LoanManager.createLoan(characterId, bankId, loanType, principalAmount, termMonths, currencyId)
    if ok then return loan else return nil, err end
end)

exports('getLoanById', function(loanId)
    return LoanManager.getLoanById(loanId)
end)

exports('getCharacterActiveLoans', function(characterId)
    return LoanManager.getCharacterActiveLoans(characterId)
end)

exports('makeLoanPayment', function(characterId, loanId, amount)
    return LoanManager.makeLoanPayment(characterId, loanId, amount)
end)

exports('getCharacterTotalDebt', function(characterId)
    return LoanManager.getCharacterTotalDebt(characterId)
end)

exports('calculateInflation', function(currencyId)
    return InflationManager.calculateInflation(currencyId)
end)

exports('getInflationRate', function(currencyId)
    return InflationManager.getInflationRate(currencyId)
end)

exports('getInflationHistory', function(currencyId, limit)
    return InflationManager.getInflationHistory(currencyId, limit)
end)

exports('getTotalMoneySupply', function(currencyId)
    return InflationManager.getTotalMoneySupply(currencyId)
end)

exports('getCharacterTransactions', function(characterId, limit)
    return BankingDatabase.getCharacterTransactions(characterId, limit)
end)

exports('createTransaction', function(characterId, transactionType, fromAccountId, toAccountId, amount, currencyId, feeAmount, feeCurrencyId, description, metadata)
    return BankingDatabase.createTransaction(characterId, transactionType, fromAccountId, toAccountId, amount, currencyId, feeAmount, feeCurrencyId, description, metadata)
end)

exports('getOrg', function(code)
    return OrgManager.getOrg(code)
end)

exports('getOrgAccountBalance', function(orgCode, currencyId)
    return OrgManager.getOrgBalanceByCode(orgCode, currencyId)
end)

exports('orgDeposit', function(characterId, orgCode, amount, currencyId, description)
    return OrgManager.orgDeposit(characterId, orgCode, amount, currencyId, description)
end)

exports('orgWithdraw', function(characterId, orgCode, amount, currencyId, description)
    return OrgManager.orgWithdraw(characterId, orgCode, amount, currencyId, description)
end)

exports('orgSystemDebit', function(orgCode, amount, currencyId, description)
    return OrgManager.orgSystemDebit(orgCode, amount, currencyId, description)
end)

exports('orgSystemCredit', function(orgCode, amount, currencyId, description)
    return OrgManager.orgSystemCredit(orgCode, amount, currencyId, description)
end)

exports('getOrgTransactions', function(orgCode, limit)
    return OrgManager.getOrgTransactions(orgCode, limit)
end)

exports('isOrgMember', function(characterId, orgCode, permission)
    return OrgManager.isOrgMember(characterId, orgCode, permission)
end)

exports('createOrgAccount', function(orgCode, bankCode)
    return OrgManager.createOrgAccount(orgCode, bankCode)
end)

exports('ensureOrgAccount', function(orgCode, bankCode)
    return OrgManager.ensureOrgAccount(orgCode, bankCode)
end)

