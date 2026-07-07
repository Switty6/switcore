local pullInteractions = {}

local function IsOfficerWithArrestPerm()
    if not myJob then return false end
    if myJob.name ~= 'police' or not myJob.isOnDuty then return false end
    local perms = myJob.permissions or {}
    for _, p in ipairs(perms) do
        if p == 'arrest' then return true end
    end
    return false
end

local function cleanPullInteractions()
    for _, id in pairs(pullInteractions) do
        exports.proximity:RemoveInteraction(id)
    end
    pullInteractions = {}
end

CreateThread(function()
    while true do
        Wait(1500)

        if not IsOfficerWithArrestPerm() then
            cleanPullInteractions()
            goto continue
        end

        local maxDist = 3.0
        local myPed   = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)

        local nearby = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) then
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver ~= 0 and driver ~= myPed and DoesEntityExist(driver) and IsPedAPlayer(driver) then
                    local dist = #(myCoords - GetEntityCoords(veh))
                    if dist <= maxDist then
                        nearby[veh] = true
                    end
                end
            end
        end

        for veh, id in pairs(pullInteractions) do
            if not nearby[veh] or not DoesEntityExist(veh) then
                exports.proximity:RemoveInteraction(id)
                pullInteractions[veh] = nil
            end
        end

        for veh in pairs(nearby) do
            if not pullInteractions[veh] then
                local capturedVeh = veh
                pullInteractions[veh] = exports.proximity:AddEntityInteraction(
                    veh, Sw.T('police.prox_pull_out'), 'police_pull_from_vehicle', {},
                    function()
                        local driver = GetPedInVehicleSeat(capturedVeh, -1)
                        if driver == 0 or not DoesEntityExist(driver) or not IsPedAPlayer(driver) then return end
                        local targetSrc = GetPlayerServerId(NetworkGetPlayerIndexFromPed(driver))
                        if targetSrc and targetSrc > 0 then
                            TriggerServerEvent('police:server:pullFromVehicle', targetSrc)
                        end
                    end,
                    nil, nil, maxDist
                )
            end
        end

        ::continue::
    end
end)

RegisterNetEvent('police:client:pulledFromVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 16)
        CreateThread(function()
            Wait(2000)
            if GetVehiclePedIsIn(ped, false) == veh then
                ClearPedTasksImmediately(ped)
            end
        end)
    end
    TriggerEvent('switcore:notify:local', 'warning', Sw.T('police.you_were_pulled_out'), 4000)
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    cleanPullInteractions()
end)
