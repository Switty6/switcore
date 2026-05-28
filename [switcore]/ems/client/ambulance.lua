local currentAmbuPlate   = nil
local ambInteractionId   = nil
local emsBlips           = {}
local blipUpdateTimer    = 0

CreateThread(function()
    while not Cfg.ambulanceModels do Wait(500) end

    while true do
        Wait(2000)
        if not isEMS or not emsOnDuty then
            if ambInteractionId then
                exports.proximity:RemoveInteraction(ambInteractionId)
                ambInteractionId  = nil
                currentAmbuPlate  = nil
            end
            goto cont
        end

        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle == 0 then
            if ambInteractionId then
                exports.proximity:RemoveInteraction(ambInteractionId)
                ambInteractionId = nil
                currentAmbuPlate = nil
            end
            goto cont
        end

        local model    = GetEntityModel(vehicle)
        local modelStr = string.lower(GetDisplayNameFromVehicleModel(model) or '')
        local isAmbu   = false

        for _, m in ipairs(Cfg.ambulanceModels or {}) do
            if modelStr == string.lower(m) then isAmbu = true; break end
        end

        if not isAmbu then goto cont end

        local plate = string.gsub(GetVehicleNumberPlateText(vehicle) or '', '%s+', '')

        if plate ~= currentAmbuPlate then
            if ambInteractionId then
                exports.proximity:RemoveInteraction(ambInteractionId)
            end
            ambInteractionId = exports.proximity:AddEntityInteraction(
                vehicle, 'Inventar Ambulanta', 'ems_ambulance_inv',
                { plate = plate },
                function(data)
                    TriggerServerEvent('ems:server:getVehicleInventory', data.plate)
                end
            )
            currentAmbuPlate = plate
            TriggerServerEvent('ems:server:stockDefaultInventory', plate)
        end

        local coords = GetEntityCoords(vehicle)
        TriggerServerEvent('ems:server:reportVehiclePos', plate,
            { x = coords.x, y = coords.y, z = coords.z }, modelStr)

        ::cont::
    end
end)

RegisterNetEvent('ems:client:vehicleInventory')
AddEventHandler('ems:client:vehicleInventory', function(items, plate)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openVehicleInventory',
        items  = items,
        plate  = plate or currentAmbuPlate,
        ivTreatments = Cfg.ivTreatments or {},
    })
end)

RegisterNUICallback('closeVehicleInventory', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeVehicleInventory' })
    cb('ok')
end)

RegisterNUICallback('takeFromAmbulance', function(data, cb)
    TriggerServerEvent('ems:server:takeFromAmbulance', data.plate, data.itemName, data.amount or 1)
    cb('ok')
end)

RegisterNetEvent('ems:client:updateEMSBlips')
AddEventHandler('ems:client:updateEMSBlips', function(list)
    for _, blip in pairs(emsBlips) do
        RemoveBlip(blip)
    end
    emsBlips = {}

    for _, unit in ipairs(list or {}) do
        local blip = AddBlipForCoord(unit.x, unit.y, unit.z)
        SetBlipSprite(blip, 61)
        SetBlipColour(blip, 25)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('EMS - ' .. (unit.plate or ''))
        EndTextCommandSetBlipName(blip)
        emsBlips[unit.plate] = blip
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in pairs(emsBlips) do RemoveBlip(blip) end
end)
