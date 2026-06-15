local nearbyPatients       = {}
local nearbyUnconscious    = {}
local isCarrying           = nil
local carryThread          = nil

CreateThread(function()
    while not Cfg.patientScanInterval do Wait(500) end

    while true do
        Wait((Cfg.patientScanInterval or 2) * 1000)

        if not isEMS or not emsOnDuty then
            for _, id in pairs(nearbyPatients) do
                exports.proximity:RemoveInteraction(id)
            end
            for _, id in pairs(nearbyUnconscious) do
                exports.proximity:RemoveInteraction(id)
            end
            nearbyPatients    = {}
            nearbyUnconscious = {}
            goto cont
        end

        local myPed    = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local range    = Cfg.patientScanRange or 3.5

        for targetSrc, id in pairs(nearbyPatients) do
            local targetPlayer = GetPlayerFromServerId(targetSrc)
            local tPed         = GetPlayerPed(targetPlayer)
            if not DoesEntityExist(tPed) or
               #(myCoords - GetEntityCoords(tPed)) > range + 2.0 then
                exports.proximity:RemoveInteraction(id)
                nearbyPatients[targetSrc] = nil
            end
        end

        for targetSrc, id in pairs(nearbyUnconscious) do
            local targetPlayer = GetPlayerFromServerId(targetSrc)
            local tPed         = GetPlayerPed(targetPlayer)
            if not DoesEntityExist(tPed) or
               #(myCoords - GetEntityCoords(tPed)) > range + 2.0 then
                exports.proximity:RemoveInteraction(id)
                nearbyUnconscious[targetSrc] = nil
            end
        end

        for _, playerId in ipairs(GetActivePlayers()) do
            local targetSrc = GetPlayerServerId(playerId)
            if targetSrc == GetPlayerServerId(PlayerId()) then goto nextP end

            local tPed = GetPlayerPed(playerId)
            if not DoesEntityExist(tPed) then goto nextP end

            local dist = #(myCoords - GetEntityCoords(tPed))
            if dist <= range then
                if not nearbyPatients[targetSrc] then
                    local id = exports.proximity:AddEntityInteraction(
                        tPed, Sw.T('ems.examine_patient'), 'ems_examine',
                        { targetSrc = targetSrc },
                        function(data)
                            TriggerServerEvent('ems:server:getPatientData', data.targetSrc)
                        end
                    )
                    nearbyPatients[targetSrc] = id
                end

                if IsPedRagdoll(tPed) and not nearbyUnconscious[targetSrc] then
                    local stretcherId = exports.proximity:AddEntityInteraction(
                        tPed, Sw.T('ems.lift_patient'), 'ems_lift',
                        { targetSrc = targetSrc },
                        function(data)
                            if isCarrying then
                                TriggerServerEvent('ems:server:placePatient', isCarrying, false, nil)
                            else
                                TriggerServerEvent('ems:server:liftPatient', data.targetSrc)
                            end
                        end
                    )
                    nearbyUnconscious[targetSrc] = stretcherId
                elseif not IsPedRagdoll(tPed) and nearbyUnconscious[targetSrc] then
                    exports.proximity:RemoveInteraction(nearbyUnconscious[targetSrc])
                    nearbyUnconscious[targetSrc] = nil
                end
            end

            ::nextP::
        end

        ::cont::
    end
end)

RegisterNetEvent('ems:client:openPatientMenu')
AddEventHandler('ems:client:openPatientMenu', function(data)
    SetNuiFocus(true, true)
    EmsPushI18n()
    SendNUIMessage({ action = 'openPatientMenu', data = data })
end)

RegisterNetEvent('ems:client:patientDataUpdated')
AddEventHandler('ems:client:patientDataUpdated', function(data)
    SendNUIMessage({ action = 'openPatientMenu', data = data })
end)

RegisterNUICallback('closePatientMenu', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePatientMenu' })
    cb('ok')
end)

RegisterNUICallback('revivePatient', function(data, cb)
    TriggerServerEvent('ems:server:revivePatient', data.patientSrc)
    cb('ok')
end)

RegisterNUICallback('treatInjury', function(data, cb)
    TriggerServerEvent('ems:server:treatInjury', data.patientSrc, data.injuryId)
    cb('ok')
end)

RegisterNUICallback('cureAllConditions', function(data, cb)
    TriggerServerEvent('ems:server:cureAllConditions', data.patientSrc)
    cb('ok')
end)

RegisterNUICallback('administerIV', function(data, cb)
    TriggerServerEvent('ems:server:administerIV', data.patientSrc, data.itemName, data.plate)
    cb('ok')
end)

RegisterNUICallback('logDiagnosis', function(data, cb)
    TriggerServerEvent('ems:server:logDiagnosis', data.patientSrc, data.notes)
    cb('ok')
end)

RegisterNetEvent('ems:client:startCarrying')
AddEventHandler('ems:client:startCarrying', function(targetSrc)
    isCarrying = targetSrc
    local targetPlayer = GetPlayerFromServerId(targetSrc)

    CreateThread(function()
        while isCarrying == targetSrc do
            Wait(0)
            local myPed     = PlayerPedId()
            local myCoords  = GetEntityCoords(myPed)
            local tPed      = GetPlayerPed(targetPlayer)

            if not DoesEntityExist(tPed) then break end

            local fwd = GetEntityForwardVector(myPed)
            local newX = myCoords.x + fwd.x * 0.5
            local newY = myCoords.y + fwd.y * 0.5
            local newZ = myCoords.z

            SetEntityCoords(tPed, newX, newY, newZ, false, false, false, false)
            SetEntityHeading(tPed, GetEntityHeading(myPed))
        end
    end)

    exports.notifications:Notify('info', Sw.T('ems.carrying_patient'), 5000)
end)

RegisterNetEvent('ems:client:stopCarrying')
AddEventHandler('ems:client:stopCarrying', function()
    isCarrying = nil
end)

RegisterNetEvent('ems:client:youAreLiftedBy')
AddEventHandler('ems:client:youAreLiftedBy', function(emsSrc)
    FreezeEntityPosition(PlayerPedId(), true)
end)

RegisterNetEvent('ems:client:youArePlaced')
AddEventHandler('ems:client:youArePlaced', function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetPedToRagdoll(ped, 500, 500, 0, false, false, false)
end)

RegisterNetEvent('ems:client:placeInAmbulance')
AddEventHandler('ems:client:placeInAmbulance', function(vehiclePlate)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local plate = string.gsub(GetVehicleNumberPlateText(veh), '%s+', '')
        if plate == vehiclePlate then
            SetPedIntoVehicle(ped, veh, 1)
            break
        end
    end
end)

RegisterNetEvent('ems:client:playerRevived')
AddEventHandler('ems:client:playerRevived', function(data)
end)
