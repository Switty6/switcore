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

local function SendPatientData(emsSrc, patientSrc)
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
end

Sw.SecureEvent('ems:server:getPatientData', {
    character = true,
    rateLimit = { max = 20, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    if not IsEMSOnDuty(emsSrc) then return end

    SendPatientData(emsSrc, ctx.args[1])
end)

Sw.SecureEvent('ems:server:revivePatient', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    local charId = ctx.character.id
    local patientSrc = ctx.args[1]

    if not exports.jobs:HasJobPermission(charId, 'revive') then
        Notify(emsSrc, 'error', Sw.TP(emsSrc, 'ems.no_revive_permission'), 4000)
        return
    end

    if not IsUnconscious(patientSrc) then
        Notify(emsSrc, 'warning', Sw.TP(emsSrc, 'ems.patient_not_unconscious'), 3000)
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

Sw.SecureEvent('ems:server:treatInjury', {
    character = true,
    rateLimit = { max = 20, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    if not IsEMSOnDuty(emsSrc) then return end

    local patientSrc, injuryId = ctx.args[1], ctx.args[2]

    local ok = exports.medical:TreatInjury(patientSrc, injuryId)
    if not ok then
        Notify(emsSrc, 'warning', Sw.TP(emsSrc, 'ems.injury_not_found'), 3000)
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

    Notify(emsSrc, 'success', Sw.TP(emsSrc, 'ems.injury_treated'), 3000)
    SendPatientData(emsSrc, patientSrc)
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

Sw.SecureEvent('ems:server:cureAllConditions', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    local charId = ctx.character.id
    local patientSrc = ctx.args[1]

    if not exports.jobs:HasJobPermission(charId, 'revive') then
        Notify(emsSrc, 'error', Sw.TP(emsSrc, 'ems.no_permission'), 4000)
        return
    end

    exports.medical:CureAll(patientSrc)

    local patientCharId = GetCharId(patientSrc)
    if patientCharId then
        EmsDB.logRecord(patientCharId, charId, 'treatment', { type = 'cure_all' })
    end

    Notify(emsSrc, 'success', Sw.TP(emsSrc, 'ems.all_conditions_cured'), 4000)
    Notify(patientSrc, 'success', Sw.TP(patientSrc, 'ems.cured_by_doctor'), 5000)
end)

Sw.SecureEvent('ems:server:administerIV', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    if not IsEMSOnDuty(emsSrc) then return end

    local patientSrc, itemName, plate = ctx.args[1], ctx.args[2], ctx.args[3]

    local emsCharId = GetCharId(emsSrc)
    if not emsCharId then return end

    local ivTreatments = exports.settings:GetSettingJSON('ems.iv_treatments', {})
    local treatment    = nil
    for _, t in ipairs(ivTreatments) do
        if t.item == itemName then treatment = t; break end
    end

    if not treatment then
        Notify(emsSrc, 'error', Sw.TP(emsSrc, 'ems.iv_invalid'), 3000)
        return
    end

    if not EmsDB.tryDeductVehicleItem(plate, itemName, 1) then
        Notify(emsSrc, 'warning', Sw.TP(emsSrc, 'ems.iv_insufficient_stock'), 3000)
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

    Notify(emsSrc, 'success', Sw.TP(emsSrc, 'ems.iv_administered', treatment.label), 3000)
    Notify(patientSrc, 'info', Sw.TP(patientSrc, 'ems.iv_received', treatment.label), 4000)
end)

Sw.SecureEvent('ems:server:searchPatient', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src    = ctx.source
    local charId = ctx.character.id
    local query  = ctx.args[1]

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' then return end

    if not query or #query < 2 then
        TriggerClientEvent('ems:client:patientSearchResults', src, {})
        return
    end

    local results = EmsDB.searchPatient(query)
    TriggerClientEvent('ems:client:patientSearchResults', src, results)
end)

Sw.SecureEvent('ems:server:getPatientHistory', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src    = ctx.source
    local charId = ctx.character.id
    local patientCharId = ctx.args[1]

    local job = exports.jobs:GetCharacterJob(charId)
    if not job or job.name ~= 'ems' then return end

    local history = EmsDB.getPatientHistory(patientCharId)
    TriggerClientEvent('ems:client:patientHistory', src, history)
end)

Sw.SecureEvent('ems:server:getOnDutyEMS', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src    = ctx.source
    local charId = ctx.character.id

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

Sw.SecureEvent('ems:server:liftPatient', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    if not IsEMSOnDuty(emsSrc) then return end

    local targetSrc = ctx.args[1]

    if not IsUnconscious(targetSrc) then
        Notify(emsSrc, 'warning', Sw.TP(emsSrc, 'ems.patient_not_unconscious'), 3000)
        return
    end

    if not TrySetCarrier(targetSrc, nil, emsSrc) then
        Notify(emsSrc, 'warning', Sw.TP(emsSrc, 'ems.patient_already_carried'), 3000)
        return
    end

    TriggerClientEvent('ems:client:youAreLiftedBy', targetSrc, emsSrc)
    TriggerClientEvent('ems:client:startCarrying',  emsSrc,    targetSrc)
end)

Sw.SecureEvent('ems:server:placePatient', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local emsSrc = ctx.source
    if not IsEMSOnDuty(emsSrc) then return end

    local targetSrc, inVehicle, vehiclePlate = ctx.args[1], ctx.args[2], ctx.args[3]

    if not TrySetCarrier(targetSrc, emsSrc, nil) then
        Notify(emsSrc, 'warning', Sw.TP(emsSrc, 'ems.not_carrying_patient'), 3000)
        return
    end

    TriggerClientEvent('ems:client:stopCarrying', emsSrc)

    if inVehicle and vehiclePlate then
        TriggerClientEvent('ems:client:placeInAmbulance', targetSrc, vehiclePlate)
    else
        TriggerClientEvent('ems:client:youArePlaced', targetSrc)
    end
end)

Sw.SecureEvent('ems:server:logDiagnosis', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local emsSrc    = ctx.source
    local emsCharId = ctx.character.id
    local patientSrc, notes = ctx.args[1], ctx.args[2]

    local patientCharId = GetCharId(patientSrc)
    if not patientCharId then return end

    EmsDB.logRecord(patientCharId, emsCharId, 'diagnosis', { notes = notes or '' })
    Notify(emsSrc, 'success', Sw.TP(emsSrc, 'ems.diagnosis_saved'), 3000)
end)
