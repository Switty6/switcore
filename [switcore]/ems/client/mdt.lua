RegisterNetEvent('ems:client:newUnconsciousPlayer')
AddEventHandler('ems:client:newUnconsciousPlayer', function(data)
    if isEMS and emsOnDuty then
        exports.notifications:Notify('warning',
            Sw.T('ems.patient_unconscious', data.name or Sw.T('ems.patient_unknown')), 8000)
        local blip = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(blip, 153)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.9)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Sw.T('ems.blip_patient', data.name or '?'))
        EndTextCommandSetBlipName(blip)
        CreateThread(function()
            Wait(180000)
            RemoveBlip(blip)
        end)
    end
end)
