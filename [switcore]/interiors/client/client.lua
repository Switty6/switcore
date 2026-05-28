-- entrance = coords in fata usii (trigger zona)
-- interiorCoords = coords INSIDE pentru GetInteriorAtCoords
-- ipl = lista de IPL-uri de incarcat (optional)
-- props = lista de entity sets de activat (optional)
-- triggerDistance = distanta la care se incarca (default 40.0)
-- unloadDistance  = distanta la care se descarca (default 120.0)
-- alwaysLoaded    = nu se descarca niciodata dupa prima incarcare

local DEFAULT_TRIGGER_DISTANCE = 40.0
local DEFAULT_UNLOAD_DISTANCE  = 120.0
local CHECK_INTERVAL           = 1500


local PREDEFINED_INTERIORS = {
    {
        id              = 'pdm_showroom',
        name            = 'PDM Showroom',
        entrance        = vector3(-43.65, -1098.73, 26.42),
        interiorCoords  = vector3(-21.0, -1101.0, 28.0),
        ipl             = { 'shr_int' },
        triggerDistance = 60.0,
        alwaysLoaded    = true,
    },

    {
        id             = 'mrpd',
        name           = 'Mission Row PD',
        entrance       = vector3(428.23, -982.21, 29.69),
        interiorCoords = vector3(456.9, -982.0, 30.69),
        triggerDistance = 50.0,
    },

    {
        id             = 'pillbox_hospital',
        name           = 'Pillbox Hospital',
        entrance       = vector3(295.6, -592.0, 43.28),
        interiorCoords = vector3(295.6, -592.0, 43.28),
        triggerDistance = 50.0,
    },

    {
        id             = 'sandy_medical',
        name           = 'Sandy Shores Medical',
        entrance       = vector3(1839.6, 3672.9, 34.28),
        interiorCoords = vector3(1839.6, 3672.9, 34.28),
        triggerDistance = 40.0,
    },

    {
        id             = 'bank_hawick',
        name           = 'Fleeca Bank Hawick',
        entrance       = vector3(-350.14, -50.37, 49.04),
        interiorCoords = vector3(-350.14, -50.37, 49.04),
        triggerDistance = 20.0,
    },

    {
        id             = 'bank_vinewood',
        name           = 'Fleeca Bank Vinewood',
        entrance       = vector3(149.27, -1040.47, 29.37),
        interiorCoords = vector3(149.27, -1040.47, 29.37),
        triggerDistance = 20.0,
    },

    {
        id             = 'paleto_pd',
        name           = 'Paleto Bay PD',
        entrance       = vector3(-448.34, 6008.27, 31.72),
        interiorCoords = vector3(-448.34, 6008.27, 31.72),
        triggerDistance = 40.0,
    },

    {
        id             = 'bcso',
        name           = 'Blaine County Sheriff',
        entrance       = vector3(1852.95, 3686.64, 34.27),
        interiorCoords = vector3(1852.95, 3686.64, 34.27),
        triggerDistance = 40.0,
    },

    {
        id             = 'maze_bank_arena',
        name           = 'Maze Bank Arena',
        entrance       = vector3(-248.15, -2026.64, 27.34),
        interiorCoords = vector3(-248.15, -2026.64, 27.34),
        ipl            = { 'dt1_03_mba_gr_entrance' },
        triggerDistance = 60.0,
    },
}

local registeredInteriors = {}  
local loadedState         = {}  

local function DoLoadInterior(interior)
    if interior.ipl then
        for _, iplName in ipairs(interior.ipl) do
            if not IsIplActive(iplName) then
                RequestIpl(iplName)
            end
        end
    end

    if interior.interiorCoords then
        CreateThread(function()
            local c = interior.interiorCoords
            local interiorId = 0
            local retries = 0
            while (interiorId == 0 or interiorId == -1) and retries < 30 do
                interiorId = GetInteriorAtCoords(c.x, c.y, c.z)
                if interiorId == 0 or interiorId == -1 then
                    Wait(100)
                    retries = retries + 1
                end
            end
            if interiorId == 0 or interiorId == -1 then
                print(('[INTERIORS] Nu s-a gasit interior la coords pentru: %s'):format(interior.id))
                return
            end
            if not IsInteriorReady(interiorId) then
                LoadInterior(interiorId)
                local timeout = 0
                while not IsInteriorReady(interiorId) and timeout < 200 do
                    Wait(50)
                    timeout = timeout + 1
                end
                if timeout >= 200 then
                    print(('[INTERIORS] Timeout la incarcare: %s'):format(interior.id))
                end
            end
            if interior.props then
                for _, prop in ipairs(interior.props) do
                    EnableInteriorProp(interiorId, prop)
                end
            end
            RefreshInterior(interiorId)
        end)
    end
end

local function DoUnloadInterior(interior)
    if interior.alwaysLoaded then return end

    if interior.ipl then
        for _, iplName in ipairs(interior.ipl) do
            if IsIplActive(iplName) then
                RemoveIpl(iplName)
            end
        end
    end
end

CreateThread(function()
    Wait(2000)  
    for _, def in ipairs(PREDEFINED_INTERIORS) do
        registeredInteriors[def.id] = def
    end

    while true do
        local ped = PlayerPedId()
        if ped ~= 0 then
            local pos = GetEntityCoords(ped)

            for id, interior in pairs(registeredInteriors) do
                local dist = #(pos - interior.entrance)
                local trigDist   = interior.triggerDistance  or DEFAULT_TRIGGER_DISTANCE
                local unloadDist = interior.unloadDistance   or DEFAULT_UNLOAD_DISTANCE

                if dist <= trigDist and not loadedState[id] then
                    loadedState[id] = true
                    DoLoadInterior(interior)

                elseif dist > unloadDist and loadedState[id] and not interior.alwaysLoaded then
                    loadedState[id] = false
                    DoUnloadInterior(interior)
                end
            end
        end

        Wait(CHECK_INTERVAL)
    end
end)

exports('RegisterInterior', function(data)
    if not data or not data.id or not data.entrance then
        print('[INTERIORS] RegisterInterior: lipsesc campuri obligatorii (id, entrance)')
        return false
    end
    if type(data.entrance) ~= 'vector3' then
        data.entrance = vector3(data.entrance.x, data.entrance.y, data.entrance.z)
    end
    if data.interiorCoords and type(data.interiorCoords) ~= 'vector3' then
        data.interiorCoords = vector3(data.interiorCoords.x, data.interiorCoords.y, data.interiorCoords.z)
    end
    registeredInteriors[data.id] = data
    return true
end)

exports('UnregisterInterior', function(id)
    if registeredInteriors[id] then
        if loadedState[id] then DoUnloadInterior(registeredInteriors[id]) end
        registeredInteriors[id] = nil
        loadedState[id] = nil
        return true
    end
    return false
end)

exports('ForceLoadInterior', function(id)
    local interior = registeredInteriors[id]
    if not interior then return false end
    loadedState[id] = true
    DoLoadInterior(interior)
    return true
end)

exports('IsInteriorLoaded', function(id)
    return loadedState[id] == true
end)

print('[INTERIORS] Sistem interioare initializat cu ' .. #PREDEFINED_INTERIORS .. ' interioare predefinite')
