
PoliceConfig   = {}
local myJob    = nil
local proximityIds = {}

function PushPoliceI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', PushPoliceI18n)

CreateThread(function()
    Wait(1500)
    PushPoliceI18n()
end)

local isJailed      = false
local jailRemaining = 0
local savedComponents = {}
local isWearingUniform = false

local function isMale()
    return GetEntityModel(PlayerPedId()) ~= GetHashKey('mp_f_freemode_01')
end

local function saveCurrentComponents()
    savedComponents = {}
    local ped = PlayerPedId()
    for _, compId in ipairs({ 1, 3, 4, 6, 7, 8, 9, 10, 11 }) do
        local drawable, texture = GetPedDrawableVariation(ped, compId), GetPedTextureVariation(ped, compId)
        savedComponents[compId] = { drawableId = drawable, textureId = texture }
    end
end

RegisterNetEvent('police:client:syncConfig', function(cfg)
    PoliceConfig = cfg
    RegisterPoliceBlips()
    RegisterPoliceZones()
end)

local blipHandles = {}

function RegisterPoliceBlips()
    for _, h in ipairs(blipHandles) do
        if DoesBlipExist(h) then RemoveBlip(h) end
    end
    blipHandles = {}

    local function addBlip(data)
        if not data or not data.x then return end
        local blip = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(blip, data.sprite or 60)
        SetBlipColour(blip, data.color or 29)
        SetBlipScale(blip, data.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(data.label or Sw.T('police.blip_default'))
        EndTextCommandSetBlipName(blip)
        table.insert(blipHandles, blip)
    end

    addBlip(PoliceConfig.stationBlip)
    addBlip(PoliceConfig.jailBlip)

    -- Facilitatile interne se vad doar daca esti politist
    if myJob and myJob.name == 'police' then
        addBlip(PoliceConfig.armoryBlip)
        addBlip(PoliceConfig.cloakroomBlip)
        addBlip(PoliceConfig.garageBlip)
    end
end

function RegisterPoliceZones()
    for _, id in pairs(proximityIds) do
        exports.proximity:RemoveInteraction(id)
    end
    proximityIds = {}

    if not myJob or myJob.name ~= 'police' then return end

    if myJob.isOnDuty and PoliceConfig.armoryCoords then
        local perms = myJob.permissions or {}
        local hasArmory = false
        for _, p in ipairs(perms) do
            if p == 'armory' then hasArmory = true; break end
        end
        if hasArmory then
            proximityIds['armory'] = exports.proximity:AddInteraction(
                PoliceConfig.armoryCoords,
                Sw.T('police.prox_armory'),
                'police_armory',
                {},
                function() TriggerServerEvent('police:server:openArmory') end,
                nil, nil, nil
            )
        end
    end

    if myJob.isOnDuty and PoliceConfig.cloakroomCoords then
        proximityIds['cloakroom'] = exports.proximity:AddInteraction(
            PoliceConfig.cloakroomCoords,
            Sw.T('police.prox_cloakroom'),
            'police_cloakroom',
            {},
            function() TriggerServerEvent('police:server:openCloakroom') end,
            nil, nil, nil
        )
    end
end

RegisterNetEvent('jobs:client:jobUpdated', function(job)
    myJob = job
    RegisterPoliceBlips()
    RegisterPoliceZones()
end)

RegisterNetEvent('police:client:sendToJail', function(data)
    isJailed      = true
    jailRemaining = data.remaining or 0

    local c = data.coords
    if c then
        SetEntityCoords(PlayerPedId(), c.x, c.y, c.z, false, false, false, false)
        if c.heading then SetEntityHeading(PlayerPedId(), c.heading) end
    end

    SendNUIMessage({ action = 'jailStart', remaining = jailRemaining, reason = data.reason })
end)

RegisterNetEvent('police:client:jailTimer', function(remaining)
    jailRemaining = remaining
    SendNUIMessage({ action = 'jailTimer', remaining = remaining })
end)

RegisterNetEvent('police:client:released', function(data)
    isJailed      = false
    jailRemaining = 0

    local c = data and data.coords
    if c then
        SetEntityCoords(PlayerPedId(), c.x, c.y, c.z, false, false, false, false)
        if c.heading then SetEntityHeading(PlayerPedId(), c.heading) end
    end

    SendNUIMessage({ action = 'jailEnd' })
end)

RegisterNetEvent('police:client:openArmory', function(weapons, equipment)
    PushPoliceI18n()
    SendNUIMessage({ action = 'openArmory', weapons = weapons, equipment = equipment })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('closeArmory', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('takeArmoryItem', function(data, cb)
    TriggerServerEvent('police:server:takeArmoryItem', data.itemName, data.isWeapon)
    cb('ok')
end)

RegisterNetEvent('police:client:openCloakroom', function(gender)
    PushPoliceI18n()
    SendNUIMessage({ action = 'openCloakroom', gender = gender })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('closeCloakroom', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('wearUniform', function(_, cb)
    -- Salvam tinuta civila DOAR cand nu suntem deja in uniforma. Altfel un al doilea
    -- click pe "Uniforma" ar suprascrie snapshot-ul cu uniforma si nu te-ai mai putea
    -- intoarce in civil (raman blocat in uniforma).
    if not isWearingUniform then
        saveCurrentComponents()
    end
    isWearingUniform = true
    TriggerServerEvent('police:server:applyUniform', isMale() and 'male' or 'female')
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('wearCivilian', function(_, cb)
    isWearingUniform = false
    TriggerServerEvent('police:server:setCivilianClothes')
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('police:client:applyUniform', function(components)
    local ped = PlayerPedId()
    for _, comp in ipairs(components or {}) do
        SetPedComponentVariation(ped, comp.componentId, comp.drawableId, comp.textureId, 0)
    end
end)

RegisterNetEvent('police:client:restoreCivilianClothes', function()
    local ped = PlayerPedId()
    for compId, comp in pairs(savedComponents) do
        SetPedComponentVariation(ped, compId, comp.drawableId, comp.textureId, 0)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if isJailed then
        TriggerServerEvent('police:server:saveJailTimer', jailRemaining)
    end
    for _, id in pairs(proximityIds) do
        exports.proximity:RemoveInteraction(id)
    end
end)
