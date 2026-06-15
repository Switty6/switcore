local isUIOpen = false
local currentMode = nil
local currentBankCode = nil

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

local function OpenNUI(mode, bankCode)
    if isUIOpen then return end
    isUIOpen = true
    currentMode = mode
    currentBankCode = bankCode

    SetNuiFocus(true, true)
    pushI18n()
    SendNUIMessage({
        action = 'open',
        mode = mode,
        bankCode = bankCode or 'MAZE'
    })

    TriggerServerEvent('banking:server:getAccounts')
    TriggerServerEvent('banking:server:getCash')

    if mode == 'bank' then
        TriggerServerEvent('banking:server:getBanks')
        TriggerServerEvent('banking:server:getCurrencies')
        TriggerServerEvent('banking:server:getTransactions', 20)
        TriggerServerEvent('banking:server:getLoans')
    end
end

local function CloseNUI()
    if not isUIOpen then return end
    isUIOpen = false
    currentMode = nil
    currentBankCode = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

CreateThread(function()
    Wait(1500) -- Asteapta initializarea proximity + settings inainte de a inregistra interactiuni
    TriggerServerEvent('banking:server:getProximityConfig')
end)

RegisterNetEvent('banking:client:proximityConfig', function(config)
    local atmDistance  = config.atmDistance  or 1.5
    local bankDistance = config.bankDistance or 2.0

    for _, model in ipairs(config.atmModels or {}) do
        exports.proximity:AddStaticModelInteraction(
            model,
            Sw.T('banking.proximity.atm_label'),
            'banking_atm',
            {},
            atmDistance
        )
    end

    for _, location in ipairs(config.bankLocations or {}) do
        local coords = vector3(location.x, location.y, location.z)
        exports.proximity:AddStaticInteraction(
            coords,
            location.label or Sw.T('banking.proximity.bank_label'),
            'banking_bank',
            { bankCode = location.bankCode }
        )
    end

end)

RegisterNetEvent('switcore:proximity:interact', function(interaction)
    if not interaction or not interaction.type then return end

    if interaction.type == 'banking_atm' then
        OpenNUI('atm', nil)
    elseif interaction.type == 'banking_bank' then
        local bankCode = interaction.data and interaction.data.bankCode or 'MAZE'
        OpenNUI('bank', bankCode)
    end
end)

RegisterNetEvent('banking:client:accountsData', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'accountsData', data = data })
    end
end)

RegisterNetEvent('banking:client:cashData', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'cashData', data = data })
    end
end)

RegisterNetEvent('banking:client:depositResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'depositResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getAccounts')
            TriggerServerEvent('banking:server:getCash')
        end
    end
end)

RegisterNetEvent('banking:client:withdrawResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'withdrawResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getAccounts')
            TriggerServerEvent('banking:server:getCash')
        end
    end
end)

RegisterNetEvent('banking:client:transferResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'transferResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getAccounts')
            TriggerServerEvent('banking:server:getCash')
            TriggerServerEvent('banking:server:getTransactions', 20)
        end
    end
end)

RegisterNetEvent('banking:client:transactionsData', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'transactionsData', data = data })
    end
end)

RegisterNetEvent('banking:client:banksData', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'banksData', data = data })
    end
end)

RegisterNetEvent('banking:client:currenciesData', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'currenciesData', data = data })
    end
end)

RegisterNetEvent('banking:client:createAccountResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'createAccountResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getAccounts')
        end
    end
end)

RegisterNetEvent('banking:client:loansData', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'loansData', data = data })
    end
end)

RegisterNetEvent('banking:client:createLoanResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'createLoanResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getLoans')
            TriggerServerEvent('banking:server:getAccounts')
        end
    end
end)

RegisterNetEvent('banking:client:payLoanResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'payLoanResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getLoans')
            TriggerServerEvent('banking:server:getAccounts')
            TriggerServerEvent('banking:server:getCash')
        end
    end
end)

RegisterNetEvent('banking:client:exchangeResult', function(data)
    if isUIOpen then
        SendNUIMessage({ action = 'exchangeResult', data = data })
        if data.success then
            TriggerServerEvent('banking:server:getAccounts')
        end
    end
end)

RegisterNUICallback('close', function(data, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('banking:server:deposit', data.accountId, data.amount)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('banking:server:withdraw', data.accountId, data.amount)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('banking:server:transfer', data.fromAccountId, data.toAccountNumber, data.amount)
    cb('ok')
end)

RegisterNUICallback('getAccounts', function(data, cb)
    TriggerServerEvent('banking:server:getAccounts')
    cb('ok')
end)

RegisterNUICallback('getCash', function(data, cb)
    TriggerServerEvent('banking:server:getCash')
    cb('ok')
end)

RegisterNUICallback('getTransactions', function(data, cb)
    TriggerServerEvent('banking:server:getTransactions', data.limit or 50)
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    TriggerServerEvent('banking:server:createAccount', data.bankCode, data.accountType)
    cb('ok')
end)

RegisterNUICallback('getLoans', function(data, cb)
    TriggerServerEvent('banking:server:getLoans')
    cb('ok')
end)

RegisterNUICallback('createLoan', function(data, cb)
    TriggerServerEvent('banking:server:createLoan', data.bankCode, data.loanType, data.amount, data.termMonths)
    cb('ok')
end)

RegisterNUICallback('payLoan', function(data, cb)
    TriggerServerEvent('banking:server:payLoan', data.loanId, data.amount)
    cb('ok')
end)

RegisterNUICallback('exchangeCurrency', function(data, cb)
    TriggerServerEvent('banking:server:exchangeCurrency', data.accountId, data.amount, data.currencyFromId, data.currencyToId)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isUIOpen then
            CloseNUI()
        end
    end
end)

