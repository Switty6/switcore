local function SeedGarages()
    local locations = exports.settings:GetSettingList('garages.locations', {})
    for _, loc in ipairs(locations) do
        local result = GaragesDatabase.upsertGarage(
            loc.code, loc.name, loc.type, loc.coords, loc.spawnPoint
        )
        if result then
            print(string.format('[GARAGES] Garaj upsert: %s (%s)', loc.code, loc.name))
        end
    end
end

local function InitializeGaragesSystem()
    SeedGarages()
    print('[GARAGES] Sistem garaje inițializat')
end

CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end
    InitializeGaragesSystem()
end)

RegisterNetEvent('garages:server:getLocationConfig', function()
    local src = source
    local locations = exports.settings:GetSettingList('garages.locations', {})
    local distance  = exports.settings:GetSettingNumber('garages.interaction_distance', 2.5)
    TriggerClientEvent('garages:client:locationConfig', src, {
        locations = locations,
        distance  = distance,
    })
end)
