local NPC_SPAWN_LOCATIONS = {
    { x =  -68.5,   y = -1763.5, z = 29.3,  name = 'Compania de Taxi'     },
    { x =  441.1,   y =  -981.9, z = 30.7,  name = 'Centrul Comercial'    },
    { x = -248.0,   y =  -338.2, z = 35.5,  name = 'Spital'               },
    { x = -1393.0,  y =  -580.9, z = 30.0,  name = 'Little Seoul'         },
    { x =  378.5,   y = -1601.0, z = 29.3,  name = 'Strawberry'           },
    { x =  147.0,   y = -1040.0, z = 29.3,  name = 'Forum Drive'          },
    { x = -718.0,   y =  -241.0, z = 37.5,  name = 'Hawick'               },
}

local NPC_DESTINATIONS = {
    { x = -1038.2, y = -2735.0, z = 20.2,  label = 'Aeroportul Los Santos' },
    { x =  441.1,  y =  -981.9, z = 30.7,  label = 'Centrul Comercial'     },
    { x = -549.0,  y =  -191.4, z = 37.9,  label = 'Banca Maze'            },
    { x = -279.0,  y =  -967.0, z = 31.2,  label = 'Primaria'              },
    { x = -1293.0, y =  -770.0, z = 17.5,  label = 'Del Perro Plaja'       },
    { x =  -74.7,  y =  -820.0, z = 326.2, label = 'Vinewood Hills'        },
    { x = 1694.6,  y =  4831.0, z = 42.1,  label = 'Sandy Shores'          },
    { x = -272.5,  y =  6230.4, z = 31.4,  label = 'Paleto Bay'            },
    { x = 1086.5,  y = -2368.1, z = 30.0,  label = 'Plaja de Sud'          },
    { x = -1260.0, y =  -350.5, z = 37.8,  label = 'Vinewood Blvd'         },
}

local NPC_PED_MODELS = {
    'a_f_m_business_02', 'a_m_m_business_01', 'a_f_y_tourist_01',
    'a_m_y_tourist_01',  'a_f_m_fatwhite_01', 'a_m_m_farmer_01',
    'a_f_y_bevhills_01', 'a_m_y_bevhills_01', 'a_f_m_prolhost_01',
}

local PICKUP_NORMAL = {
    'Multumesc! Poti sa ma duci la %s?',
    'In sfarsit un taxi! Trebuie sa ajung la %s.',
    'Buna! Destinatia mea este %s.',
    'Buna ziua! Poti sa ma duci la %s?',
    'Am asteptat mult. Ma poti duce la %s?',
}
local PICKUP_URGENT = {
    'Urgent! Trebuie sa ajung la %s cat mai repede!',
    'Va rog, ma grabesc! %s, acum!',
    'Este o urgenta! Poti sa accelerezi spre %s?',
}
local DROPOFF_NORMAL = {
    'Multumesc pentru cursa!',
    'Excelent! La revedere!',
    'Chiar apreciez ajutorul!',
    'O zi buna iti doresc!',
    'Grozav, multumesc mult!',
}
local DROPOFF_FAST = {
    'Ai condus excelent, iti las un bacsis!',
    'Impresionant! Meriti un bacsis!',
    'Ai ajuns repede, multumesc cu bacsis!',
}

local MAX_NPC_FARES  = 2
local ENTER_TIMEOUT  = 12000   -- ms

local npcList   = {}
local npcOnDuty = false

local function notify(t, msg)
    TriggerEvent('notifications:client:send', {
        type = t, title = 'Taxi', message = msg, duration = 5000
    })
end

local function countActiveNpcs()
    local n = 0
    for _, npc in ipairs(npcList) do
        if npc.status ~= 'done' and DoesEntityExist(npc.ped) then
            n = n + 1
        end
    end
    return n
end

local function purgeFinishedNpcs()
    local alive = {}
    for _, npc in ipairs(npcList) do
        if npc.status ~= 'done' and DoesEntityExist(npc.ped) then
            table.insert(alive, npc)
        end
    end
    npcList = alive
end

local function cleanupNpc(npc)
    if npc.proxId     then exports.proximity:RemoveInteraction(npc.proxId)    end
    if npc.destProxId then exports.proximity:RemoveInteraction(npc.destProxId) end
    if npc.blip and DoesBlipExist(npc.blip) then RemoveBlip(npc.blip) end
    npc.status = 'done'
    CreateThread(function()
        Wait(4000)
        if DoesEntityExist(npc.ped) then
            SetEntityAsMissionEntity(npc.ped, false, true)
            DeletePed(npc.ped)
        end
    end)
end

local function isDriverOfTaxi()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false, nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return false, nil end
    return true, veh
end

local function onNpcDropoff(npc)
    if npc.status ~= 'riding' then return end
    npc.status = 'done'

    if npc.destProxId then
        exports.proximity:RemoveInteraction(npc.destProxId)
        npc.destProxId = nil
    end

    local _, veh = isDriverOfTaxi()
    if veh and DoesEntityExist(npc.ped) then
        TaskLeaveVehicle(npc.ped, veh, 0)
    end

    -- GTA world units * 0.001 ≈ km
    local dx     = (npc.dest.x - npc.spawn.x) * 0.001
    local dy     = (npc.dest.y - npc.spawn.y) * 0.001
    local distKm = math.max(0.2, math.sqrt(dx * dx + dy * dy))

    -- Urgent fares pay 1.5x base
    local multiplier = npc.isUrgent and 1.5 or 1.0

    -- Speed tip: delivering under 90s per km grants a 10-25% bonus
    local elapsedSec    = npc.pickupTime and ((GetGameTimer() - npc.pickupTime) / 1000) or 9999
    local fastThreshold = distKm * 90
    if elapsedSec < fastThreshold then
        local tip = math.random(10, 25) / 100
        multiplier = multiplier + tip
        local msg = DROPOFF_FAST[math.random(#DROPOFF_FAST)]
        notify('success', msg .. string.format(' (+%.0f%%)', tip * 100))
    else
        notify('info', DROPOFF_NORMAL[math.random(#DROPOFF_NORMAL)])
    end

    TriggerServerEvent('taxi:server:npcRideComplete', distKm, multiplier)
    ClearGpsPlayerWaypoint()

    CreateThread(function()
        Wait(5000)
        if DoesEntityExist(npc.ped) then
            SetEntityAsMissionEntity(npc.ped, false, true)
            DeletePed(npc.ped)
        end
    end)
end

local function onNpcPickup(npc)
    if npc.status ~= 'waiting' then return end

    local driving, veh = isDriverOfTaxi()
    if not driving then
        notify('warning', 'Trebuie sa fii la volanul masinii de taxi.')
        return
    end

    npc.status         = 'entering'
    npc.patientExpired = true   -- prevents the patience thread from despawning him

    if npc.proxId then
        exports.proximity:RemoveInteraction(npc.proxId)
        npc.proxId = nil
    end
    if npc.blip and DoesBlipExist(npc.blip) then
        RemoveBlip(npc.blip)
        npc.blip = nil
    end

    SetBlockingOfNonTemporaryEvents(npc.ped, false)
    TaskEnterVehicle(npc.ped, veh, ENTER_TIMEOUT, 0, 2.0, 1, 0)

    local template = npc.isUrgent
        and PICKUP_URGENT[math.random(#PICKUP_URGENT)]
        or  PICKUP_NORMAL[math.random(#PICKUP_NORMAL)]
    notify(npc.isUrgent and 'warning' or 'info',
        string.format(template, npc.dest.label))

    CreateThread(function()
        local elapsed = 0
        while elapsed < ENTER_TIMEOUT do
            Wait(300)
            elapsed = elapsed + 300
            if not DoesEntityExist(npc.ped) then return end
            if IsPedInVehicle(npc.ped, veh, false) then
                npc.status     = 'riding'
                npc.pickupTime = GetGameTimer()
                SetBlockingOfNonTemporaryEvents(npc.ped, true)

                SetNewWaypoint(npc.dest.x, npc.dest.y)

                local capturedNpc = npc
                local destProxId  = 'taxi_npc_dest_' .. npc.ped
                exports.proximity:AddInteraction(
                    vector3(npc.dest.x, npc.dest.y, npc.dest.z),
                    'Coboara Pasager - ' .. npc.dest.label,
                    destProxId,
                    {},
                    function() onNpcDropoff(capturedNpc) end
                )
                npc.destProxId = destProxId
                return
            end
        end

        -- ENTER_TIMEOUT elapsed; abandon this NPC
        npc.status = 'done'
        SetEntityAsMissionEntity(npc.ped, false, true)
        if DoesEntityExist(npc.ped) then DeletePed(npc.ped) end
    end)
end

local function spawnNpc(spawnData)
    local isUrgent = math.random(100) <= 20          -- 20% chance for urgent fare
    local patience = math.random(150, 360)            -- seconds until NPC leaves on his own

    local modelName = NPC_PED_MODELS[math.random(#NPC_PED_MODELS)]
    local model     = GetHashKey(modelName)

    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) do
        Wait(50); t = t + 50
        if t > 6000 then SetModelAsNoLongerNeeded(model) return end
    end

    local heading = math.random(0, 359) * 1.0

    local ped = CreatePed(4, model,
        spawnData.x, spawnData.y, spawnData.z - 1.0,
        heading, false, true)

    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)

    -- Urgent fares always use the impatient scenario
    if isUrgent then
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    else
        local scenarios = {
            'WORLD_HUMAN_STAND_IMPATIENT',
            'WORLD_HUMAN_LOOK_AT_PHONE',
            'WORLD_HUMAN_TOURIST_MAP',
        }
        TaskStartScenarioInPlace(ped, scenarios[math.random(#scenarios)], 0, true)
    end

    -- Urgent fares get a larger red blip; normal fares are yellow
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 198)
    SetBlipColour(blip, isUrgent and 1 or 2)
    SetBlipScale(blip, isUrgent and 0.7 or 0.55)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString((isUrgent and '[URGENT] ' or '') .. 'Pasager NPC - ' .. spawnData.name)
    EndTextCommandSetBlipName(blip)

    local dest = NPC_DESTINATIONS[math.random(#NPC_DESTINATIONS)]

    local npc = {
        ped            = ped,
        blip           = blip,
        spawn          = spawnData,
        dest           = dest,
        status         = 'waiting',
        isUrgent       = isUrgent,
        patience       = patience,
        patientExpired = false,
        pickupTime     = nil,
        proxId         = nil,
        destProxId     = nil,
    }

    local capturedNpc = npc
    local proxId      = 'taxi_npc_' .. tostring(ped)
    exports.proximity:AddInteraction(
        vector3(spawnData.x, spawnData.y, spawnData.z),
        (isUrgent and '[URGENT] ' or '') .. 'Ridica Pasager - ' .. spawnData.name,
        proxId,
        {},
        function() onNpcPickup(capturedNpc) end
    )
    npc.proxId = proxId

    table.insert(npcList, npc)

    CreateThread(function()
        Wait(patience * 1000)
        if npc.status == 'waiting' and not npc.patientExpired then
            cleanupNpc(npc)
        end
    end)
end

-- Periodic spawn loop: 25-65s interval while on duty
CreateThread(function()
    while true do
        Wait(math.random(25000, 65000))

        if not npcOnDuty then goto continue end

        purgeFinishedNpcs()

        if countActiveNpcs() < MAX_NPC_FARES then
            local loc = NPC_SPAWN_LOCATIONS[math.random(#NPC_SPAWN_LOCATIONS)]
            spawnNpc(loc)
        end

        ::continue::
    end
end)

local function firstSpawn()
    Wait(8000)
    if not npcOnDuty then return end
    purgeFinishedNpcs()
    if countActiveNpcs() < MAX_NPC_FARES then
        local loc = NPC_SPAWN_LOCATIONS[math.random(#NPC_SPAWN_LOCATIONS)]
        spawnNpc(loc)
    end
end

AddEventHandler('jobs:client:jobUpdated', function(job)
    local wasDuty = npcOnDuty
    npcOnDuty = (job and job.name == Config.JobName and job.isOnDuty) == true

    if not npcOnDuty and wasDuty then
        for _, npc in ipairs(npcList) do
            cleanupNpc(npc)
        end
        npcList = {}
    elseif npcOnDuty and not wasDuty then
        CreateThread(firstSpawn)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    for _, npc in ipairs(npcList) do
        if npc.proxId     then exports.proximity:RemoveInteraction(npc.proxId)     end
        if npc.destProxId then exports.proximity:RemoveInteraction(npc.destProxId) end
        if npc.blip and DoesBlipExist(npc.blip) then RemoveBlip(npc.blip) end
        if DoesEntityExist(npc.ped) then
            SetEntityAsMissionEntity(npc.ped, false, true)
            DeletePed(npc.ped)
        end
    end
end)
