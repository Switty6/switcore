
local activeVehicle = nil
local garageProxId  = nil

local KM_TO_MILES = 0.621371

function RegisterGarageZone()
    if garageProxId then
        exports.proximity:RemoveInteraction(garageProxId)
        garageProxId = nil
    end

    if not myJob or myJob.name ~= 'police' or not myJob.isOnDuty then return end
    if not PoliceConfig.garageCoords then return end

    garageProxId = exports.proximity:AddInteraction(
        PoliceConfig.garageCoords,
        'Garaj Politie',
        'police_garage',
        {},
        function() TriggerServerEvent('police:server:openGarage') end,
        nil, nil, nil
    )
end

local _original = RegisterPoliceZones
RegisterPoliceZones = function()
    _original()
    RegisterGarageZone()
end

RegisterNetEvent('police:client:openGarage', function(data)
    SendNUIMessage({
        action      = 'openGarage',
        fleet       = data.fleet or {},
        currentId   = data.currentId,
        mileageUnit = data.mileageUnit or PoliceConfig.mileageUnit or 'km'
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('closeGarage', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('checkoutVehicle', function(data, cb)
    TriggerServerEvent('police:server:checkoutVehicle', data.vehicleId)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('returnVehicle', function(data, cb)
    if not activeVehicle then cb('ok'); return end
    ReturnActiveVehicle()
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('police:client:spawnFleetVehicle', function(data)
    local model = GetHashKey(data.model)

    RequestModel(model)
    local waited = 0
    while not HasModelLoaded(model) and waited < 100 do
        Wait(100)
        waited = waited + 1
    end

    if not HasModelLoaded(model) then
        return
    end

    local spawn = data.spawnCoords or { x = 0, y = 0, z = 0, heading = 0 }

    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.heading or 0.0, false, false)
    SetVehicleNumberPlateText(veh, data.plate)
    SetEntityAsMissionEntity(veh, true, true)

    SetVehicleBodyHealth(veh, data.bodyHealth or 1000.0)
    SetVehicleEngineHealth(veh, data.engineHealth or 1000.0)

    SetVehicleFuelLevel(veh, data.fuel or 100.0)

    if data.modifications then
        local mods = type(data.modifications) == 'string'
            and json.decode(data.modifications) or data.modifications
        if mods and type(mods) == 'table' then
            ApplyFleetMods(veh, mods)
        end
    end

    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, veh, -1)

    activeVehicle = {
        vehicleId   = data.vehicleId,
        entity      = veh,
        plate       = data.plate,
        mileage     = tonumber(data.mileage) or 0.0,
        mileageUnit = data.mileageUnit or PoliceConfig.mileageUnit or 'km',
        fuel        = tonumber(data.fuel) or 100.0,
        lastCoords  = GetEntityCoords(veh),
    }

    StartVehicleTick()

    UpdateMileageHUD()

    SendNUIMessage({
        action      = 'vehicleCheckedOut',
        label       = data.label,
        plate       = data.plate,
        mileage     = FormatMileage(activeVehicle.mileage, activeVehicle.mileageUnit),
        mileageUnit = activeVehicle.mileageUnit
    })
end)

function ApplyFleetMods(veh, mods)
    SetVehicleModKit(veh, 0)
    for modType, modValue in pairs(mods) do
        local t = tonumber(modType)
        local v = tonumber(modValue)
        if t and v then
            SetVehicleMod(veh, t, v, false)
        end
    end
end

local tickRunning = false

function StartVehicleTick()
    if tickRunning then return end
    tickRunning = true

    CreateThread(function()
        local stateSyncCounter = 0

        while activeVehicle do
            Wait(5000)

            local veh = activeVehicle.entity
            if not DoesEntityExist(veh) then break end

            local currentCoords = GetEntityCoords(veh)
            local lastCoords    = activeVehicle.lastCoords or currentCoords
            local distMetres    = #(currentCoords - lastCoords)
            local addedKm       = distMetres / 1000.0

            if addedKm > 0.001 then
                activeVehicle.mileage    = activeVehicle.mileage + addedKm
                activeVehicle.lastCoords = currentCoords
                TriggerServerEvent('police:server:fleetMileageTick', activeVehicle.vehicleId, addedKm)
                UpdateMileageHUD()
            end

            stateSyncCounter = stateSyncCounter + 1
            if stateSyncCounter >= 6 then
                stateSyncCounter = 0
                TriggerServerEvent('police:server:fleetStateTick', activeVehicle.vehicleId, {
                    fuel         = GetVehicleFuelLevel(veh) * 100.0 / math.max(1, GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume') or 65),
                    mileage      = activeVehicle.mileage,
                    bodyHealth   = GetVehicleBodyHealth(veh),
                    engineHealth = GetVehicleEngineHealth(veh),
                })
            end
        end

        tickRunning = false
    end)
end

function ReturnActiveVehicle()
    if not activeVehicle then return end

    local veh = activeVehicle.entity
    local state = {}

    if DoesEntityExist(veh) then
        state.fuel         = GetVehicleFuelLevel(veh) * 100.0 / math.max(1, GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume') or 65)
        state.mileage      = activeVehicle.mileage
        state.bodyHealth   = GetVehicleBodyHealth(veh)
        state.engineHealth = GetVehicleEngineHealth(veh)

        SetEntityAsMissionEntity(veh, false, true)
        DeleteVehicle(veh)
    else
        state.fuel    = activeVehicle.fuel
        state.mileage = activeVehicle.mileage
    end

    TriggerServerEvent('police:server:returnVehicle', activeVehicle.vehicleId, state)

    SendNUIMessage({ action = 'vehicleReturned' })
    activeVehicle = nil
end

function FormatMileage(km, unit)
    if unit == 'miles' then
        return ('%.1f mi'):format(km * KM_TO_MILES)
    end
    return ('%.1f km'):format(km)
end

function UpdateMileageHUD()
    if not activeVehicle then return end
    SendNUIMessage({
        action      = 'mileageUpdate',
        mileage     = FormatMileage(activeVehicle.mileage, activeVehicle.mileageUnit),
        mileageUnit = activeVehicle.mileageUnit
    })
end

RegisterNetEvent('jobs:client:jobUpdated', function(job)
    if activeVehicle and (not job or job.name ~= 'police' or not job.isOnDuty) then
        ReturnActiveVehicle()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if activeVehicle then
        ReturnActiveVehicle()
    end
    if garageProxId then
        exports.proximity:RemoveInteraction(garageProxId)
    end
end)
