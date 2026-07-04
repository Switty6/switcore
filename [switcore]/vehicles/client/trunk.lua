-- Portbagaj (proximitate, oricine se apropie) + torpedou (comanda, doar cel
-- din scaunele fata). Serverul e singurul care verifica daca jucatorul are
-- cheia (vehicles:server:openVehicleStorage) - aici doar afisam promptul.
local TRUNK_PROX_DIST = 2.5
local trunkInteractions = {}
local openTrunkVehicle  = nil
local openTrunkPlate    = nil

local function CleanupTrunkInteractions()
    for _, id in pairs(trunkInteractions) do
        exports.proximity:RemoveInteraction(id)
    end
    trunkInteractions = {}
end

local function CloseTrunkIfAny()
    if openTrunkVehicle and DoesEntityExist(openTrunkVehicle) then
        SetVehicleDoorShut(openTrunkVehicle, 5, false)
    end
    openTrunkVehicle = nil
    openTrunkPlate   = nil
end

local function OpenTrunk(plate, vehicle)
    CloseTrunkIfAny()
    openTrunkVehicle = vehicle
    openTrunkPlate   = plate
    if DoesEntityExist(vehicle) then
        SetVehicleDoorOpen(vehicle, 5, false, false)
    end
    TriggerServerEvent('vehicles:server:openVehicleStorage', plate, 'trunk')
end

RegisterNetEvent('vehicles:client:openVehicleStorage', function(invId)
    exports.inventory:OpenSecondaryInventory()
end)

RegisterCommand('glovebox', function()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped and GetPedInVehicleSeat(vehicle, 0) ~= ped then return end

    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    TriggerServerEvent('vehicles:server:openVehicleStorage', plate, 'glove')
end, false)
RegisterKeyMapping('glovebox', Sw.T('vehicles.keymap_glovebox'), 'keyboard', 'b')

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        -- Inchide portbagajul deschis daca ne indepartam prea mult
        if openTrunkVehicle then
            if not DoesEntityExist(openTrunkVehicle) or #(pos - GetEntityCoords(openTrunkVehicle)) > 8.0 then
                CloseTrunkIfAny()
            end
        end

        if IsPedInAnyVehicle(ped, false) then
            CleanupTrunkInteractions()
            goto continue
        end

        local nearby = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) then
                local vp = GetEntityCoords(veh)
                if #(pos - vp) <= TRUNK_PROX_DIST + 3.0 then
                    local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                    nearby[plate] = veh
                end
            end
        end

        for plate, veh in pairs(nearby) do
            if not trunkInteractions[plate] then
                local capturedPlate  = plate
                local capturedEntity = veh
                trunkInteractions[plate] = exports.proximity:AddEntityInteraction(
                    veh, Sw.T('vehicles.prox_open_trunk'), 'vehicle_trunk', {},
                    function() OpenTrunk(capturedPlate, capturedEntity) end,
                    nil, nil, TRUNK_PROX_DIST
                )
            end
        end

        for plate, id in pairs(trunkInteractions) do
            if not nearby[plate] then
                exports.proximity:RemoveInteraction(id)
                trunkInteractions[plate] = nil
            end
        end

        ::continue::
    end
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    CleanupTrunkInteractions()
    CloseTrunkIfAny()
end)
