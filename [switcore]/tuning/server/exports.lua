
exports('GetTuningShops', function()
    return TuningDatabase.getActiveShops()
end)

exports('GetTuningPrices', function()
    return TuningManager.getPriceTable()
end)

exports('GetVehicleMods', function(vehicleId)
    return TuningManager.getVehicleMods(vehicleId)
end)

exports('CalculateUpgradeCost', function(vehicleId, category, targetTier)
    return TuningManager.calculateUpgradeCost(vehicleId, category, targetTier)
end)

-- characterId ignorat: source rezolvă personajul activ intern (semnătură păstrată pentru compatibilitate cu apelanți vechi)
exports('ApplyMod', function(source, _characterId, vehicleId, category, targetTier, paymentMethod)
    return TuningManager.applyMod(source, vehicleId, category, targetTier, paymentMethod, nil)
end)

exports('ResetMods', function(source, vehicleId, paymentMethod)
    return TuningManager.resetMods(source, vehicleId, paymentMethod, nil)
end)
