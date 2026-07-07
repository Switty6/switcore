local isUIOpen        = false
local godmode         = false
local invisible       = false
local noWantedActive  = false
local frozenTime      = false

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

local function CloseAdmin()
    if not isUIOpen then return end
    isUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function OpenAdmin()
    if isUIOpen then return end
    TriggerServerEvent('admin:server:open')
end

RegisterNetEvent('admin:client:open', function(data)
    if not data or not data.tabs or #data.tabs == 0 then
        exports.notifications:Notify('error', Sw.T('admin.client.access_denied'), 3000)
        return
    end
    isUIOpen = true
    pushI18n()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = 'open',
        tabs       = data.tabs,
        perms      = data.perms or {},
        players    = data.players or {},
        currencies = data.currencies or {},
        groups     = data.groups or {},
    })
end)

RegisterCommand('admin', OpenAdmin, false)
RegisterKeyMapping('admin', 'Admin Menu', 'keyboard', 'F1')

RegisterNUICallback('close', function(_, cb)
    CloseAdmin()
    cb('ok')
end)

RegisterNUICallback('getPlayers', function(_, cb)
    TriggerServerEvent('admin:server:getPlayers')
    cb('ok')
end)

RegisterNUICallback('getPlayerInfo', function(data, cb)
    if data and data.targetId then
        TriggerServerEvent('admin:server:getPlayerInfo', data.targetId)
    end
    cb('ok')
end)

RegisterNUICallback('banPlayer', function(data, cb)
    TriggerServerEvent('admin:server:banPlayer', data.targetId, data.reason, data.duration)
    cb('ok')
end)

RegisterNUICallback('kickPlayer', function(data, cb)
    TriggerServerEvent('admin:server:kickPlayer', data.targetId, data.reason)
    cb('ok')
end)

RegisterNUICallback('warnPlayer', function(data, cb)
    TriggerServerEvent('admin:server:warnPlayer', data.targetId, data.reason)
    cb('ok')
end)

RegisterNUICallback('gotoPlayer', function(data, cb)
    if not data or not data.targetId then cb('err'); return end
    CloseAdmin()
    TriggerServerEvent('admin:server:gotoPlayer', data.targetId)
    cb('ok')
end)

RegisterNUICallback('bringPlayer', function(data, cb)
    TriggerServerEvent('admin:server:bringPlayer', data.targetId)
    cb('ok')
end)

RegisterNUICallback('freezePlayer', function(data, cb)
    TriggerServerEvent('admin:server:freezePlayer', data.targetId, data.frozen)
    cb('ok')
end)

RegisterNUICallback('spectatePlayer', function(data, cb)
    if IsSpectating() then
        StopSpectate()
        SendNUIMessage({ action = 'spectateState', active = false })
    else
        local ok = StartSpectate(data.targetId)
        if ok then
            CloseAdmin()
            SendNUIMessage({ action = 'spectateState', active = true })
        end
    end
    cb('ok')
end)

RegisterNUICallback('giveCashToPlayer', function(data, cb)
    TriggerServerEvent('admin:server:giveCashToPlayer', data.targetId, data.amount, data.target, data.currencyId)
    cb('ok')
end)

RegisterNUICallback('addGroup', function(data, cb)
    TriggerServerEvent('admin:server:addGroup', data.targetId, data.group)
    cb('ok')
end)

RegisterNUICallback('removeGroup', function(data, cb)
    TriggerServerEvent('admin:server:removeGroup', data.targetId, data.group)
    cb('ok')
end)

RegisterNUICallback('setBucket', function(data, cb)
    TriggerServerEvent('admin:server:setBucket', data.targetId, data.bucket)
    cb('ok')
end)

RegisterNUICallback('getPlayerInventory', function(data, cb)
    if data and data.targetId then
        TriggerServerEvent('admin:server:getPlayerInventory', data.targetId)
    end
    cb('ok')
end)

RegisterNUICallback('getItemCatalog', function(_, cb)
    TriggerServerEvent('admin:server:getItemCatalog')
    cb('ok')
end)

RegisterNUICallback('givePlayerItem', function(data, cb)
    TriggerServerEvent('admin:server:givePlayerItem', data.targetId, data.itemName, data.amount)
    cb('ok')
end)

RegisterNUICallback('takePlayerItem', function(data, cb)
    TriggerServerEvent('admin:server:takePlayerItem', data.targetId, data.itemName, data.amount, data.slot)
    cb('ok')
end)

RegisterNUICallback('getPlayerNeeds', function(data, cb)
    if data and data.targetId then
        TriggerServerEvent('admin:server:getPlayerNeeds', data.targetId)
    end
    cb('ok')
end)

RegisterNUICallback('setPlayerNeed', function(data, cb)
    TriggerServerEvent('admin:server:setPlayerNeed', data.targetId, data.key, data.value)
    cb('ok')
end)

RegisterNUICallback('healTarget', function(data, cb)
    TriggerServerEvent('admin:server:healTarget', data.targetId)
    cb('ok')
end)

RegisterNUICallback('reviveTarget', function(data, cb)
    TriggerServerEvent('admin:server:reviveTarget', data.targetId)
    cb('ok')
end)

RegisterNUICallback('getPlayerCharacterInfo', function(data, cb)
    if data and data.targetId then
        TriggerServerEvent('admin:server:getPlayerCharacterInfo', data.targetId)
    end
    cb('ok')
end)

RegisterNUICallback('teleportTargetToCoords', function(data, cb)
    TriggerServerEvent('admin:server:teleportTargetToCoords', data.targetId, data.x, data.y, data.z)
    cb('ok')
end)

RegisterNUICallback('getPlayerVehicles', function(data, cb)
    if data and data.targetId then
        TriggerServerEvent('admin:server:getPlayerVehicles', data.targetId)
    end
    cb('ok')
end)

RegisterNUICallback('spawnPlayerVehicle', function(data, cb)
    TriggerServerEvent('admin:server:spawnPlayerVehicle', data.targetId, data.vehicleId)
    cb('ok')
end)

RegisterNUICallback('impoundPlayerVehicle', function(data, cb)
    TriggerServerEvent('admin:server:impoundPlayerVehicle', data.vehicleId, data.reason)
    cb('ok')
end)

RegisterNUICallback('releasePlayerVehicle', function(data, cb)
    TriggerServerEvent('admin:server:releasePlayerVehicle', data.vehicleId)
    cb('ok')
end)

RegisterNUICallback('setVehicleFuelAdmin', function(data, cb)
    TriggerServerEvent('admin:server:setVehicleFuelAdmin', data.vehicleId, data.amount)
    cb('ok')
end)

RegisterNUICallback('getJobsCatalog', function(_, cb)
    TriggerServerEvent('admin:server:getJobsCatalog')
    cb('ok')
end)

RegisterNUICallback('getPlayerJob', function(data, cb)
    if data and data.targetId then
        TriggerServerEvent('admin:server:getPlayerJob', data.targetId)
    end
    cb('ok')
end)

RegisterNUICallback('setPlayerJob', function(data, cb)
    TriggerServerEvent('admin:server:setPlayerJob', data.targetId, data.jobName, data.grade)
    cb('ok')
end)

RegisterNUICallback('firePlayer', function(data, cb)
    TriggerServerEvent('admin:server:firePlayer', data.targetId)
    cb('ok')
end)

RegisterNetEvent('admin:client:playerInventory', function(payload)
    SendNUIMessage({ action = 'playerInventory', payload = payload })
end)

RegisterNetEvent('admin:client:itemCatalog', function(catalog)
    SendNUIMessage({ action = 'itemCatalog', catalog = catalog })
end)

RegisterNetEvent('admin:client:itemsCatalog', function(catalog)
    SendNUIMessage({ action = 'itemsCatalog', catalog = catalog })
end)

RegisterNetEvent('admin:client:playerNeeds', function(payload)
    SendNUIMessage({ action = 'playerNeeds', payload = payload })
end)

RegisterNetEvent('admin:client:playerCharacterInfo', function(payload)
    SendNUIMessage({ action = 'playerCharacterInfo', payload = payload })
end)

RegisterNetEvent('admin:client:playerVehicles', function(payload)
    SendNUIMessage({ action = 'playerVehicles', payload = payload })
end)

RegisterNetEvent('admin:client:jobsCatalog', function(catalog)
    SendNUIMessage({ action = 'jobsCatalog', catalog = catalog })
end)

RegisterNetEvent('admin:client:playerJob', function(payload)
    SendNUIMessage({ action = 'playerJob', payload = payload })
end)

RegisterNetEvent('admin:client:applyHeal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetPedMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('admin:client:applyRevive', function()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetPedMaxHealth(ped))
    ClearPedTasksImmediately(ped)
end)

RegisterNUICallback('toggleNoclip', function(_, cb)
    local willActivate = not IsNoclipActive()
    if willActivate then CloseAdmin() end
    local active = ToggleNoclip()
    SendNUIMessage({ action = 'noclipState', active = active })
    cb('ok')
end)

local godmodeThread = false
RegisterNUICallback('toggleGodmode', function(_, cb)
    godmode = not godmode
    local ped = PlayerPedId()
    SetEntityInvincible(ped, godmode)
    SetPlayerInvincible(PlayerId(), godmode)
    SendNUIMessage({ action = 'godmodeState', active = godmode })

    if godmode and not godmodeThread then
        godmodeThread = true
        CreateThread(function()
            while godmode do
                local p = PlayerPedId()
                SetEntityInvincible(p, true)
                SetPlayerInvincible(PlayerId(), true)
                local maxHp = GetEntityMaxHealth(p)
                if GetEntityHealth(p) < maxHp then SetEntityHealth(p, maxHp) end
                ClearPedBloodDamage(p)
                Wait(500)
            end
            godmodeThread = false
        end)
    end
    cb('ok')
end)

RegisterNUICallback('toggleInvisible', function(_, cb)
    invisible = not invisible
    SetEntityVisible(PlayerPedId(), not invisible, false)
    SetLocalPlayerInvisibleLocally(invisible)
    SendNUIMessage({ action = 'invisibleState', active = invisible })
    cb('ok')
end)

RegisterNUICallback('toggleEntityOverlay', function(_, cb)
    local active = ToggleOverlay()
    SaveOverlayKVP()
    SendNUIMessage({ action = 'overlayState', active = active })
    cb('ok')
end)

RegisterNUICallback('getOverlaySettings', function(_, cb)
    local s = GetOverlaySettings()
    SendNUIMessage({ action = 'overlaySettings', settings = s, active = IsOverlayActive() })
    cb('ok')
end)

RegisterNUICallback('saveOverlaySettings', function(data, cb)
    if data and data.settings then
        ApplyOverlaySettings(data.settings)
        SaveOverlayKVP()
    end
    cb('ok')
end)

RegisterNUICallback('healSelf', function(_, cb)
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetPedMaxHealth(ped))
    TriggerServerEvent('admin:server:healSelf')
    cb('ok')
end)

RegisterNUICallback('armorSelf', function(_, cb)
    SetPedArmour(PlayerPedId(), 100)
    cb('ok')
end)

RegisterNUICallback('reviveSelf', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetPedMaxHealth(ped))
    ClearPedTasksImmediately(ped)
    TriggerServerEvent('admin:server:reviveSelf')
    cb('ok')
end)

RegisterNUICallback('giveWeapon', function(data, cb)
    if data and data.weapon and data.weapon ~= '' then
        local name = data.weapon:upper()
        if not name:match('^WEAPON_') then name = 'WEAPON_' .. name end
        local hash = GetHashKey(name)
        GiveWeaponToPed(PlayerPedId(), hash, data.ammo or 250, false, true)
    end
    cb('ok')
end)

RegisterNUICallback('removeWeapons', function(_, cb)
    RemoveAllPedWeapons(PlayerPedId(), true)
    cb('ok')
end)

RegisterNUICallback('giveCashToSelf', function(data, cb)
    TriggerServerEvent('admin:server:giveCashToSelf', data.amount, data.target, data.currencyId)
    cb('ok')
end)

RegisterNUICallback('teleportWaypoint', function(_, cb)
    CloseAdmin()
    TriggerServerEvent('admin:server:teleportToWaypoint')
    cb('ok')
end)

RegisterNUICallback('teleportCoords', function(data, cb)
    CloseAdmin()
    TriggerServerEvent('admin:server:teleportToCoords', data.x, data.y, data.z)
    cb('ok')
end)

RegisterNUICallback('getMyCoords', function(_, cb)
    local ped = PlayerPedId()
    local c   = GetEntityCoords(ped)
    SendNUIMessage({
        action  = 'myCoords',
        x       = math.floor(c.x * 100) / 100,
        y       = math.floor(c.y * 100) / 100,
        z       = math.floor(c.z * 100) / 100,
        heading = math.floor(GetEntityHeading(ped)),
    })
    cb('ok')
end)

RegisterNUICallback('setPedModel', function(data, cb)
    if not data or not data.model or data.model == '' then cb('err'); return end
    local hash = GetHashKey(data.model)
    if not IsModelInCdimage(hash) then cb('invalid_model'); return end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do Wait(50); t = t + 1 end
    if not HasModelLoaded(hash) then cb('timeout'); return end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    SetPedDefaultComponentVariation(PlayerPedId())
    cb('ok')
end)

local function getVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        veh = GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 71)
    end
    return veh
end

RegisterNUICallback('spawnVehicle', function(data, cb)
    if not data or not data.model then cb('err'); return end
    local hash = GetHashKey(data.model)
    if not IsModelInCdimage(hash) then cb('invalid_model'); return end

    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 50 do Wait(50); t = t + 1 end
    if not HasModelLoaded(hash) then cb('timeout'); return end

    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local head   = GetEntityHeading(ped)
    local fwd    = { x = -math.sin(math.rad(head)), y = math.cos(math.rad(head)) }
    local spawn  = vector3(coords.x + fwd.x * 5.0, coords.y + fwd.y * 5.0, coords.z)
    local veh    = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, head, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNumberPlateText(veh, 'ADMIN')
    SetModelAsNoLongerNeeded(hash)

    if data.enter then
        SetPedIntoVehicle(ped, veh, -1)
    end
    cb('ok')
end)

RegisterNUICallback('deleteVehicle', function(_, cb)
    local veh = getVehicle()
    if veh and veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
    cb('ok')
end)

RegisterNUICallback('deleteNearbyVehicles', function(_, cb)
    local ped    = PlayerPedId()
    local myVeh  = GetVehiclePedIsIn(ped, false)
    local coords = GetEntityCoords(ped)
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if v ~= myVeh and #(GetEntityCoords(v) - coords) <= 50.0 then
            SetEntityAsMissionEntity(v, true, true)
            DeleteVehicle(v)
        end
    end
    cb('ok')
end)

RegisterNUICallback('repairVehicle', function(_, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineOn(veh, true, true, false)
    end
    cb('ok')
end)

RegisterNUICallback('refuelVehicle', function(_, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 then
        TriggerEvent('vehicles:refuel', veh)
    end
    cb('ok')
end)

RegisterNUICallback('flipVehicle', function(_, cb)
    local veh = getVehicle()
    if veh and veh ~= 0 then
        local h = GetEntityHeading(veh)
        SetEntityRotation(veh, 0.0, 0.0, h, 2, true)
    end
    cb('ok')
end)

RegisterNUICallback('setPlate', function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 and data and data.plate then
        SetVehicleNumberPlateText(veh, data.plate)
    end
    cb('ok')
end)

RegisterNUICallback('setVehicleColor', function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 then
        SetVehicleColours(veh, data.primary or 0, data.secondary or 0)
    end
    cb('ok')
end)

RegisterNUICallback('setLivery', function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 then
        SetVehicleLivery(veh, data.livery or 0)
    end
    cb('ok')
end)

RegisterNUICallback('setWindowTint', function(data, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 then
        SetVehicleWindowTint(veh, data.tint or 0)
    end
    cb('ok')
end)

RegisterNUICallback('toggleEngine', function(_, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and veh ~= 0 then
        local on = GetIsVehicleEngineRunning(veh)
        SetVehicleEngineOn(veh, not on, true, true)
    end
    cb('ok')
end)

RegisterNUICallback('toggleLock', function(_, cb)
    local veh = getVehicle()
    if veh and veh ~= 0 then
        local state = GetVehicleDoorLockStatus(veh)
        SetVehicleDoorsLocked(veh, state == 2 and 1 or 2)
    end
    cb('ok')
end)

RegisterNUICallback('getResources', function(_, cb)
    TriggerServerEvent('admin:server:getResources')
    cb('ok')
end)

RegisterNUICallback('restartResource', function(data, cb)
    TriggerServerEvent('admin:server:restartResource', data.resourceName)
    cb('ok')
end)

RegisterNUICallback('startResource', function(data, cb)
    TriggerServerEvent('admin:server:startResource', data.resourceName)
    cb('ok')
end)

RegisterNUICallback('stopResource', function(data, cb)
    TriggerServerEvent('admin:server:stopResource', data.resourceName)
    cb('ok')
end)

RegisterNUICallback('getItemsCatalog', function(_, cb)
    TriggerServerEvent('admin:server:getItemsCatalog')
    cb('ok')
end)

RegisterNUICallback('saveItem', function(data, cb)
    TriggerServerEvent('admin:server:saveItem', data)
    cb('ok')
end)

RegisterNUICallback('deleteItem', function(data, cb)
    TriggerServerEvent('admin:server:deleteItem', data.name)
    cb('ok')
end)

RegisterNUICallback('reloadItemsCatalog', function(_, cb)
    TriggerServerEvent('admin:server:reloadItemsCatalog')
    cb('ok')
end)

RegisterNUICallback('syncTime', function(data, cb)
    TriggerServerEvent('admin:server:syncTime', data.hour, data.minute, data.freeze)
    cb('ok')
end)

RegisterNUICallback('syncWeather', function(data, cb)
    TriggerServerEvent('admin:server:syncWeather', data.weather)
    cb('ok')
end)

RegisterNUICallback('announce', function(data, cb)
    TriggerServerEvent('admin:server:announce', data.message)
    cb('ok')
end)

RegisterNetEvent('admin:client:updatePlayers', function(players)
    SendNUIMessage({ action = 'updatePlayers', players = players })
end)

RegisterNetEvent('admin:client:playerInfo', function(info)
    SendNUIMessage({ action = 'playerInfo', info = info })
end)

RegisterNetEvent('admin:client:resourceList', function(list)
    SendNUIMessage({ action = 'resourceList', list = list })
end)

RegisterNetEvent('admin:client:teleport', function(coords)
    exports.core:SafeTeleport(coords)
end)

RegisterNetEvent('admin:client:setFreeze', function(frozen)
    FreezeEntityPosition(PlayerPedId(), frozen)
end)

RegisterNetEvent('admin:client:syncTime', function(hour, minute, freeze)
    NetworkOverrideClockTime(hour, minute, 0)
    frozenTime = freeze and true or false
end)

RegisterNetEvent('admin:client:syncWeather', function(weather)
    SetWeatherTypeOverTime(weather, 5.0)
    Wait(5500)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
end)

CreateThread(function()
    while true do
        if frozenTime then
            NetworkOverrideClockTime(GetClockHours(), GetClockMinutes(), 0)
        end
        Wait(2000)
    end
end)

RegisterNetEvent('admin:bucket:applyRules', function(rules)
    noWantedActive = rules and rules.noWanted == true
    if noWantedActive then
        ClearPlayerWantedLevel(PlayerId())
        SetMaxWantedLevel(0)
        SetPoliceIgnorePlayer(PlayerId(), true)
    else
        SetMaxWantedLevel(5)
        SetPoliceIgnorePlayer(PlayerId(), false)
    end
end)

CreateThread(function()
    while true do
        if noWantedActive then
            SetMaxWantedLevel(0)
            Wait(2000)
        else
            Wait(5000)
        end
    end
end)

local function TeleportToWaypoint()
    local waypointBlip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypointBlip) then
        exports.notifications:Notify('error', Sw.T('admin.client.no_waypoint'), 3000)
        return
    end

    local coords = GetBlipInfoIdCoord(waypointBlip)
    local ped    = PlayerPedId()
    local veh    = GetVehiclePedIsIn(ped, false)
    local entity = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped

    FreezeEntityPosition(entity, true)

    local groundZ, found
    for _, z in ipairs({ 1000.0, 500.0, 250.0, 100.0, 50.0, 0.0 }) do
        SetEntityCoordsNoOffset(entity, coords.x, coords.y, z, false, false, false)
        local t = 0
        while not HasCollisionLoadedAroundEntity(entity) and t < 20 do
            RequestCollisionAtCoord(coords.x, coords.y, z)
            Wait(50)
            t = t + 1
        end
        found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, z, false)
        if found then break end
    end

    SetEntityCoordsNoOffset(entity, coords.x, coords.y, (found and groundZ + 1.0) or 100.0, false, false, false)
    FreezeEntityPosition(entity, false)
    exports.notifications:Notify('success', Sw.T('admin.client.teleported_waypoint'), 2500)
end

RegisterNetEvent('admin:client:teleportToWaypoint', TeleportToWaypoint)

RegisterNetEvent('admin:client:toggleOverlay', function()
    local active = ToggleOverlay()
    SaveOverlayKVP()
    exports.notifications:Notify('info', active and Sw.T('admin.client.dev_overlay_on') or Sw.T('admin.client.dev_overlay_off'), 3000)
end)

RegisterCommand('devoverlay', function()
    TriggerServerEvent('admin:server:checkOverlayPermission')
end, false)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    if isUIOpen then CloseAdmin() end
    if IsNoclipActive() then ToggleNoclip() end
    if IsSpectating() then StopSpectate() end
    if godmode then
        godmode = false
        SetEntityInvincible(PlayerPedId(), false)
        SetPlayerInvincible(PlayerId(), false)
    end
    if invisible then SetEntityVisible(PlayerPedId(), true, false) end
    if IsOverlayActive() then SetOverlayActive(false) end
    if noWantedActive then
        SetMaxWantedLevel(5)
        SetPoliceIgnorePlayer(PlayerId(), false)
    end
end)
