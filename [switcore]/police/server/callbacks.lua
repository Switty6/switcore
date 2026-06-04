
local function getOnDutyRoster()
    local officers = {}
    local ok, roster = pcall(function() return exports.jobs:GetJobRoster('police') end)
    if ok and roster then
        for _, m in ipairs(roster) do
            if m.is_on_duty then officers[#officers + 1] = m end
        end
    end
    return officers
end

local function filterArmoryList(list, itemName)
    local out = {}
    for _, e in ipairs(list) do
        if e.itemName ~= itemName then out[#out + 1] = e end
    end
    return out
end

local function saveArmorySettings()
    local settings = exports.police:GetPoliceSettings()
    exports.settings:SetSetting('police.armory_weapons',   json.encode(settings.armoryWeapons or {}))
    exports.settings:SetSetting('police.armory_equipment', json.encode(settings.armoryEquipment or {}))
end

local armoryLockBusy = false
local function withArmoryLock(fn)
    while armoryLockBusy do Citizen.Wait(5) end
    armoryLockBusy = true
    local ok, err = pcall(fn)
    armoryLockBusy = false
    if not ok then print('[POLICE] armory lock error: ' .. tostring(err)) end
end

Sw.SecureEvent('police:server:handcuffPlayer', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local targetSrc = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa incatusezi.')
        return
    end

    targetSrc = tonumber(targetSrc)
    if not targetSrc or not GetPlayerName(targetSrc) then
        notify(src, 'error', 'Eroare', 'Jucatorul nu exista.')
        return
    end

    local targetChar = getActiveChar(targetSrc)
    if not targetChar then
        notify(src, 'error', 'Eroare', 'Jucatorul nu are personaj activ.')
        return
    end

    if exports.police:IsCharacterHandcuffed(targetChar.id) then
        notify(src, 'error', 'Eroare', 'Jucatorul este deja incatusat.')
        return
    end

    local srcCoords    = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetSrc))
    local dist = #(srcCoords - targetCoords)
    local settings = exports.police:GetPoliceSettings()
    if dist > (settings.handcuffDist or 2.5) + 2.0 then
        notify(src, 'error', 'Prea departe', 'Jucatorul este prea departe.')
        return
    end

    if not exports.police:AddHandcuff(targetChar.id, char.id) then
        notify(src, 'error', 'Eroare', 'Nu am putut incatusa jucatorul.')
        return
    end
    TriggerClientEvent('police:client:handcuffed', targetSrc)
    notify(src, 'success', 'Incatusat', 'Jucatorul a fost incatusat.')
end)

Sw.SecureEvent('police:server:unhandcuffPlayer', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local targetSrc = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa scoti catusele.')
        return
    end

    targetSrc = tonumber(targetSrc)
    local targetChar = targetSrc and getActiveChar(targetSrc) or nil
    if not targetChar or not exports.police:IsHandcuffedBy(targetChar.id, char.id) then
        notify(src, 'error', 'Eroare', 'Nu esti ofiterul care a incatusat acest jucator.')
        return
    end

    exports.police:RemoveHandcuff(targetChar.id)
    TriggerClientEvent('police:client:unhandcuffed', targetSrc)
    notify(src, 'success', 'Catuse scoase', 'Catusele au fost scoase.')
end)

Sw.SecureEvent('police:server:arrestPlayer', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local targetSrc, reason, sentenceMinutes, bailAmount = ctx.args[1], ctx.args[2], ctx.args[3], ctx.args[4]

    if not isPoliceOnDuty(char.id) or not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa arestezi.')
        return
    end

    targetSrc = tonumber(targetSrc)
    local targetChar = targetSrc and getActiveChar(targetSrc) or nil
    if not targetChar or not exports.police:IsHandcuffedBy(targetChar.id, char.id) then
        notify(src, 'error', 'Eroare', 'Jucatorul nu este incatusat de tine.')
        return
    end

    sentenceMinutes = math.max(1, math.min(tonumber(sentenceMinutes) or 10, 720))
    bailAmount      = math.max(0, tonumber(bailAmount) or 0)
    reason          = tostring(reason or ''):sub(1, 512)
    if #reason < 3 then
        notify(src, 'error', 'Date invalide', 'Motiv prea scurt.')
        return
    end

    local ok, err = JailCharacter(targetChar.id, char.id, reason, sentenceMinutes, bailAmount)
    if not ok then
        notify(src, 'error', 'Eroare arest', err)
        return
    end

    exports.police:RemoveHandcuff(targetChar.id)
    TriggerClientEvent('police:client:unhandcuffed', targetSrc)
    notify(src, 'success', 'Arestat', targetChar.first_name .. ' ' .. targetChar.last_name .. ' a fost arestat.')
end)

Sw.SecureEvent('police:server:unjailEarly', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local targetCharId = ctx.args[1]

    if not isAdmin(src) and not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea de eliberare timpurie.')
        return
    end

    targetCharId = tonumber(targetCharId)
    if not targetCharId then return end

    local ok = ReleaseFromJail(targetCharId, 'officer')
    if ok then
        notify(src, 'success', 'Eliberat', 'Detinutu a fost eliberat.')
    else
        notify(src, 'error', 'Eroare', 'Personajul nu este in inchisoare.')
    end
end)

Sw.SecureEvent('police:server:payBail', {
    character = true,
    rateLimit = { max = 5, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    local sentence = PoliceDatabase.getActiveJailSentence(char.id)
    if not sentence then
        notify(src, 'error', 'Eroare', 'Nu esti la inchisoare.')
        return
    end

    if sentence.bail_amount <= 0 then
        notify(src, 'error', 'Imposibil', 'Nu exista optiune de cautiune pentru aceasta sentinta.')
        return
    end

    local balance = exports.banking:getCharacterCash(char.id, 1) or 0
    if balance < sentence.bail_amount then
        notify(src, 'error', 'Fonduri insuficiente', 'Ai nevoie de $' .. sentence.bail_amount .. ' cautiune.')
        return
    end

    local settings    = exports.police:GetPoliceSettings()
    local currencyId  = tonumber(settings.vehicleCurrencyId) or 1

    exports.banking:addCharacterCash(char.id, currencyId, -sentence.bail_amount)
    pcall(function()
        exports.government:AddIncome(sentence.bail_amount, 'RON',
            'Cautiune - ' .. (char.first_name or '') .. ' ' .. (char.last_name or ''), 'Amenzi')
    end)
    ReleaseFromJail(char.id, 'bail')
end)

Sw.SecureEvent('police:server:openArmory', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not isPoliceOnDuty(char.id) or not hasArmoryPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai acces la armament.')
        return
    end

    local settings = exports.police:GetPoliceSettings()
    TriggerClientEvent('police:client:openArmory', src, settings.armoryWeapons, settings.armoryEquipment)
end)

Sw.SecureEvent('police:server:takeArmoryItem', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local itemName, isWeapon = ctx.args[1], ctx.args[2]

    if not isPoliceOnDuty(char.id) or not hasArmoryPerm(char.id) then return end

    local invId = 'char:' .. char.id
    local cfg, amount

    if isWeapon then
        cfg = findArmoryWeapon(itemName)
        if not cfg then return end
        exports.inventory:AddItem(invId, cfg.itemName, 1, nil)
        if cfg.ammoItem and cfg.ammoAmount and cfg.ammoAmount > 0 then
            exports.inventory:AddItem(invId, cfg.ammoItem, cfg.ammoAmount, nil)
        end
        amount = 1
    else
        cfg = findArmoryEquipment(itemName)
        if not cfg then return end
        exports.inventory:AddItem(invId, cfg.itemName, cfg.amount, nil)
        amount = cfg.amount
    end

    PoliceDatabase.logArmoryTake(char.id, cfg.itemName, amount)
    TriggerClientEvent('police:client:armoryItemGiven', src, { itemName = cfg.itemName, label = cfg.label })
    notify(src, 'success', 'Echipament', cfg.label .. ' adaugat in inventar.')
end)

Sw.SecureEvent('police:server:openCloakroom', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not isPoliceOnDuty(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Trebuie sa fii in tura.')
        return
    end

    local character = exports.characters:getActiveCharacter(src)
    local gender    = 'male'
    if character and character.appearance then
        local app = character.appearance
        if type(app) == 'string' then
            local ok, decoded = pcall(json.decode, app)
            app = ok and decoded or {}
        end
        if app and (app.gender == 1 or app.gender == 'female') then
            gender = 'female'
        end
    end

    TriggerClientEvent('police:client:openCloakroom', src, gender)
end)

Sw.SecureEvent('police:server:applyUniform', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local gender = ctx.args[1]

    if not isPoliceOnDuty(char.id) then return end

    local settings    = exports.police:GetPoliceSettings()
    local components  = gender == 'female' and settings.uniformFemale or settings.uniformMale
    TriggerClientEvent('police:client:applyUniform', src, components)
end)

Sw.SecureEvent('police:server:setCivilianClothes', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src = ctx.source
    TriggerClientEvent('police:client:restoreCivilianClothes', src)
end)

Sw.SecureEvent('police:server:openMDT', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not isPoliceOnDuty(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Trebuie sa fii in tura.')
        return
    end

    local warrants  = PoliceDatabase.getAllActiveWarrants()
    local officers  = getOnDutyRoster()
    local settings  = exports.police:GetPoliceSettings()
    local currencyId = tonumber(settings.vehicleCurrencyId) or 1
    local canManage = hasManagePerm(char.id)

    local mgmtData = nil
    if canManage then
        local orgBalance = exports.banking:getOrgAccountBalance('police', currencyId)
        local orgTxs     = exports.banking:getOrgTransactions('police', 20)
        local fleet      = PoliceDatabase.getFleet()
        mgmtData = {
            balance          = orgBalance,
            transactions     = orgTxs,
            fleet            = fleet,
            fleetModels      = settings.fleetModels or {},
            sellRatio        = settings.vehicleSellRatio or 0.6,
            armoryWeapons    = settings.armoryWeapons or {},
            armoryEquipment  = settings.armoryEquipment or {},
            currencyId       = currencyId
        }
    end

    TriggerClientEvent('police:client:mdtData', src, {
        warrants   = warrants,
        officers   = officers,
        canManage  = canManage,
        management = mgmtData
    })
end)

Sw.SecureEvent('police:server:searchCharacter', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local query = ctx.args[1]

    if not isPoliceOnDuty(char.id) then return end

    query = tostring(query or ''):sub(1, 64)
    if #query < 2 then
        notify(src, 'warning', 'Cautare', 'Introdu cel putin 2 caractere.')
        return
    end

    local results = PoliceDatabase.searchCharacter('%' .. query .. '%')
    for _, c in ipairs(results) do
        c.hasWarrant = PoliceDatabase.getActiveWarrant(c.id) ~= nil
        c.isJailed   = PoliceDatabase.getActiveJailSentence(c.id) ~= nil
    end

    TriggerClientEvent('police:client:searchResults', src, results)
end)

Sw.SecureEvent('police:server:createWarrant', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local characterId, charges, bailAmount = ctx.args[1], ctx.args[2], ctx.args[3]

    if not isPoliceOnDuty(char.id) or not hasArrestPerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea sa emiti mandate.')
        return
    end

    characterId = tonumber(characterId)
    bailAmount  = math.max(0, tonumber(bailAmount) or 0)
    charges     = tostring(charges or ''):sub(1, 512)

    if not characterId or #charges < 3 then
        notify(src, 'error', 'Date invalide', 'Completeaza toate campurile.')
        return
    end

    local warrant = PoliceDatabase.createWarrant(characterId, char.id, charges, bailAmount)
    if warrant then
        TriggerClientEvent('police:client:warrantCreated', src, warrant)
        notify(src, 'success', 'Mandat', 'Mandatul a fost emis.')
    end
end)

Sw.SecureEvent('police:server:closeWarrant', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local warrantId = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasArrestPerm(char.id) then return end

    warrantId = tonumber(warrantId)
    if not warrantId then return end

    PoliceDatabase.closeWarrant(warrantId, char.id)
    TriggerClientEvent('police:client:warrantClosed', src, warrantId)
    notify(src, 'success', 'Mandat', 'Mandatul a fost inchis.')
end)

Sw.SecureEvent('police:server:getOnDutyOfficers', {
    character = true,
    rateLimit = { max = 15, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not isPoliceOnDuty(char.id) then return end

    TriggerClientEvent('police:client:onDutyOfficers', src, getOnDutyRoster())
end)

Sw.SecureEvent('police:server:openGarage', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not isPoliceOnDuty(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Trebuie sa fii in tura.')
        return
    end

    local fleet    = PoliceDatabase.getFleet()
    local current  = PoliceDatabase.getCharacterCheckout(char.id)
    local settings = exports.police:GetPoliceSettings()

    TriggerClientEvent('police:client:openGarage', src, {
        fleet       = fleet,
        currentId   = current and current.id or nil,
        mileageUnit = settings.mileageUnit or 'km'
    })
end)

Sw.SecureEvent('police:server:checkoutVehicle', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local vehicleId = ctx.args[1]

    if not isPoliceOnDuty(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Trebuie sa fii in tura.')
        return
    end

    local existing = PoliceDatabase.getCharacterCheckout(char.id)
    if existing then
        notify(src, 'error', 'Eroare', 'Ai deja un vehicul preluat. Returneaza-l mai intai.')
        return
    end

    vehicleId = tonumber(vehicleId)

    local vehicle = PoliceDatabase.checkoutFleetVehicle(vehicleId, char.id)
    if not vehicle then
        local exists = PoliceDatabase.getFleetVehicle(vehicleId)
        if not exists then
            notify(src, 'error', 'Eroare', 'Vehiculul nu exista.')
        else
            notify(src, 'error', 'Indisponibil', 'Vehiculul este deja preluat de altcineva.')
        end
        return
    end

    PoliceDatabase.logFleetAction(vehicleId, char.id, 'checkout', vehicle.mileage, vehicle.fuel)

    local settings = exports.police:GetPoliceSettings()
    local spawn    = settings.garageSpawn or { x = 0, y = 0, z = 0, heading = 0 }

    TriggerClientEvent('police:client:spawnFleetVehicle', src, {
        vehicleId     = vehicle.id,
        model         = vehicle.model,
        plate         = vehicle.plate,
        label         = vehicle.label,
        fuel          = vehicle.fuel,
        mileage       = vehicle.mileage,
        bodyHealth    = vehicle.body_health,
        engineHealth  = vehicle.engine_health,
        modifications = vehicle.modifications,
        spawnCoords   = spawn,
        mileageUnit   = settings.mileageUnit or 'km'
    })

    notify(src, 'success', 'Garaj', vehicle.label .. ' a fost preluat.')
end)

Sw.SecureEvent('police:server:returnVehicle', {
    character = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local vehicleId, state = ctx.args[1], ctx.args[2]

    vehicleId = tonumber(vehicleId)
    local vehicle = PoliceDatabase.getFleetVehicle(vehicleId)
    if not vehicle or vehicle.checked_out_by ~= char.id then
        notify(src, 'error', 'Eroare', 'Nu ai preluat acest vehicul.')
        return
    end

    state = state or {}
    local fuel       = math.max(0, math.min(tonumber(state.fuel)         or vehicle.fuel,         100))
    local mileage    = math.max(0, tonumber(state.mileage)               or vehicle.mileage)
    local bodyHealth = math.max(0, math.min(tonumber(state.bodyHealth)   or vehicle.body_health,  1000))
    local engHealth  = math.max(0, math.min(tonumber(state.engineHealth) or vehicle.engine_health, 1000))

    PoliceDatabase.returnFleetVehicle(vehicleId, fuel, mileage, bodyHealth, engHealth)
    PoliceDatabase.logFleetAction(vehicleId, char.id, 'return', mileage, fuel)

    notify(src, 'success', 'Garaj', vehicle.label .. ' a fost returnat.')
end)

Sw.SecureEvent('police:server:fleetMileageTick', {
    character = true,
    rateLimit = { max = 30, window = 10000 },
    silent = true,
}, function(ctx)
    local char = ctx.character
    local vehicleId, addedKm = ctx.args[1], ctx.args[2]

    vehicleId = tonumber(vehicleId)
    addedKm   = math.max(0, math.min(tonumber(addedKm) or 0, 5.0))

    local vehicle = PoliceDatabase.getFleetVehicle(vehicleId)
    if not vehicle or vehicle.checked_out_by ~= char.id then return end

    PoliceDatabase.updateFleetMileage(vehicleId, (vehicle.mileage or 0) + addedKm)
end)

Sw.SecureEvent('police:server:fleetStateTick', {
    character = true,
    rateLimit = { max = 30, window = 10000 },
    silent = true,
}, function(ctx)
    local char = ctx.character
    local vehicleId, state = ctx.args[1], ctx.args[2]

    vehicleId = tonumber(vehicleId)
    local vehicle = PoliceDatabase.getFleetVehicle(vehicleId)
    if not vehicle or vehicle.checked_out_by ~= char.id then return end

    state = state or {}
    local fuel       = math.max(0, math.min(tonumber(state.fuel)         or vehicle.fuel,         100))
    local mileage    = math.max(0, tonumber(state.mileage)               or vehicle.mileage)
    local bodyHealth = math.max(0, math.min(tonumber(state.bodyHealth)   or vehicle.body_health,  1000))
    local engHealth  = math.max(0, math.min(tonumber(state.engineHealth) or vehicle.engine_health, 1000))

    PoliceDatabase.updateFleetState(vehicleId, fuel, mileage, bodyHealth, engHealth)
end)

Sw.SecureEvent('police:server:purchaseFleetVehicle', {
    character = true,
    rateLimit = { max = 5, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local modelName = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasManagePerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea de management.')
        return
    end

    local settings   = exports.police:GetPoliceSettings()
    local currencyId = tonumber(settings.vehicleCurrencyId) or 1

    local modelCfg = nil
    for _, m in ipairs(settings.fleetModels or {}) do
        if m.model == modelName then modelCfg = m; break end
    end
    if not modelCfg then
        notify(src, 'error', 'Eroare', 'Modelul nu exista in configuratie.')
        return
    end

    local price = tonumber(modelCfg.price) or 0
    if price > 0 then
        local orgBalance = exports.banking:getOrgAccountBalance('police', currencyId)
        if orgBalance < price then
            notify(src, 'error', 'Fonduri insuficiente',
                string.format('Buget insuficient. Necesar: $%d, Disponibil: $%d', price, math.floor(orgBalance)))
            return
        end
        local ok, err = exports.banking:orgSystemDebit('police', price, currencyId,
            'Achizitie vehicul: ' .. (modelCfg.label or modelName))
        if not ok then
            notify(src, 'error', 'Eroare buget', err or 'Eroare la debitare cont.')
            return
        end
    end

    local fleet    = PoliceDatabase.getFleet()
    local newIndex = #fleet + 1
    local plate    = ('POLIT%03d'):format(newIndex)
    while PoliceDatabase.getFleetVehicleByPlate(plate) do
        newIndex = newIndex + 1
        plate    = ('POLIT%03d'):format(newIndex)
    end

    local vehicle = PoliceDatabase.createFleetVehicle(
        modelCfg.model, modelCfg.label, modelCfg.category or 'emergency', plate, price)
    if not vehicle then
        if price > 0 then
            exports.banking:orgSystemCredit('police', price, currencyId, 'Rambursare achizitie esecuata')
        end
        notify(src, 'error', 'Eroare', 'Nu s-a putut adauga vehiculul.')
        return
    end

    notify(src, 'success', 'Vehicul achizitionat',
        string.format('%s (Nr. %s) a fost adaugat in flota.', modelCfg.label, plate))
    TriggerClientEvent('police:client:fleetVehicleAdded', src, vehicle)
end)

Sw.SecureEvent('police:server:sellFleetVehicle', {
    character = true,
    rateLimit = { max = 5, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local vehicleId = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasManagePerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea de management.')
        return
    end

    vehicleId = tonumber(vehicleId)
    local vehicle = PoliceDatabase.getFleetVehicle(vehicleId)
    if not vehicle then
        notify(src, 'error', 'Eroare', 'Vehiculul nu exista.')
        return
    end
    if not vehicle.is_available then
        notify(src, 'error', 'Indisponibil', 'Vehiculul este in uz si nu poate fi vandut.')
        return
    end

    local settings   = exports.police:GetPoliceSettings()
    local currencyId = tonumber(settings.vehicleCurrencyId) or 1
    local sellRatio  = tonumber(settings.vehicleSellRatio) or 0.6
    local sellPrice  = math.floor((tonumber(vehicle.purchase_price) or 0) * sellRatio)

    PoliceDatabase.deleteFleetVehicle(vehicleId)

    if sellPrice > 0 then
        exports.banking:orgSystemCredit('police', sellPrice, currencyId,
            'Vanzare vehicul: ' .. (vehicle.plate or '') .. ' - ' .. (vehicle.label or ''))
    end

    notify(src, 'success', 'Vehicul vandut',
        string.format('%s vandut pentru $%d.', vehicle.label, sellPrice))
    TriggerClientEvent('police:client:fleetVehicleRemoved', src, vehicleId)
end)

Sw.SecureEvent('police:server:addArmoryWeapon', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local itemName, label, ammoItem, ammoAmount = ctx.args[1], ctx.args[2], ctx.args[3], ctx.args[4]

    if not isPoliceOnDuty(char.id) or not hasManagePerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea de management.')
        return
    end
    itemName = tostring(itemName or ''):sub(1, 64)
    label    = tostring(label    or ''):sub(1, 64)
    if #itemName < 2 or #label < 1 then return end

    withArmoryLock(function()
        local settings = exports.police:GetPoliceSettings()
        for _, w in ipairs(settings.armoryWeapons) do
            if w.itemName == itemName then
                notify(src, 'error', 'Duplicat', 'Arma deja existenta in armament.')
                return
            end
        end
        table.insert(settings.armoryWeapons, {
            itemName   = itemName,
            label      = label,
            ammoItem   = ammoItem ~= '' and ammoItem or nil,
            ammoAmount = tonumber(ammoAmount) or 0
        })
        saveArmorySettings()
        notify(src, 'success', 'Armament', label .. ' adaugat.')
        TriggerClientEvent('police:client:armoryUpdated', src, {
            weapons   = settings.armoryWeapons,
            equipment = settings.armoryEquipment
        })
    end)
end)

Sw.SecureEvent('police:server:removeArmoryWeapon', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local itemName = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasManagePerm(char.id) then return end

    itemName = tostring(itemName or '')
    withArmoryLock(function()
        local settings = exports.police:GetPoliceSettings()
        settings.armoryWeapons = filterArmoryList(settings.armoryWeapons, itemName)
        saveArmorySettings()
        TriggerClientEvent('police:client:armoryUpdated', src, {
            weapons   = settings.armoryWeapons,
            equipment = settings.armoryEquipment
        })
    end)
end)

Sw.SecureEvent('police:server:addArmoryEquipment', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local itemName, label, amount = ctx.args[1], ctx.args[2], ctx.args[3]

    if not isPoliceOnDuty(char.id) or not hasManagePerm(char.id) then
        notify(src, 'error', 'Acces refuzat', 'Nu ai permisiunea de management.')
        return
    end
    itemName = tostring(itemName or ''):sub(1, 64)
    label    = tostring(label    or ''):sub(1, 64)
    if #itemName < 2 or #label < 1 then return end

    withArmoryLock(function()
        local settings = exports.police:GetPoliceSettings()
        for _, e in ipairs(settings.armoryEquipment) do
            if e.itemName == itemName then
                notify(src, 'error', 'Duplicat', 'Echipamentul deja exista.')
                return
            end
        end
        table.insert(settings.armoryEquipment, {
            itemName = itemName,
            label    = label,
            amount   = math.max(1, tonumber(amount) or 1)
        })
        saveArmorySettings()
        notify(src, 'success', 'Armament', label .. ' adaugat.')
        TriggerClientEvent('police:client:armoryUpdated', src, {
            weapons   = settings.armoryWeapons,
            equipment = settings.armoryEquipment
        })
    end)
end)

Sw.SecureEvent('police:server:removeArmoryEquipment', {
    character = true,
    rateLimit = { max = 10, window = 5000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local itemName = ctx.args[1]

    if not isPoliceOnDuty(char.id) or not hasManagePerm(char.id) then return end

    itemName = tostring(itemName or '')
    withArmoryLock(function()
        local settings = exports.police:GetPoliceSettings()
        settings.armoryEquipment = filterArmoryList(settings.armoryEquipment, itemName)
        saveArmorySettings()
        TriggerClientEvent('police:client:armoryUpdated', src, {
            weapons   = settings.armoryWeapons,
            equipment = settings.armoryEquipment
        })
    end)
end)

Sw.SecureEvent('police:server:saveJailTimer', {
    character = true,
    rateLimit = { max = 30, window = 10000 },
    silent = true,
}, function(ctx)
    local char = ctx.character
    local remaining = ctx.args[1]

    local data = activeJailTimers[char.id]
    if data then
        PoliceDatabase.updateRemainingTime(data.sentenceId, math.max(0, tonumber(remaining) or 0))
    end
end)
