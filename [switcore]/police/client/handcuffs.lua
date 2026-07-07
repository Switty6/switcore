
local isHandcuffed       = false
local handcuffRestricted = false

local nearbyInteractions = {}

local function isOfficerWithArrest()
    if not myJob then return false end
    if myJob.name ~= 'police' or not myJob.isOnDuty then return false end
    local perms = myJob.permissions or {}
    for _, p in ipairs(perms) do
        if p == 'arrest' then return true end
    end
    return false
end

local function cleanNearbyInteractions()
    for src, id in pairs(nearbyInteractions) do
        exports.proximity:RemoveInteraction(id)
    end
    nearbyInteractions = {}
end

CreateThread(function()
    while true do
        Wait(2000)

        if not isOfficerWithArrest() then
            cleanNearbyInteractions()
        else
            local maxDist  = (PoliceConfig.handcuffDist or 2.5) + 0.5
            local myPed    = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local mySrc    = GetPlayerServerId(PlayerId())

            for targetSrc, id in pairs(nearbyInteractions) do
                local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
                if not targetPed or not DoesEntityExist(targetPed) then
                    exports.proximity:RemoveInteraction(id)
                    nearbyInteractions[targetSrc] = nil
                else
                    local dist = #(myCoords - GetEntityCoords(targetPed))
                    if dist > maxDist + 2.0 then
                        exports.proximity:RemoveInteraction(id)
                        nearbyInteractions[targetSrc] = nil
                    end
                end
            end

            for _, playerId in ipairs(GetActivePlayers()) do
                local targetSrc = GetPlayerServerId(playerId)
                if targetSrc ~= mySrc and not nearbyInteractions[targetSrc] then
                    local targetPed = GetPlayerPed(playerId)
                    if DoesEntityExist(targetPed) then
                        local dist = #(myCoords - GetEntityCoords(targetPed))
                        if dist <= maxDist then
                            local id = exports.proximity:AddEntityInteraction(
                                targetPed,
                                Sw.T('police.prox_handcuff'),
                                'police_handcuff',
                                { targetSrc = targetSrc },
                                function(data)
                                    TriggerServerEvent('police:server:handcuffPlayer', data.targetSrc)
                                end,
                                nil, nil
                            )
                            nearbyInteractions[targetSrc] = id
                        end
                    end
                end
            end
        end
    end
end)

local function applyHandcuffRestrictions()
    if handcuffRestricted then return end
    handcuffRestricted = true
    CreateThread(function()
        while isHandcuffed do
            DisableControlAction(0, 19,  true)
            DisableControlAction(0, 20,  true)
            DisableControlAction(0, 24,  true)
            DisableControlAction(0, 25,  true)
            DisableControlAction(0, 47,  true)
            DisableControlAction(0, 58,  true)
            DisablePlayerFiring(PlayerId(), true)
            SetPedCanSwitchWeapon(PlayerPedId(), false)
            Wait(0)
        end
        SetPedCanSwitchWeapon(PlayerPedId(), true)
        handcuffRestricted = false
    end)
end

RegisterNetEvent('police:client:handcuffed', function()
    isHandcuffed = true
    applyHandcuffRestrictions()
    SendNUIMessage({ action = 'handcuffed', state = true })
end)

RegisterNetEvent('police:client:unhandcuffed', function()
    isHandcuffed = false
    SendNUIMessage({ action = 'handcuffed', state = false })
end)

RegisterNetEvent('police:client:openArrestForm', function(targetSrc)
    PushPoliceI18n()
    SendNUIMessage({ action = 'openArrestForm', targetSrc = targetSrc })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('submitArrest', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('police:server:arrestPlayer',
        data.targetSrc,
        data.reason,
        data.minutes,
        data.bail
    )
    cb('ok')
end)

RegisterNUICallback('cancelArrest', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('police:client:playerHandcuffedByMe', function(targetSrc)
    if nearbyInteractions[targetSrc] then
        exports.proximity:RemoveInteraction(nearbyInteractions[targetSrc])
        nearbyInteractions[targetSrc] = nil
    end

    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
    if not DoesEntityExist(targetPed) then return end

    local uncuffId = exports.proximity:AddEntityInteraction(
        targetPed,
        Sw.T('police.prox_uncuff'),
        'police_uncuff',
        { targetSrc = targetSrc },
        function(data)
            TriggerServerEvent('police:server:unhandcuffPlayer', data.targetSrc)
        end,
        nil, nil
    )

    local arrestId = exports.proximity:AddEntityInteraction(
        targetPed,
        Sw.T('police.prox_arrest'),
        'police_arrest',
        { targetSrc = targetSrc },
        function(data)
            TriggerEvent('police:client:openArrestForm', data.targetSrc)
        end,
        nil, nil
    )

    nearbyInteractions[targetSrc .. '_uncuff'] = uncuffId
    nearbyInteractions[targetSrc .. '_arrest'] = arrestId
end)

RegisterCommand('handcuff', function()
    if not isOfficerWithArrest() then return end

    local maxDist  = (PoliceConfig.handcuffDist or 2.5) + 0.5
    local myPed    = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local mySrc    = GetPlayerServerId(PlayerId())

    local closestSrc, closestDist = nil, maxDist
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetSrc = GetPlayerServerId(playerId)
        if targetSrc ~= mySrc then
            local targetPed = GetPlayerPed(playerId)
            if DoesEntityExist(targetPed) then
                local dist = #(myCoords - GetEntityCoords(targetPed))
                if dist <= closestDist then
                    closestSrc  = targetSrc
                    closestDist = dist
                end
            end
        end
    end

    if not closestSrc then
        TriggerEvent('switcore:notify:local', 'warning', Sw.T('police.no_player_nearby'), 3000)
        return
    end

    TriggerServerEvent('police:server:handcuffPlayer', closestSrc)
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cleanNearbyInteractions()
end)
