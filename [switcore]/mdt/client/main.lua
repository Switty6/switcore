-- Unified MDT for police + EMS.
-- Owns the NUI page - all NUI callbacks live here.

local isMDTOpen = false
local currentJob = nil   -- updated by jobs:client:jobUpdated

RegisterNetEvent('jobs:client:jobUpdated')
AddEventHandler('jobs:client:jobUpdated', function(job)
    currentJob = job
    if isMDTOpen and (not job or not job.isOnDuty) then
        CloseMDT()
    end
end)

local function CloseMDT()
    if not isMDTOpen then return end
    isMDTOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMDT' })
end

local function OpenMDT()
    if isMDTOpen then CloseMDT(); return end
    if not currentJob or not currentJob.isOnDuty then return end

    local jobName = currentJob.name

    if jobName == 'police' then
        TriggerServerEvent('police:server:openMDT')
    elseif jobName == 'ems' then
        isMDTOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openMDT', jobName = 'ems' })
        TriggerServerEvent('ems:server:getCalls')
        TriggerServerEvent('ems:server:getOnDutyEMS')
    end
end

RegisterKeyMapping('mdt:open', 'Deschide MDT', 'keyboard', 'F6')
RegisterCommand('mdt:open', function()
    OpenMDT()
end, false)

RegisterNUICallback('closeMDT', function(_, cb)
    CloseMDT()
    cb('ok')
end)

RegisterNUICallback('mdtSearch', function(data, cb)
    TriggerServerEvent('police:server:searchCharacter', data.query)
    cb('ok')
end)

RegisterNUICallback('createWarrant', function(data, cb)
    TriggerServerEvent('police:server:createWarrant', data.characterId, data.charges, data.bailAmount)
    cb('ok')
end)

RegisterNUICallback('closeWarrant', function(data, cb)
    TriggerServerEvent('police:server:closeWarrant', data.warrantId)
    cb('ok')
end)

RegisterNUICallback('getOnDutyOfficers', function(_, cb)
    TriggerServerEvent('police:server:getOnDutyOfficers')
    cb('ok')
end)

RegisterNUICallback('unjailEarly', function(data, cb)
    TriggerServerEvent('police:server:unjailEarly', data.characterId)
    cb('ok')
end)

RegisterNUICallback('getCriminalHistory', function(data, cb)
    TriggerServerEvent('mdt:server:getCriminalHistory', data)
    cb('ok')
end)

RegisterNUICallback('createCitation', function(data, cb)
    TriggerServerEvent('mdt:server:createCitation', data)
    cb('ok')
end)

RegisterNUICallback('getCitations', function(_, cb)
    TriggerServerEvent('mdt:server:getCitations')
    cb('ok')
end)

RegisterNUICallback('payCitationOfficer', function(data, cb)
    TriggerServerEvent('mdt:server:payCitationOfficer', data)
    cb('ok')
end)

RegisterNUICallback('createBOLO', function(data, cb)
    TriggerServerEvent('mdt:server:createBOLO', data)
    cb('ok')
end)

RegisterNUICallback('getActiveBOLOs', function(_, cb)
    TriggerServerEvent('mdt:server:getActiveBOLOs')
    cb('ok')
end)

RegisterNUICallback('closeBOLO', function(data, cb)
    TriggerServerEvent('mdt:server:closeBOLO', data)
    cb('ok')
end)

RegisterNUICallback('createIncident', function(data, cb)
    TriggerServerEvent('mdt:server:createIncident', data)
    cb('ok')
end)

RegisterNUICallback('getIncidents', function(_, cb)
    TriggerServerEvent('mdt:server:getIncidents')
    cb('ok')
end)

RegisterNUICallback('impoundVehicle', function(data, cb)
    TriggerServerEvent('mdt:server:impoundVehicle', data)
    cb('ok')
end)

RegisterNUICallback('getImpounds', function(_, cb)
    TriggerServerEvent('mdt:server:getImpounds')
    cb('ok')
end)

RegisterNUICallback('retrieveImpound', function(data, cb)
    TriggerServerEvent('mdt:server:retrieveImpound', data)
    cb('ok')
end)

RegisterNUICallback('purchaseFleetVehicle', function(data, cb)
    TriggerServerEvent('police:server:purchaseFleetVehicle', data.model)
    cb('ok')
end)

RegisterNUICallback('sellFleetVehicle', function(data, cb)
    TriggerServerEvent('police:server:sellFleetVehicle', data.vehicleId)
    cb('ok')
end)

RegisterNUICallback('addArmoryWeapon', function(data, cb)
    TriggerServerEvent('police:server:addArmoryWeapon', data.itemName, data.label, data.ammoItem, data.ammoAmount)
    cb('ok')
end)

RegisterNUICallback('removeArmoryWeapon', function(data, cb)
    TriggerServerEvent('police:server:removeArmoryWeapon', data.itemName)
    cb('ok')
end)

RegisterNUICallback('addArmoryEquipment', function(data, cb)
    TriggerServerEvent('police:server:addArmoryEquipment', data.itemName, data.label, data.amount)
    cb('ok')
end)

RegisterNUICallback('removeArmoryEquipment', function(data, cb)
    TriggerServerEvent('police:server:removeArmoryEquipment', data.itemName)
    cb('ok')
end)

RegisterNUICallback('getCalls', function(_, cb)
    TriggerServerEvent('ems:server:getCalls')
    cb('ok')
end)

RegisterNUICallback('acceptCall', function(data, cb)
    TriggerServerEvent('ems:server:acceptCall', data.callId)
    cb('ok')
end)

RegisterNUICallback('resolveCall', function(data, cb)
    TriggerServerEvent('ems:server:resolveCall', data.callId)
    cb('ok')
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    SetNewWaypoint(data.x, data.y)
    exports.notifications:Notify('info', 'Waypoint setat la locatia apelului.', 3000)
    cb('ok')
end)

RegisterNUICallback('searchPatient', function(data, cb)
    TriggerServerEvent('ems:server:searchPatient', data.query)
    cb('ok')
end)

RegisterNUICallback('getPatientHistory', function(data, cb)
    TriggerServerEvent('ems:server:getPatientHistory', data.characterId)
    cb('ok')
end)

RegisterNUICallback('getOnDutyEMS', function(_, cb)
    TriggerServerEvent('ems:server:getOnDutyEMS')
    cb('ok')
end)

RegisterNetEvent('police:client:mdtData')
AddEventHandler('police:client:mdtData', function(data)
    isMDTOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action     = 'openMDT',
        jobName    = 'police',
        warrants   = data.warrants   or {},
        officers   = data.officers   or {},
        canManage  = data.canManage  or false,
        management = data.management or nil
    })
end)

RegisterNetEvent('police:client:searchResults')
AddEventHandler('police:client:searchResults', function(results)
    SendNUIMessage({ action = 'searchResults', results = results or {} })
end)

RegisterNetEvent('police:client:warrantCreated')
AddEventHandler('police:client:warrantCreated', function(warrant)
    SendNUIMessage({ action = 'warrantCreated', warrant = warrant })
end)

RegisterNetEvent('police:client:warrantClosed')
AddEventHandler('police:client:warrantClosed', function(warrantId)
    SendNUIMessage({ action = 'warrantClosed', warrantId = warrantId })
end)

RegisterNetEvent('police:client:onDutyOfficers')
AddEventHandler('police:client:onDutyOfficers', function(officers)
    SendNUIMessage({ action = 'onDutyOfficers', officers = officers or {} })
end)

RegisterNetEvent('police:client:fleetVehicleAdded')
AddEventHandler('police:client:fleetVehicleAdded', function(vehicle)
    SendNUIMessage({ action = 'fleetVehicleAdded', vehicle = vehicle })
end)

RegisterNetEvent('police:client:fleetVehicleRemoved')
AddEventHandler('police:client:fleetVehicleRemoved', function(vehicleId)
    SendNUIMessage({ action = 'fleetVehicleRemoved', vehicleId = vehicleId })
end)

RegisterNetEvent('police:client:armoryUpdated')
AddEventHandler('police:client:armoryUpdated', function(data)
    SendNUIMessage({ action = 'armoryUpdated', weapons = data.weapons, equipment = data.equipment })
end)

RegisterNetEvent('mdt:client:criminalHistory')
AddEventHandler('mdt:client:criminalHistory', function(data)
    SendNUIMessage({ action = 'criminalHistory', data = data })
end)

RegisterNetEvent('mdt:client:citationsData')
AddEventHandler('mdt:client:citationsData', function(data)
    SendNUIMessage({ action = 'citationsData', data = data })
end)

RegisterNetEvent('mdt:client:citationCreated')
AddEventHandler('mdt:client:citationCreated', function(row)
    TriggerServerEvent('mdt:server:getCitations')
end)

RegisterNetEvent('mdt:client:bolosData')
AddEventHandler('mdt:client:bolosData', function(data)
    SendNUIMessage({ action = 'bolosData', data = data })
end)

RegisterNetEvent('mdt:client:boloCreated')
AddEventHandler('mdt:client:boloCreated', function(row)
    TriggerServerEvent('mdt:server:getActiveBOLOs')
end)

RegisterNetEvent('mdt:client:incidentsData')
AddEventHandler('mdt:client:incidentsData', function(data)
    SendNUIMessage({ action = 'incidentsData', data = data })
end)

RegisterNetEvent('mdt:client:incidentCreated')
AddEventHandler('mdt:client:incidentCreated', function(row)
    TriggerServerEvent('mdt:server:getIncidents')
end)

RegisterNetEvent('mdt:client:impoundsData')
AddEventHandler('mdt:client:impoundsData', function(data)
    SendNUIMessage({ action = 'impoundsData', data = data })
end)

RegisterNetEvent('mdt:client:impoundCreated')
AddEventHandler('mdt:client:impoundCreated', function(row)
    TriggerServerEvent('mdt:server:getImpounds')
end)

RegisterNetEvent('ems:client:callsData')
AddEventHandler('ems:client:callsData', function(calls)
    SendNUIMessage({ action = 'updateCalls', data = calls })
end)

RegisterNetEvent('ems:client:callsUpdated')
AddEventHandler('ems:client:callsUpdated', function(calls)
    SendNUIMessage({ action = 'updateCalls', data = calls })
end)

RegisterNetEvent('ems:client:new112Call')
AddEventHandler('ems:client:new112Call', function(call)
    if not isMDTOpen then return end
    SendNUIMessage({ action = 'addCall', data = call })
end)

RegisterNetEvent('ems:client:patientSearchResults')
AddEventHandler('ems:client:patientSearchResults', function(results)
    SendNUIMessage({ action = 'searchResults', data = results })
end)

RegisterNetEvent('ems:client:patientHistory')
AddEventHandler('ems:client:patientHistory', function(data)
    SendNUIMessage({ action = 'patientHistory', data = data })
end)

RegisterNetEvent('ems:client:onDutyEMS')
AddEventHandler('ems:client:onDutyEMS', function(roster)
    SendNUIMessage({ action = 'updateRoster', data = roster })
end)
