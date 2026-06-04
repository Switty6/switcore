version '1.0.0'
description 'Sistem de banking/economie pentru SwitCore. Suport pentru conturi bancare multiple, valute, credite și inflație automată.'
author 'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'proximity',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/banking_database.lua',
    'server/banking_helpers.lua',
    'server/currency_manager.lua',
    'server/fee_manager.lua',
    'server/banking_manager.lua',
    'server/loan_manager.lua',
    'server/inflation_manager.lua',
    'server/org_manager.lua',
    'server/exports.lua',
    'server/callbacks.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/atm/style.css',
    'ui/atm/script.js',
    'ui/bank/style.css',
    'ui/bank/script.js'
}

exports {
    'createCurrency',
    'getCurrencyByCode',
    'getCurrencyById',
    'getActiveCurrencies',
    'setExchangeRate',
    'getExchangeRate',
    'exchangeCurrency',
    
    'getBankByCode',
    'getBankById',
    'getActiveBanks',
    
    'createAccount',
    'getAccountByNumber',
    'getAccountById',
    'getCharacterAccounts',
    'getAccountBalance',

    'deposit',
    'withdraw',
    'transfer',
    'exchangeCurrency',
    
    'getCharacterCash',
    'setCharacterCash',
    'addCharacterCash',
    'getCharacterAllCash',

    'setBankFee',
    'getBankFee',
    'getBankFees',
    'calculateFee',
    
    'createLoan',
    'getLoanById',
    'getCharacterActiveLoans',
    'makeLoanPayment',
    'getCharacterTotalDebt',

    'calculateInflation',
    'getInflationRate',
    'getInflationHistory',
    'getTotalMoneySupply',
    
    'getCharacterTransactions',
    'createTransaction',

    'getOrg',
    'getOrgAccountBalance',
    'orgDeposit',
    'orgWithdraw',
    'orgSystemDebit',
    'orgSystemCredit',
    'getOrgTransactions',
    'isOrgMember',
    'createOrgAccount',
    'ensureOrgAccount'
}

lua54 'yes'
