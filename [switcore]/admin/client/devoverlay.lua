local overlayActive = false
local overlaySettings = {
    maxDist    = 80.0,
    showVeh    = true,
    showPed    = true,
    showObj    = false,
    showSelf   = true,

    veh = {
        model      = true,
        plate      = true,
        netId      = true,
        handle     = true,
        dist       = true,
        speed      = true,
        bodyHp     = true,
        engineHp   = true,
        coords     = false,
        heading    = false,
        occupants  = true,
        networked  = false,
    },

    ped = {
        label      = true,
        model      = true,
        netId      = true,
        handle     = true,
        dist       = true,
        hp         = true,
        armour     = true,
        heading    = false,
        weapon     = true,
        isDead     = true,
        coords     = false,
        serverId   = true,
    },

    obj = {
        model      = true,
        netId      = true,
        handle     = true,
        dist       = true,
        coords     = false,
        networked  = false,
    },

    self = {
        coords     = true,
        speed      = true,
        street     = true,
        zone       = true,
        fps        = true,
        heading    = true,
    },
}

local FPS_SAMPLES = {}
local FPS_AVG     = 0

-- 30fps: 60fps incarca CEF degeaba pentru ESP
local NUI_TICK_MS = 33

local function GetPedModelStr(hash)
    return string.format("0x%08X", hash)
end

local function GetWeaponName(hash)
    local names = {
        [0xC8A9481A] = 'Pistol',
        [0x92A27487] = 'Pistol .50',
        [0x958A4A8F] = 'SNS Pistol',
        [0x7B02597D] = 'Heavy Pistol',
        [0xBFE256D4] = 'Pistol Mk II',
        [0x1B06D571] = 'Micro SMG',
        [0x78A97CD0] = 'SMG',
        [0x2BE6766B] = 'SMG Mk II',
        [0xEFEFEFEF] = 'Assault Rifle',
        [0xBFEFFF6D] = 'Carbine Rifle',
        [0x969C3D67] = 'Advanced Rifle',
        [0x7FD62962] = 'Special Carbine',
        [0xC0A3098D] = 'Bullpup Rifle',
        [0x394F415C] = 'Assault Rifle Mk II',
        [0xA2719263] = 'Pump Shotgun',
        [0x1D073A89] = 'Sawn-Off Shotgun',
        [0xE284C527] = 'Assault Shotgun',
        [0x9D61E50F] = 'Bullpup Shotgun',
        [0xB115F450] = 'Pistol Machinegun',
        [0x05FC3C11] = 'Combat MG',
        [0xDBBD7280] = 'MG',
        [0x624FE830] = 'Minigun',
        [0xAF113F99] = 'Grenade Launcher',
        [0x020B8A8B] = 'RPG',
        [0xB1CA7A50] = 'Unarmed',
        [0xA67F7168] = 'Knife',
        [0x958FF8B5] = 'Baseball Bat',
        [0x84BD7BFD] = 'Crowbar',
        [0xF9DCBF2D] = 'Golf Club',
        [0x8BB05FD7] = 'Hammer',
        [0x4E875F73] = 'Hatchet',
        [0x99B507EA] = 'Machete',
        [0xDD5DF8D9] = 'Switchblade',
        [0x25CF03D4] = 'Wrench',
        [0x0A3D4D34] = 'Battle Axe',
        [0x274D5DF8] = 'Pool Cue',
        [0x33413532] = 'Nightstick',
        [0x3EABCE80] = 'Pipe Wrench',
        [0xF9E6AA4B] = 'Brass Knuckles',
        [0x6E460DD4] = 'Fist',
    }
    if hash == 0xA67F7168 or hash == GetHashKey('WEAPON_UNARMED') or hash == 2725352035 then
        return 'Unarmed'
    end
    return names[hash] or string.format("0x%08X", hash)
end

local function GetStreetStr(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street   = GetStreetNameFromHashKey(streetHash)
    local crossing = GetStreetNameFromHashKey(crossingHash)
    if crossing and crossing ~= '' and crossing ~= 'NULL' then
        return street .. ' / ' .. crossing
    end
    return street
end

local function BuildSelfLines(myPed, s)
    if not s.self then return nil end
    if not (s.self.coords or s.self.speed or s.self.street or s.self.zone or s.self.fps or s.self.heading) then
        return nil
    end

    local coords  = GetEntityCoords(myPed)
    local heading = math.floor(GetEntityHeading(myPed))
    local speed   = math.floor(GetEntitySpeed(myPed) * 3.6)

    local lines = {}
    if s.self.coords  then lines[#lines + 1] = { k = 'Pos',  v = string.format('%.1f  %.1f  %.1f', coords.x, coords.y, coords.z) } end
    if s.self.heading then lines[#lines + 1] = { k = 'Head', v = heading .. '°' } end
    if s.self.speed   then lines[#lines + 1] = { k = 'Spd',  v = speed .. ' km/h' } end
    if s.self.street  then lines[#lines + 1] = { k = 'St',   v = GetStreetStr(coords) or '-' } end
    if s.self.zone    then lines[#lines + 1] = { k = 'Zn',   v = GetNameOfZone(coords.x, coords.y, coords.z) or '-' } end
    if s.self.fps     then lines[#lines + 1] = { k = 'FPS',  v = tostring(math.floor(FPS_AVG)) } end

    return lines
end

local function hpClass(hp, hi, mid)
    if hp > hi then return 'good' elseif hp > mid then return 'warn' else return 'bad' end
end

local function BuildVehLines(veh, myCoords, s)
    local vs  = s.veh
    local vc  = GetEntityCoords(veh)
    local dist = #(vc - myCoords)

    local model    = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local plate    = GetVehicleNumberPlateText(veh)
    local netId    = NetworkGetNetworkIdFromEntity(veh)
    local handle   = tostring(veh)
    local speed    = math.floor(GetEntitySpeed(veh) * 3.6)
    local bodyHp   = math.floor(GetVehicleBodyHealth(veh))
    local engineHp = math.floor(GetVehicleEngineHealth(veh))
    local heading  = math.floor(GetEntityHeading(veh))
    local driver   = GetPedInVehicleSeat(veh, -1)
    local numPass  = GetVehicleNumberOfPassengers(veh)
    local isNet    = NetworkGetEntityIsNetworked(veh)

    local lines = {}
    if vs.model    then lines[#lines + 1] = { k = 'Model', v = model } end
    if vs.plate    then lines[#lines + 1] = { k = 'Plate', v = plate } end
    if vs.netId    then lines[#lines + 1] = { k = 'NetID', v = netId ~= 0 and tostring(netId) or 'local' } end
    if vs.handle   then lines[#lines + 1] = { k = 'Handle', v = handle } end
    if vs.dist     then lines[#lines + 1] = { k = 'Dist',  v = string.format('%.1fm', dist), cls = dist < 10 and 'warn' or nil } end
    if vs.speed    then lines[#lines + 1] = { k = 'Speed', v = speed .. ' km/h' } end
    if vs.bodyHp   then lines[#lines + 1] = { k = 'Body',  v = tostring(bodyHp), cls = hpClass(bodyHp, 800, 400) } end
    if vs.engineHp then lines[#lines + 1] = { k = 'Engine', v = tostring(engineHp), cls = hpClass(engineHp, 800, 400) } end
    if vs.heading  then lines[#lines + 1] = { k = 'Head',  v = heading .. '°' } end
    if vs.occupants then
        local hasDriver = driver ~= 0
        lines[#lines + 1] = { k = 'Driver', v = hasDriver and 'YES' or 'no', cls = hasDriver and 'warn' or nil }
        lines[#lines + 1] = { k = 'Pass',   v = tostring(numPass) }
    end
    if vs.networked then lines[#lines + 1] = { k = 'Netw', v = isNet and 'YES' or 'local' } end
    if vs.coords    then lines[#lines + 1] = { k = 'Pos',  v = string.format('%.1f %.1f %.1f', vc.x, vc.y, vc.z) } end

    return lines
end

local function BuildPedLines(ped, myCoords, s, isPlayer, serverId)
    local ps   = s.ped
    local pc   = GetEntityCoords(ped)
    local dist = #(pc - myCoords)

    local modelHash = GetEntityModel(ped)
    local modelStr  = isPlayer and (GetPlayerName(NetworkGetPlayerIndexFromPed(ped)) or '?') or GetPedModelStr(modelHash)
    local netId     = NetworkGetNetworkIdFromEntity(ped)
    local handle    = tostring(ped)
    local hp        = GetEntityHealth(ped) - 100
    local maxHp     = GetPedMaxHealth(ped) - 100
    local armour    = GetPedArmour(ped)
    local heading   = math.floor(GetEntityHeading(ped))
    local isDead    = IsEntityDead(ped)
    local inVeh     = IsPedInAnyVehicle(ped, false)
    local _, weapon = GetCurrentPedWeapon(ped, true)

    local lines = {}
    if ps.model then
        lines[#lines + 1] = { k = isPlayer and 'Name' or 'Model', v = modelStr }
    end
    if ps.netId then lines[#lines + 1] = { k = 'NetID', v = netId ~= 0 and tostring(netId) or 'local' } end
    if ps.handle then lines[#lines + 1] = { k = 'Handle', v = handle } end
    if ps.serverId and isPlayer and serverId then
        lines[#lines + 1] = { k = 'SrvID', v = tostring(serverId), cls = 'warn' }
    end
    if ps.dist then
        lines[#lines + 1] = { k = 'Dist', v = string.format('%.1fm', dist), cls = dist < 5 and 'bad' or nil }
    end
    if ps.hp then
        local hpPct = maxHp > 0 and (hp / maxHp) or 0
        local cls = hpPct > 0.6 and 'good' or hpPct > 0.3 and 'warn' or 'bad'
        lines[#lines + 1] = { k = 'HP', v = string.format('%d / %d', math.max(0, hp), math.max(0, maxHp)), cls = cls }
    end
    if ps.armour  then lines[#lines + 1] = { k = 'Armour', v = tostring(armour) } end
    if ps.heading then lines[#lines + 1] = { k = 'Head', v = heading .. '°' } end
    if ps.weapon  then lines[#lines + 1] = { k = 'Wpn',  v = GetWeaponName(weapon) } end
    if ps.isDead and isDead then
        lines[#lines + 1] = { k = 'State', v = 'DEAD', cls = 'bad' }
    end
    if inVeh then lines[#lines + 1] = { k = 'State', v = 'in vehicle' } end
    if ps.coords then lines[#lines + 1] = { k = 'Pos', v = string.format('%.1f %.1f %.1f', pc.x, pc.y, pc.z) } end

    return lines
end

local function BuildObjLines(obj, myCoords, s)
    local os   = s.obj
    local oc   = GetEntityCoords(obj)
    local dist = #(oc - myCoords)

    local modelHash = GetEntityModel(obj)
    local netId     = NetworkGetNetworkIdFromEntity(obj)
    local handle    = tostring(obj)
    local isNet     = NetworkGetEntityIsNetworked(obj)

    local lines = {}
    if os.model   then lines[#lines + 1] = { k = 'Model',  v = string.format('0x%08X', modelHash) } end
    if os.netId   then lines[#lines + 1] = { k = 'NetID',  v = netId ~= 0 and tostring(netId) or 'local' } end
    if os.handle  then lines[#lines + 1] = { k = 'Handle', v = handle } end
    if os.dist    then lines[#lines + 1] = { k = 'Dist',   v = string.format('%.1fm', dist) } end
    if os.networked then lines[#lines + 1] = { k = 'Netw', v = isNet and 'YES' or 'local' } end
    if os.coords  then lines[#lines + 1] = { k = 'Pos',    v = string.format('%.1f %.1f %.1f', oc.x, oc.y, oc.z) } end

    return lines
end

local function OverlayThread()
    while overlayActive do
        local myPed    = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local maxDist  = overlaySettings.maxDist or 80.0
        local s        = overlaySettings

        local dt = GetFrameTime()
        if dt > 0 then
            FPS_SAMPLES[#FPS_SAMPLES + 1] = 1.0 / dt
            if #FPS_SAMPLES > 30 then table.remove(FPS_SAMPLES, 1) end
            local sum = 0
            for _, v in ipairs(FPS_SAMPLES) do sum = sum + v end
            FPS_AVG = sum / #FPS_SAMPLES
        end

        local payload = {
            action = 'esp:update',
            labels = {},
            self   = nil,
        }

        if s.showSelf then
            local selfLines = BuildSelfLines(myPed, s)
            if selfLines then
                payload.self = { title = 'Self', lines = selfLines }
            end
        end

        local playerPeds = {}
        local playerSrvId = {}
        for _, pid in ipairs(GetActivePlayers()) do
            local ppd = GetPlayerPed(pid)
            if ppd and ppd ~= 0 then
                playerPeds[ppd]   = true
                playerSrvId[ppd]  = GetPlayerServerId(pid)
            end
        end

        if s.showVeh then
            local vehs = GetGamePool('CVehicle')
            for _, veh in ipairs(vehs) do
                if veh ~= 0 then
                    local vc   = GetEntityCoords(veh)
                    local dist = #(vc - myCoords)
                    if dist <= maxDist then
                        local onScreen, sx, sy = World3dToScreen2d(vc.x, vc.y, vc.z + 1.0)
                        if onScreen then
                            payload.labels[#payload.labels + 1] = {
                                id    = 'v' .. veh,
                                kind  = 'veh',
                                title = 'Vehicle',
                                x     = sx,
                                y     = sy,
                                lines = BuildVehLines(veh, myCoords, s),
                            }
                        end
                    end
                end
            end
        end

        if s.showPed then
            local peds = GetGamePool('CPed')
            for _, ped in ipairs(peds) do
                if ped ~= 0 and ped ~= myPed then
                    local pc   = GetEntityCoords(ped)
                    local dist = #(pc - myCoords)
                    if dist <= maxDist then
                        local onScreen, sx, sy = World3dToScreen2d(pc.x, pc.y, pc.z + 1.0)
                        if onScreen then
                            local isPlayer = playerPeds[ped] == true
                            local srvId    = playerSrvId[ped]
                            payload.labels[#payload.labels + 1] = {
                                id    = 'p' .. ped,
                                kind  = isPlayer and 'player' or 'ped',
                                title = isPlayer and 'Player' or 'Ped',
                                x     = sx,
                                y     = sy,
                                lines = BuildPedLines(ped, myCoords, s, isPlayer, srvId),
                            }
                        end
                    end
                end
            end
        end

        if s.showObj then
            local objs = GetGamePool('CObject')
            local drawn = 0
            for _, obj in ipairs(objs) do
                if drawn >= 50 then break end
                if obj ~= 0 then
                    local oc   = GetEntityCoords(obj)
                    local dist = #(oc - myCoords)
                    if dist <= maxDist then
                        local onScreen, sx, sy = World3dToScreen2d(oc.x, oc.y, oc.z + 0.5)
                        if onScreen then
                            payload.labels[#payload.labels + 1] = {
                                id    = 'o' .. obj,
                                kind  = 'obj',
                                title = 'Object',
                                x     = sx,
                                y     = sy,
                                lines = BuildObjLines(obj, myCoords, s),
                            }
                            drawn = drawn + 1
                        end
                    end
                end
            end
        end

        SendNUIMessage(payload)
        Wait(NUI_TICK_MS)
    end

    SendNUIMessage({ action = 'esp:update', labels = {}, self = nil })
    SendNUIMessage({ action = 'esp:setActive', active = false })
end

function IsOverlayActive()
    return overlayActive
end

function ToggleOverlay()
    overlayActive = not overlayActive
    SendNUIMessage({ action = 'esp:setActive', active = overlayActive })
    if overlayActive then
        CreateThread(OverlayThread)
    end
    return overlayActive
end

function SetOverlayActive(state)
    local wasActive = overlayActive
    overlayActive = state
    SendNUIMessage({ action = 'esp:setActive', active = state })
    if state and not wasActive then
        CreateThread(OverlayThread)
    end
end

function ApplyOverlaySettings(newSettings)
    local function merge(dst, src)
        for k, v in pairs(src) do
            if type(v) == 'table' and type(dst[k]) == 'table' then
                merge(dst[k], v)
            else
                dst[k] = v
            end
        end
    end
    merge(overlaySettings, newSettings)
end

function GetOverlaySettings()
    return overlaySettings
end

function SaveOverlayKVP()
    local ok, encoded = pcall(json.encode, overlaySettings)
    if ok then
        SetResourceKvp('devoverlay_settings', encoded)
    end
end

function LoadOverlayKVP()
    local raw = GetResourceKvpString('devoverlay_settings')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            ApplyOverlaySettings(decoded)
        end
    end
end

LoadOverlayKVP()
