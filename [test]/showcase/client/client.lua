-- ══════════════════════════════════════════════════════════════
--  Showcase Client  -  vehicle cycle + proximity demo
-- ══════════════════════════════════════════════════════════════

-- ── Notificare locală (cu fallback nativ) ─────────────────────
local function notif(t, msg)
    local ok = pcall(function()
        exports.notifications:Notify(t, msg, 3500)
    end)
    if not ok then
        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName('[SC] ' .. msg)
        DrawNotification(false, true)
    end
end

-- ══════════════════════════════════════════════════════════════
--  TELEPORT & VEHICLE UTILITY
-- ══════════════════════════════════════════════════════════════

-- /sc_pdm - teleport la Premium Deluxe Motorsport (achiziție vehicul)
RegisterCommand('sc_pdm', function()
    SetEntityCoords(PlayerPedId(), -46.5, -1102.0, 26.42, false, false, false, true)
    notif('info', 'Teleportat → Premium Deluxe Motorsport')
end, false)

-- /sc_pump - teleport la benzinărie (Alta Ave)
RegisterCommand('sc_pump', function()
    SetEntityCoords(PlayerPedId(), 265.0, -1261.5, 29.3, false, false, false, true)
    notif('info', 'Teleportat → Stație combustibil (Alta Ave)')
end, false)

-- /sc_repair - repară vehiculul curent (demo damage)
RegisterCommand('sc_repair', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then notif('error', 'Nu ești în vehicul'); return end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    notif('success', 'Vehicul reparat complet')
end, false)

-- ══════════════════════════════════════════════════════════════
--  PROXIMITY SHOWCASE
--  /sc_proximity   → spawnează 4 demo-uri în linie în fața ta:
--      3m   single option (verde)
--      6m   3 opțiuni stacked (albastru, demo ALT menu)
--      9m   ped cu entity interaction
--     9m+  vehicul cu entity interaction
--  /sc_proximity_clear → curățenie
-- ══════════════════════════════════════════════════════════════

local proxIds      = {}
local proxPed      = 0
local proxVehicle  = 0

local MARKER = {
    green = { r = 0,   g = 255, b = 0,   a = 200 },
    blue  = { r = 30,  g = 120, b = 255, a = 200 },
    cyan  = { r = 0,   g = 220, b = 220, a = 200 },
}

local function trackId(id)
    if id then proxIds[#proxIds + 1] = id end
    return id
end

local function onDemo(label)
    return function()
        local msg = '[PROXIMITY] ' .. label
        local ok = pcall(function() exports.notifications:Notify('success', msg, 3000) end)
        if not ok then
            SetNotificationTextEntry('STRING')
            AddTextComponentSubstringPlayerName(msg)
            DrawNotification(false, true)
        end
    end
end

local function fwd(heading, dist)
    local r = math.rad(heading)
    return vector3(-math.sin(r) * dist, math.cos(r) * dist, 0.0)
end
local function right(heading, dist) return fwd(heading - 90, dist) end

local function proxClear()
    for _, id in ipairs(proxIds) do
        exports.proximity:RemoveInteraction(id)
    end
    proxIds = {}
    if proxPed ~= 0 and DoesEntityExist(proxPed) then
        SetEntityAsMissionEntity(proxPed, false, true)
        DeleteEntity(proxPed)
    end
    proxPed = 0
    if proxVehicle ~= 0 and DoesEntityExist(proxVehicle) then
        SetEntityAsMissionEntity(proxVehicle, false, true)
        DeleteEntity(proxVehicle)
    end
    proxVehicle = 0
end

local function loadModel(hash)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 60 do Wait(50); t = t + 1 end
    return HasModelLoaded(hash)
end

RegisterCommand('sc_proximity', function()
    proxClear()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local h   = GetEntityHeading(ped)

    -- 1) Single option @ 3m forward (verde)
    local p1 = pos + fwd(h, 3)
    trackId(exports.proximity:AddInteraction(
        vector3(p1.x, p1.y, pos.z),
        'Apasă pentru a interacționa',
        'demo_single', {},
        onDemo('Single option'),
        nil, nil, MARKER.green
    ))

    -- 2) Trei opțiuni stacked @ 6m forward (albastru - ALT menu)
    local p2 = pos + fwd(h, 6)
    local v2 = vector3(p2.x, p2.y, pos.z)
    trackId(exports.proximity:AddInteraction(v2, 'Cumpără item',    'demo_buy',     {}, onDemo('Cumpără'),    nil, nil, MARKER.blue))
    trackId(exports.proximity:AddInteraction(v2, 'Vorbește cu NPC', 'demo_talk',    {}, onDemo('Vorbește'),   nil, nil, MARKER.blue))
    trackId(exports.proximity:AddInteraction(v2, 'Inspectează',     'demo_inspect', {}, onDemo('Inspectează'), nil, nil, MARKER.blue))

    -- 3) Ped @ 9m forward + 2m left, cu entity interaction
    CreateThread(function()
        local pedModel = `a_m_y_business_03`
        if not loadModel(pedModel) then
            notif('error', 'Model ped indisponibil'); return
        end
        local p3 = pos + fwd(h, 9) + right(h, -2)
        local npc = CreatePed(4, pedModel, p3.x, p3.y, pos.z - 1.0, h + 180.0, true, false)
        SetEntityAsMissionEntity(npc, true, true)
        FreezeEntityPosition(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedDiesWhenInjured(npc, false)
        SetModelAsNoLongerNeeded(pedModel)
        proxPed = npc
        trackId(exports.proximity:AddEntityInteraction(
            npc,
            'Vorbește cu el',
            'demo_ped', {},
            onDemo('Entity interaction pe PED'),
            nil, MARKER.cyan
        ))
    end)

    -- 4) Vehicul @ 9m forward + 3m right, cu entity interaction
    CreateThread(function()
        local vehModel = `sultan`
        if not loadModel(vehModel) then
            notif('error', 'Model vehicul indisponibil'); return
        end
        local p4 = pos + fwd(h, 9) + right(h, 3)
        local veh = CreateVehicle(vehModel, p4.x, p4.y, pos.z, h + 90.0, true, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        SetVehicleDoorsLocked(veh, 2)
        SetModelAsNoLongerNeeded(vehModel)
        proxVehicle = veh
        trackId(exports.proximity:AddEntityInteraction(
            veh,
            'Inspectează mașina',
            'demo_vehicle', {},
            onDemo('Entity interaction pe VEHICUL'),
            nil, MARKER.cyan
        ))
    end)

    notif('success', '4 demo-uri spawnate în fața ta - mergi înainte')
    notif('info', '3m single  →  6m stacked (ALT)  →  9m ped + vehicul')
end, false)

RegisterCommand('sc_proximity_clear', function()
    local n = #proxIds
    proxClear()
    notif('success', n .. ' interacțiuni demo șterse')
end, false)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then proxClear() end
end)

-- ══════════════════════════════════════════════════════════════
--  /sc_coords - afișează coordonatele curente în chat & consolă
-- ══════════════════════════════════════════════════════════════
RegisterCommand('sc_coords', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local h   = GetEntityHeading(ped)

    local vec3   = string.format('vector3(%.2f, %.2f, %.2f)', pos.x, pos.y, pos.z)
    local vec4   = string.format('vector4(%.2f, %.2f, %.2f, %.2f)', pos.x, pos.y, pos.z, h)
    local raw    = string.format('x=%.4f  y=%.4f  z=%.4f  h=%.2f', pos.x, pos.y, pos.z, h)

    TriggerEvent('chat:addMessage', {
        color = { 0, 220, 120 },
        multiline = true,
        args = { '[Coords]', vec3 }
    })
    TriggerEvent('chat:addMessage', {
        color = { 0, 180, 220 },
        multiline = true,
        args = { '[Coords]', vec4 }
    })
    TriggerEvent('chat:addMessage', {
        color = { 180, 180, 180 },
        multiline = true,
        args = { '[Coords]', raw }
    })

    print('[sc_coords] ' .. vec4)
    notif('info', 'Coordonate copiate în chat & F8')
end, false)

-- ══════════════════════════════════════════════════════════════
--  /sc_help
-- ══════════════════════════════════════════════════════════════
RegisterCommand('sc_help', function()
    local lines = {
        '════════════ SHOWCASE COMENZI ════════════',
        '─── Proximity ──────────────────────────────',
        '  /sc_proximity         Spawn 4 demo-uri (single / stacked / ped / vehicul)',
        '  /sc_proximity_clear   Curăță demo-urile',
        '─── Vehicle cycle ──────────────────────────',
        '  /sc_pdm               Teleport → PDM (achiziție)',
        '  /sc_pump              Teleport → stație combustibil',
        '  /sc_cash [suma]       Adaugă cash personajului',
        '  /sc_car [model]       Spawn vehicul owned în DB',
        '  /sc_fuel [0-100]      Setează combustibil în DB (sync vizual)',
        '  /sc_repair            Reparare vehicul curent',
        '  /sc_needs             Umple foame & sete (100%)',
        '  /sc_revive            Reinvie după moarte (EMS + revive nativ)',
        '  /sc_seedshowroom      Populează catalogul PDM cu vehicule demo',
        '  /sc_clearshowroom     Șterge vehiculele demo din catalog',
        '─── Utilitare ──────────────────────────────',
        '  /sc_coords            Afișează coordonatele curente (vector3 + vector4)',
        '═══════════════════════════════════════════',
    }
    for _, l in ipairs(lines) do print(l) end
    notif('info', 'Comenzi afișate în consolă (F8)')
end, false)

-- ══════════════════════════════════════════════════════════════
--  NET EVENTS - fuel sync de la server
-- ══════════════════════════════════════════════════════════════

RegisterNetEvent('showcase:client:hardRevive', function()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
        NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    end
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPlayerArmour(PlayerId(), 100)
    ClearPedBloodDamage(ped)
    AnimpostfxStop('DeathFailOut')
    notif('success', 'Reinviat')
end)

RegisterNetEvent('showcase:client:requestPlate', function(amount)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        TriggerServerEvent('showcase:server:fuelError', 'Nu ești în vehicul')
        return
    end
    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
    TriggerServerEvent('showcase:server:setFuel', plate, amount)
end)

RegisterNetEvent('showcase:client:syncFuel', function(fuel)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        local tankVol = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
        if not tankVol or tankVol <= 0 then tankVol = 65.0 end
        SetVehicleFuelLevel(veh, fuel * tankVol / 100.0)
    end
end)
