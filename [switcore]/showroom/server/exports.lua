
exports('getActiveDealerships', function()
    return ShowroomDatabase.getActiveDealerships()
end)

exports('getDealershipCatalog', function(dealershipCode)
    return ShowroomManager.getDealershipCatalog(dealershipCode)
end)

exports('purchaseVehicle', function(source, characterId, catalogId, paymentMethod)
    return ShowroomManager.purchaseVehicle(source, characterId, catalogId, paymentMethod)
end)

exports('startTestDrive', function(source, characterId, catalogId)
    return ShowroomManager.startTestDrive(source, characterId, catalogId)
end)

exports('endTestDrive', function(source, characterId)
    return ShowroomManager.endTestDrive(source, characterId)
end)

exports('getActiveTestDrive', function(characterId)
    return ShowroomDatabase.getActiveTestDrive(characterId)
end)
