local blipsData    = {}
local drawDistance = 30.0
local createdBlips = {}
local markerThread = nil

local function clearBlips()
    for _, b in ipairs(createdBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    createdBlips = {}
end

local function applyConfig(config)
    clearBlips()
    blipsData    = {}
    drawDistance = config.drawDistance or 30.0
    lastFilterCoords = vector3(99999, 99999, 99999)
    nearbyMarkers    = {}

    if not config.enabled then return end

    blipsData = config.blips or {}

    for _, entry in ipairs(blipsData) do
        local blip = AddBlipForCoord(entry.x, entry.y, entry.z)
        SetBlipSprite(blip, entry.sprite or 1)
        SetBlipColour(blip, entry.color  or 0)
        SetBlipScale(blip,  entry.scale  or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(entry.label or '')
        EndTextCommandSetBlipName(blip)
        table.insert(createdBlips, blip)
    end
end

local nearbyMarkers      = {}
local lastFilterCoords   = vector3(99999, 99999, 99999)
local FILTER_MOVE_THRESH = 10.0

local function refreshNearby(playerCoords)
    nearbyMarkers = {}
    for _, entry in ipairs(blipsData) do
        if entry.showMarker then
            local dist = #(playerCoords - vector3(entry.x, entry.y, entry.z))
            if dist <= drawDistance then
                nearbyMarkers[#nearbyMarkers + 1] = entry
            end
        end
    end
    lastFilterCoords = playerCoords
end

local function startMarkerThread()
    if markerThread then return end
    markerThread = CreateThread(function()
        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())

            if #(playerCoords - lastFilterCoords) > FILTER_MOVE_THRESH then
                refreshNearby(playerCoords)
            end

            local count = #nearbyMarkers
            for i = 1, count do
                local entry = nearbyMarkers[i]
                local mc = entry.markerColor or { r = 0, g = 180, b = 255, a = 150 }
                local ms = entry.markerScale or { x = 0.5, y = 0.5, z = 0.5 }
                DrawMarker(
                    entry.markerType or 1,
                    entry.x, entry.y, entry.z,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    ms.x, ms.y, ms.z,
                    mc.r, mc.g, mc.b, mc.a,
                    false, true, 2, false, nil, nil, false
                )
            end

            Wait(count > 0 and 0 or 500)
        end
    end)
end

RegisterNetEvent('blips:client:config', function(config)
    applyConfig(config)
    startMarkerThread()
end)

AddEventHandler('switcore:characterLoaded', function()
    TriggerServerEvent('blips:server:getConfig')
end)

RegisterNetEvent('switcore:languageChanged', function()
    TriggerServerEvent('blips:server:getConfig')
end)

CreateThread(function()
    Wait(3000)
    if #blipsData == 0 then
        TriggerServerEvent('blips:server:getConfig')
    end
end)
