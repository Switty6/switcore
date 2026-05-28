local function Notify(source, ntype, msg, dur)
    TriggerClientEvent('switcore:notify', source, ntype, msg, dur or 4000)
end

local function GetCharId(source)
    return exports.characters:getCharacterId(source)
end

local function GetCharName(source)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(source)
    end)
    if ok and char then
        return (char.first_name or '') .. ' ' .. (char.last_name or '')
    end
    return 'Necunoscut'
end

local function IsEMSOnDuty(source)
    local charId = GetCharId(source)
    if not charId then return false end
    local job = exports.jobs:GetCharacterJob(charId)
    return job and job.name == 'ems' and job.isOnDuty
end

RegisterNetEvent('ems:server:getPatientData')
AddEventHandler('ems:server:getPatientData', function(patientSrc)
    local emsSrc = source
    if not IsEMSOnDuty(emsSrc) then return end

    local patientCharId = GetCharId(patientSrc)
    if not patientCharId then return end

    local conditions  = exports.medical:GetCharacterConditions(patientSrc)
    local injuries    = exports.medical:GetActiveInjuries(patientSrc)
    local isUncon     = IsUnconscious(patientSrc)
    local unconData   = GetUnconsciousData(patientSrc)
    local name        = GetCharName(patientSrc)

    local timerRemaining = 0
    if unconData then
        local respawnTimer = exports.settings:GetSettingNumber('ems.respawn_timer', 600)
        timerRemaining = math.max(0, respawnTimer - (os.time() - unconData.startedAt))
    end

    TriggerClientEvent('ems:client:openPatientMenu', emsSrc, {
        patientSrc      = patientSrc,
        patientCharId   = patientCharId,
        name            = name,
        conditions      = conditions,
        injuries        = injuries,
        unconscious     = isUncon,
        timerRemaining  = timerRemaining,
    })
end)

RegisterNetEvent('ems:server:revivePatient')
AddEventHandler('ems:server:revivePatient', function(patientSrc)
    local emsSrc = source
    local charId = GetCharId(emsSrc)
    if not charId then return end

    if not exports.jobs:HasJobPermission(charId, 'revive') then
        Notify(emsSrc, 'error', 'Nu ai permisiunea de resuscitare.', 4000)
        return
    end

    if not IsUnconscious(patientSrc) then
        Notify(emsSrc, 'warning', 'Pacientul nu este inconstient.', 3000)
        return
    end

    RevivePlayer(patientSrc, emsSrc)

    local patientCharId = GetCharId(patientSrc)
    if patientCharId then
        EmsDB.logRecord(patientCharId, charId, 'revive', {
            emsName = GetCharName(emsSrc),
        })
    end
end)

RegisterNetEvent('ems:server:treatInjury')
AddEventHandler('ems:server:treatInjury', function(patientSrc, injuryId)
    local emsSrc = source
    if not IsEMSOnDuty(emsSrc) then return end

    local ok = exports.medical:TreatInjury(patientSrc, injuryId)
    if not ok then
        Notify(emsSrc, 'warning', 'Rana nu a fost gasita.', 3000)
        return
    end

    local patientCharId = GetCharId(patientSrc)
    local emsCharId     = GetCharId(emsSrc)
    if patientCharId and emsCharId then
        EmsDB.logRecord(patientCharId, emsCharId, 'treatment', {
            type     = 'treat_injury',
            injuryId = injuryId,
        })
    end

    Notify(emsSrc, 'success', 'Rana tratata cu succes.', 3000)
    TriggerEvent('ems:server:getPatientData', emsSrc, patientSrc)
    local patientName   = GetCharName(patientSrc)
    local conditions    = exports.medical:GetCharacterConditions(patientSrc)
    local injuries      = exports.medical:GetActiveInjuries(patientSrc)
    local isUncon       = IsUnconscious(patientSrc)
    local unconData     = GetUnconsciousData(patientSrc)
    local timerRemaining = 0
    if unconData then
        local respawnTimer = exports.settings:GetSettingNumber('ems.respawn_timer', 600)
        timerRemaining = math.max(0, respawnTimer - (os.time() - unconData.startedAt))
    end

    TriggerClientEvent('ems:client:patientDataUpdated', emsSrc, {
        patientSrc     = patientSrc,
        patientCharId  = patientCharId,
        name           = patientName,
        conditions     = conditions,
        injuries       = injuries,
        unconscious    = isUncon,
        timerRemaining = timerRemaining,
    })
end)

RegisterNetEvent('ems:server:cureAllConditions')
AddEventHandler('ems:server:cureAllConditions', function(patientSrc)
    local emsSrc = source
    local charId = GetCharId(emsSrc)
    if not charId then return end

    if not exports.jobs:HasJobPermission(charId, 'revive') then
        Notify(emsSrc, 'error', 'Nu ai permisiunea necesara.', 4000)
        return
    end

    exports.medical:CureAll(patientSrc)

    local patientCharId = GetCharId(patientSrc)
    if patientCharId then
        EmsDB.logRecord(patientCharId, charId, 'treatment', { type = 'cure_all' })
    end

    Notify(emsSrc, 'success', 'Toate bolile pacientului au fost tratate.', 4000)
    Notify(patientSrc, 'success', 'Ai fost tratat de medic. Bolile sunt vindecate.', 5000)
end)

RegisterNetEvent('ems:server:administerIV')
AddEventHandler('ems:server:administerIV', function(patientSrc, itemName, plate)
    local emsSrc = source
    if not IsEMSOnDuty(emsSrc) then return end

    local emsCharId = GetCharId(emsSrc)
    if not emsCharId then return end

    local ivTreatments = exports.settings:GetSettingJSON('ems.iv_treatments', {})
    local treatment    = nil
    for _, t in ipairs(ivTreatments) do
        if t.item == itemName then treatment = t; break end
    end

    if not treatment then
        Notify(emsSrc, 'error', 'Tratament IV invalid.', 3000)
        return
    end

    if not EmsDB.tryDeductVehicleItem(plate, itemName, 1) then
        Notify(emsSrc, 'warning', 'Stoc insuficient in ambulanta.', 3000)
        return
    end

    if treatment.restoreHP and treatment.restoreHP > 0 then
        TriggerClientEvent('medical:client:applyDamage', patientSrc, -treatment.restoreHP)
    end
    if treatment.suppressDuration and treatment.suppressDuration > 0 then
        exports.medical:SuppressSymptom(patientSrc, 'bleeding', treatment.suppressDuration)
    end
    if treatment.injuryBleedSuppress and treatment.injuryBleedSuppress > 0 then
        exports.medical:SuppressInjuryBleeding(patientSrc, treatment.injuryBleedSuppress)
    end

    local patientCharId = GetCharId(patientSrc)
    if patientCharId then
        EmsDB.logRecord(patientCharId, emsCharId, 'treatment', {
            type  = 'iv',
            item  = itemName,
            label = treatment.label,
            plate = plate,
        })
    end

    Notify(emsSrc, 'success', treatment.label .. ' administrat cu succes.', 3000)
    Notify(patientSrc, 'info', 'Medicul ti-a administrat ' .. treatment.label .. '.', 4000)
end)

RegisterNetEvent('ems:server:searchPatient')
AddEventHandler('ems:server:searchPatient', function(query)
    local src    = source
    local charId = GetCharId(src)
    if not charId then return end

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' then return end

    if not query or #query < 2 then
        TriggerClientEvent('ems:client:patientSearchResults', src, {})
        return
    end

    local results = EmsDB.searchPatient(query)
    TriggerClientEvent('ems:client:patientSearchResults', src, results)
end)

RegisterNetEvent('ems:server:getPatientHistory')
AddEventHandler('ems:server:getPatientHistory', function(patientCharId)
    local src    = source
    local charId = GetCharId(src)
    if not charId then return end

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' then return end

    local history = EmsDB.getPatientHistory(patientCharId)
    TriggerClientEvent('ems:client:patientHistory', src, history)
end)

RegisterNetEvent('ems:server:getOnDutyEMS')
AddEventHandler('ems:server:getOnDutyEMS', function()
    local src    = source
    local charId = GetCharId(src)
    if not charId then return end

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' then return end

    local roster = exports.jobs:GetJobRoster('ems')
    local onDuty = {}

    if roster then
        for _, member in ipairs(roster) do
            onDuty[#onDuty + 1] = {
                characterId = member.characterId,
                name        = member.name,
                gradeLabel  = member.gradeLabel,
                isOnDuty    = member.isOnDuty,
            }
        end
    end

    TriggerClientEvent('ems:client:onDutyEMS', src, onDuty)
end)

RegisterNetEvent('ems:server:liftPatient')
AddEventHandler('ems:server:liftPatient', function(targetSrc)
    local emsSrc = source
    if not IsEMSOnDuty(emsSrc) then return end

    if not IsUnconscious(targetSrc) then
        Notify(emsSrc, 'warning', 'Pacientul nu este inconstient.', 3000)
        return
    end

    if not TrySetCarrier(targetSrc, nil, emsSrc) then
        Notify(emsSrc, 'warning', 'Pacientul este deja transportat.', 3000)
        return
    end

    TriggerClientEvent('ems:client:youAreLiftedBy', targetSrc, emsSrc)
    TriggerClientEvent('ems:client:startCarrying',  emsSrc,    targetSrc)
end)

RegisterNetEvent('ems:server:placePatient')
AddEventHandler('ems:server:placePatient', function(targetSrc, inVehicle, vehiclePlate)
    local emsSrc = source
    if not IsEMSOnDuty(emsSrc) then return end

    if not TrySetCarrier(targetSrc, emsSrc, nil) then
        Notify(emsSrc, 'warning', 'Nu transporti acest pacient.', 3000)
        return
    end

    TriggerClientEvent('ems:client:stopCarrying', emsSrc)

    if inVehicle and vehiclePlate then
        TriggerClientEvent('ems:client:placeInAmbulance', targetSrc, vehiclePlate)
    else
        TriggerClientEvent('ems:client:youArePlaced', targetSrc)
    end
end)

RegisterNetEvent('ems:server:logDiagnosis')
AddEventHandler('ems:server:logDiagnosis', function(patientSrc, notes)
    local emsSrc    = source
    local emsCharId = GetCharId(emsSrc)
    if not emsCharId then return end

    local patientCharId = GetCharId(patientSrc)
    if not patientCharId then return end

    EmsDB.logRecord(patientCharId, emsCharId, 'diagnosis', { notes = notes or '' })
    Notify(emsSrc, 'success', 'Diagnostic salvat in dosar.', 3000)
end)
