exports('AddIncome', function(amount, currencyCode, description, category, characterId)
    return GovManager.addIncome(amount, currencyCode, description, category, characterId)
end)

exports('AddExpense', function(amount, currencyCode, description, category, characterId)
    return GovManager.addExpense(amount, currencyCode, description, category, characterId)
end)

exports('GetActiveLaws', function()
    return GovDB.getLaws(true) or {}
end)

exports('GetTreasuryBalance', function()
    return GovManager.getTreasuryBalance()
end)

exports('IsGovMember', function(source)
    return exports.core:hasPermission(source, 'government.access')
        or exports.core:hasPermission(source, 'government.all')
        or exports.core:hasPermission(source, 'admin.all')
end)
