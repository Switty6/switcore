local activeCallBlips = {}
local activeCallId    = nil
local clientBlip      = nil

RegisterNetEvent('mecanic:client:newServiceCall', function(data)
    if not isMechanic or not myJob or not myJob.isOnDuty then return end

    TriggerEvent('notifications:client:send', {
        type     = 'info',
        title    = Sw.T('mecanic.roadside.call_title'),
        message  = Sw.T('mecanic.roadside.call_msg', data.clientName, ProblemLabel(data.problemType)),
        duration = 10000
    })

    if data.location then
        local b = AddBlipForCoord(data.location.x, data.location.y, data.location.z)
        SetBlipSprite(b, 1)
        SetBlipColour(b, 2)
        SetBlipScale(b, 0.9)
        SetBlipAsShortRange(b, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Sw.T('mecanic.roadside.blip_call_name', data.clientName or '?'))
        EndTextCommandSetBlipName(b)
        activeCallBlips[data.id] = b
    end

    SendNUIMessage({ action = 'newCall', call = data })

    -- Auto-expire blip dupa 120s daca nu a fost acceptat
    SetTimeout(120000, function()
        if activeCallBlips[data.id] then
            if DoesBlipExist(activeCallBlips[data.id]) then
                RemoveBlip(activeCallBlips[data.id])
            end
            activeCallBlips[data.id] = nil
        end
    end)
end)

RegisterNetEvent('mecanic:client:callAccepted', function(data)
    activeCallId = data.callId

    if data.location then
        SetNewWaypoint(data.location.x, data.location.y)
    end

    if clientBlip and DoesBlipExist(clientBlip) then RemoveBlip(clientBlip) end
    if data.location then
        clientBlip = AddBlipForCoord(data.location.x, data.location.y, data.location.z)
        SetBlipSprite(clientBlip, 1)
        SetBlipColour(clientBlip, 2)
        SetBlipScale(clientBlip, 1.0)
        SetBlipRoute(clientBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Sw.T('mecanic.roadside.blip_client_name'))
        EndTextCommandSetBlipName(clientBlip)
    end

    if activeCallBlips[data.callId] then
        if DoesBlipExist(activeCallBlips[data.callId]) then
            RemoveBlip(activeCallBlips[data.callId])
        end
        activeCallBlips[data.callId] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if not isMechanic or not activeCallId or not clientBlip then goto continue end

        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        if clientBlip and DoesBlipExist(clientBlip) then
            local blipCoords = GetBlipInfoIdCoord(clientBlip)
            local dist = #(pos - vector3(blipCoords.x, blipCoords.y, blipCoords.z))

            if dist <= 10.0 then
                TriggerEvent('notifications:client:send', {
                    type='success', title=Sw.T('mecanic.roadside.arrived_title'),
                    message=Sw.T('mecanic.roadside.arrived_msg'),
                    duration=6000
                })
                if clientBlip and DoesBlipExist(clientBlip) then
                    SetBlipRoute(clientBlip, false)
                end
                Wait(5000)
            end
        end

        ::continue::
    end
end)

RegisterNetEvent('mecanic:client:vehicleTowed', function(data)
    if clientBlip and DoesBlipExist(clientBlip) then
        RemoveBlip(clientBlip)
        clientBlip = nil
    end
    activeCallId = nil
    TriggerEvent('notifications:client:send', {
        type='success', title=Sw.T('mecanic.roadside.tow_done_title'),
        message=Sw.T('mecanic.roadside.tow_done_msg'), duration=6000
    })
end)

RegisterNUICallback('roadsideDone', function(_, cb)
    if clientBlip and DoesBlipExist(clientBlip) then
        RemoveBlip(clientBlip)
        clientBlip = nil
    end
    activeCallId = nil
    cb('ok')
end)

function ProblemLabel(problemType)
    local valid = { engine = true, tire = true, battery = true, tow = true }
    if valid[problemType] then
        return Sw.T('mecanic.problem.' .. problemType)
    end
    return problemType
end
