local DEFAULT_CURRENCY_CODE = 'USD'

local function perm(source, node)
    return exports.core:hasPermission(source, 'admin.all')
        or exports.core:hasPermission(source, node)
end

local function notify(source, t, msg, duration)
    TriggerClientEvent('switcore:notify', source, t, msg, duration or 4000)
end

local function getPermSet(source)
    local nodes = {
        'admin.players.view', 'admin.players.moderate', 'admin.players.teleport',
        'admin.players.freeze', 'admin.players.spectate', 'admin.players.cash',
        'admin.players.groups', 'admin.players.bucket',
        'admin.players.inventory', 'admin.players.needs', 'admin.players.character',
        'admin.players.vehicles', 'admin.players.jobs',
        'admin.self.noclip', 'admin.self.godmode', 'admin.self.invisible',
        'admin.self.weapons', 'admin.self.cash', 'admin.self.heal',
        'admin.self.teleport', 'admin.self.overlay', 'admin.self.model',
        'admin.vehicle.spawn', 'admin.vehicle.delete', 'admin.vehicle.modify',
        'admin.world.time', 'admin.world.weather', 'admin.world.announce',
        'admin.world.resources',
        'admin.items.manage',
    }
    local out = {}
    for _, n in ipairs(nodes) do
        if perm(source, n) then out[n] = true end
    end
    return out
end

local function hasAnyOf(source, prefix)
    local perms = getPermSet(source)
    for k in pairs(perms) do
        if k:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function computeTabs(source)
    local tabs = {}
    if hasAnyOf(source, 'admin.players.') then tabs[#tabs + 1] = 'players' end
    if hasAnyOf(source, 'admin.self.')    then tabs[#tabs + 1] = 'self'    end
    if hasAnyOf(source, 'admin.vehicle.') then tabs[#tabs + 1] = 'vehicle' end
    if hasAnyOf(source, 'admin.world.')   then tabs[#tabs + 1] = 'world'   end
    if hasAnyOf(source, 'admin.items.')   then tabs[#tabs + 1] = 'items'   end
    return tabs
end

local function buildPlayerList()
    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local sid = tonumber(id)
        local pd  = exports.core:getPlayerData(sid)
        players[#players + 1] = {
            id     = sid,
            name   = GetPlayerName(id) or 'Unknown',
            ping   = GetPlayerPing(id),
            groups = (pd and pd.groups) or {},
            dbId   = pd and pd.dbId,
        }
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    return players
end

local function isOnline(target)
    return target and GetPlayerName(target) ~= nil
end

local function getCharacterIdSafe(source)
    local ok, charId = pcall(function() return exports.characters:getCharacterId(source) end)
    if ok then return charId end
    return nil
end

local function getDefaultCurrencyId()
    local ok, curr = pcall(function() return exports.banking:getCurrencyByCode(DEFAULT_CURRENCY_CODE) end)
    if ok and curr and curr.id then return curr.id end
    return nil
end

local function adminCreditBankAccount(characterId, currencyId, amount, description)
    local accounts = exports.banking:getCharacterAccounts(characterId)
    if not accounts or #accounts == 0 then return false, 'no_account' end

    local target = accounts[1]
    for _, acc in ipairs(accounts) do
        if acc.account_type == 'checking' then target = acc; break end
    end
    if not target or not target.id then return false, 'no_account' end

    local rows = exports.postgres:query([[
        UPDATE bank_accounts
        SET balance = COALESCE(balance, '{}'::jsonb)
            || jsonb_build_object($1::text, COALESCE((balance->>$1::text)::numeric, 0) + $2),
            updated_at = NOW()
        WHERE id = $3
        RETURNING id
    ]], { tostring(currencyId), amount, target.id })

    if not rows or not rows[1] then return false, 'db_error' end

    pcall(function()
        exports.banking:createTransaction(
            characterId, 'admin_grant', nil, target.id,
            amount, currencyId, 0, currencyId,
            description or 'Admin grant', { source = 'admin_menu' }
        )
    end)

    return true, target.account_number
end

local BucketRules = {
    [0]  = { noWanted = false, population = true,  lockdown = 'inactive', dispatch = true  },
    [1]  = { noWanted = true,  population = false, lockdown = 'strict',   dispatch = false },
    [10] = { noWanted = true,  population = true,  lockdown = 'inactive', dispatch = false },
}

local function applyBucketServerRules(bucketId)
    local r = BucketRules[bucketId]
    if not r then return end
    if SetRoutingBucketPopulationEnabled    then SetRoutingBucketPopulationEnabled(bucketId, r.population) end
    if SetRoutingBucketEntityLockdownMode   then SetRoutingBucketEntityLockdownMode(bucketId, r.lockdown)  end
end

local function setPlayerBucket(target, bucketId)
    SetPlayerRoutingBucket(target, bucketId)
    applyBucketServerRules(bucketId)
    local r = BucketRules[bucketId] or BucketRules[0]
    TriggerClientEvent('admin:bucket:applyRules', target, { noWanted = r.noWanted })
end

for bucketId in pairs(BucketRules) do
    applyBucketServerRules(bucketId)
end

exports('setPlayerBucket', setPlayerBucket)
exports('getPlayerBucket', function(source) return GetPlayerRoutingBucket(source) end)
exports('defineBucketRule', function(bucketId, rules)
    BucketRules[bucketId] = rules
    applyBucketServerRules(bucketId)
end)

RegisterNetEvent('admin:server:open', function()
    local src   = source
    local tabs  = computeTabs(src)
    local perms = getPermSet(src)
    if #tabs == 0 then
        notify(src, 'error', 'Acces interzis.')
        return
    end

    local currencies = {}
    local okCurr, list = pcall(function() return exports.banking:getActiveCurrencies() end)
    if okCurr and list then
        for _, c in ipairs(list) do
            currencies[#currencies + 1] = { id = c.id, code = c.code, symbol = c.symbol, name = c.name }
        end
    end

    local primaryCode = exports.settings:GetSetting('hud.primary_currency', DEFAULT_CURRENCY_CODE)
    local primarySymbol = '$'
    for _, c in ipairs(currencies) do
        if c.code == primaryCode then primarySymbol = c.symbol or primarySymbol; break end
    end

    local groups = {}
    if perms['admin.players.groups'] then
        local okGroups, gl = pcall(function() return exports.core:getAllGroups() end)
        if okGroups and gl then
            for _, g in ipairs(gl) do
                groups[#groups + 1] = { name = g.name, displayName = g.display_name or g.displayName or g.name }
            end
        end
    end

    TriggerClientEvent('admin:client:open', src, {
        tabs            = tabs,
        perms           = perms,
        players         = buildPlayerList(),
        currencies      = currencies,
        primaryCurrency = { code = primaryCode, symbol = primarySymbol },
        groups          = groups,
    })
end)

RegisterNetEvent('admin:server:getPlayers', function()
    local src = source
    if not perm(src, 'admin.players.view') then return end
    TriggerClientEvent('admin:client:updatePlayers', src, buildPlayerList())
end)

RegisterNetEvent('admin:server:getPlayerInfo', function(targetId)
    local src = source
    if not perm(src, 'admin.players.view') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then
        notify(src, 'error', 'Jucătorul nu a fost găsit.')
        return
    end
    local pd = exports.core:getPlayerData(targetId)
    if not pd then
        notify(src, 'error', 'Date indisponibile.')
        return
    end

    local ped    = GetPlayerPed(targetId)
    local coords = ped ~= 0 and GetEntityCoords(ped) or nil
    local heading = ped ~= 0 and GetEntityHeading(ped) or 0
    local bucket = GetPlayerRoutingBucket(targetId)

    local charId
    local okChar, ch = pcall(function() return exports.characters:getActiveCharacter(targetId) end)
    if okChar and ch then
        charId = ch.id
    end

    TriggerClientEvent('admin:client:playerInfo', src, {
        id          = targetId,
        name        = GetPlayerName(targetId) or 'Unknown',
        ping        = GetPlayerPing(targetId),
        identifiers = pd.identifiers or {},
        groups      = pd.groups or {},
        dbId        = pd.dbId,
        characterId = charId,
        coords      = coords and { x = coords.x, y = coords.y, z = coords.z } or nil,
        heading     = heading,
        bucket      = bucket,
    })
end)

RegisterNetEvent('admin:server:banPlayer', function(targetId, reason, duration)
    local src = source
    if not perm(src, 'admin.players.moderate') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    if not reason or reason == '' then return notify(src, 'error', 'Motivul este obligatoriu.') end
    local ok, err = exports.core:banPlayerBySource(targetId, src, reason, duration or 'permanent')
    if ok then
        notify(src, 'success', 'Jucător banat.')
    else
        notify(src, 'error', 'Ban eșuat: ' .. tostring(err))
    end
end)

RegisterNetEvent('admin:server:kickPlayer', function(targetId, reason)
    local src = source
    if not perm(src, 'admin.players.moderate') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    if not reason or reason == '' then return notify(src, 'error', 'Motivul este obligatoriu.') end
    local ok = exports.core:kickPlayerBySource(targetId, src, reason)
    if ok ~= false then
        notify(src, 'success', 'Jucător dat afară.')
    end
end)

RegisterNetEvent('admin:server:warnPlayer', function(targetId, reason)
    local src = source
    if not perm(src, 'admin.players.moderate') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    if not reason or reason == '' then return notify(src, 'error', 'Motivul este obligatoriu.') end
    local ok = exports.core:warnPlayerBySource(targetId, src, reason)
    if ok ~= false then
        notify(src, 'success', 'Warn trimis.')
    end
end)

RegisterNetEvent('admin:server:gotoPlayer', function(targetId)
    local src = source
    if not perm(src, 'admin.players.teleport') then return end
    targetId = tonumber(targetId)
    local ped = GetPlayerPed(targetId)
    if not ped or ped == 0 then return notify(src, 'error', 'Jucător invalid.') end
    local c = GetEntityCoords(ped)
    TriggerClientEvent('admin:client:teleport', src, { x = c.x + 0.5, y = c.y + 0.5, z = c.z })
end)

RegisterNetEvent('admin:server:bringPlayer', function(targetId)
    local src = source
    if not perm(src, 'admin.players.teleport') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    TriggerClientEvent('admin:client:teleport', targetId, { x = c.x + 1.5, y = c.y, z = c.z })
    notify(src, 'success', 'Jucător adus la tine.')
end)

RegisterNetEvent('admin:server:freezePlayer', function(targetId, frozen)
    local src = source
    if not perm(src, 'admin.players.freeze') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    TriggerClientEvent('admin:client:setFreeze', targetId, frozen and true or false)
    notify(src, 'success', frozen and 'Jucător înghețat.' or 'Jucător dezghețat.')
end)

local function doCashGrant(adminSrc, targetSrc, amount, target, currencyId)
    if not isOnline(targetSrc) then return notify(adminSrc, 'error', 'Țintă invalidă.') end
    amount = tonumber(amount)
    if not amount or amount == 0 then return notify(adminSrc, 'error', 'Sumă invalidă.') end

    local charId = getCharacterIdSafe(targetSrc)
    if not charId then return notify(adminSrc, 'error', 'Ținta nu are personaj activ.') end

    currencyId = tonumber(currencyId) or getDefaultCurrencyId()
    if not currencyId then return notify(adminSrc, 'error', 'Valută indisponibilă.') end

    if target == 'bank' then
        local ok, info = adminCreditBankAccount(charId, currencyId, amount, 'Admin grant')
        if not ok then
            if info == 'no_account' then return notify(adminSrc, 'error', 'Ținta nu are cont bancar.') end
            return notify(adminSrc, 'error', 'Creditare eșuată.')
        end
        notify(adminSrc, 'success', ('Bancă: %s în %s'):format(amount, info))
        notify(targetSrc, 'info', ('Ai primit %s în cont bancar.'):format(amount))
        logAdminAction(adminSrc, 'cash.grant.bank', targetSrc, { amount = amount, currencyId = currencyId, account = info })
    else
        exports.banking:addCharacterCash(charId, currencyId, amount)
        notify(adminSrc, 'success', ('Cash: %s acordat.'):format(amount))
        if targetSrc ~= adminSrc then
            notify(targetSrc, 'info', ('Ai primit %s cash.'):format(amount))
        end
        logAdminAction(adminSrc, 'cash.grant.cash', targetSrc, { amount = amount, currencyId = currencyId })
    end
end

RegisterNetEvent('admin:server:giveCashToPlayer', function(targetId, amount, target, currencyId)
    local src = source
    if not perm(src, 'admin.players.cash') then return end
    doCashGrant(src, tonumber(targetId), amount, target, currencyId)
end)

RegisterNetEvent('admin:server:giveCashToSelf', function(amount, target, currencyId)
    local src = source
    if not perm(src, 'admin.self.cash') then return end
    doCashGrant(src, src, amount, target, currencyId)
end)

RegisterNetEvent('admin:server:addGroup', function(targetId, groupName)
    local src = source
    if not perm(src, 'admin.players.groups') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) or not groupName or groupName == '' then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    local ok, err = exports.core:addPlayerGroup(targetId, groupName, nil, src)
    if ok ~= false then
        notify(src, 'success', 'Grup adăugat: ' .. groupName)
    else
        notify(src, 'error', 'Eroare: ' .. tostring(err))
    end
end)

RegisterNetEvent('admin:server:removeGroup', function(targetId, groupName)
    local src = source
    if not perm(src, 'admin.players.groups') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) or not groupName or groupName == '' then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    local ok, err = exports.core:removePlayerGroup(targetId, groupName)
    if ok ~= false then
        notify(src, 'success', 'Grup scos: ' .. groupName)
    else
        notify(src, 'error', 'Eroare: ' .. tostring(err))
    end
end)

RegisterNetEvent('admin:server:setBucket', function(targetId, bucketId)
    local src = source
    if not perm(src, 'admin.players.bucket') then return end
    targetId = tonumber(targetId); bucketId = tonumber(bucketId)
    if not isOnline(targetId) or not bucketId then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    setPlayerBucket(targetId, bucketId)
    notify(src, 'success', ('Bucket %d aplicat.'):format(bucketId))
end)

RegisterNetEvent('admin:server:teleportToWaypoint', function()
    local src = source
    if not perm(src, 'admin.self.teleport') then
        return notify(src, 'error', 'Acces interzis.')
    end
    TriggerClientEvent('admin:client:teleportToWaypoint', src)
end)

RegisterNetEvent('admin:server:teleportToCoords', function(x, y, z)
    local src = source
    if not perm(src, 'admin.self.teleport') then return end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not (x and y and z) then return notify(src, 'error', 'Coordonate invalide.') end
    TriggerClientEvent('admin:client:teleport', src, { x = x, y = y, z = z })
end)

RegisterNetEvent('admin:server:checkOverlayPermission', function()
    local src = source
    if perm(src, 'admin.self.overlay') then
        TriggerClientEvent('admin:client:toggleOverlay', src)
    else
        notify(src, 'error', 'Acces interzis.')
    end
end)

RegisterNetEvent('admin:server:syncTime', function(hour, minute, freeze)
    local src = source
    if not perm(src, 'admin.world.time') then return end
    hour   = tonumber(hour) or 12
    minute = tonumber(minute) or 0
    TriggerClientEvent('admin:client:syncTime', -1, hour, minute, freeze and true or false)
    notify(src, 'success', ('Timp setat la %02d:%02d'):format(hour, minute))
end)

RegisterNetEvent('admin:server:syncWeather', function(weather)
    local src = source
    if not perm(src, 'admin.world.weather') then return end
    if type(weather) ~= 'string' or weather == '' then return end
    TriggerClientEvent('admin:client:syncWeather', -1, weather)
    notify(src, 'success', 'Vreme: ' .. weather)
end)

RegisterNetEvent('admin:server:announce', function(message)
    local src = source
    if not perm(src, 'admin.world.announce') then return end
    if not message or message == '' then return end
    local who = GetPlayerName(src) or 'Admin'
    TriggerClientEvent('switcore:notify', -1, 'warning', ('[ANUNȚ] %s: %s'):format(who, message), 8000)
end)

RegisterNetEvent('admin:server:getResources', function()
    local src = source
    if not perm(src, 'admin.world.resources') then return end
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            list[#list + 1] = { name = name, state = GetResourceState(name) }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    TriggerClientEvent('admin:client:resourceList', src, list)
end)

RegisterNetEvent('admin:server:restartResource', function(resourceName)
    local src = source
    if not perm(src, 'admin.world.resources') then return end
    if not resourceName or resourceName == '' then return end
    if GetResourceState(resourceName) == 'missing' then
        return notify(src, 'error', 'Resursa nu există.')
    end
    StopResource(resourceName)
    Wait(400)
    StartResource(resourceName)
    notify(src, 'success', 'Restartat: ' .. resourceName)
end)

RegisterNetEvent('admin:server:startResource', function(resourceName)
    local src = source
    if not perm(src, 'admin.world.resources') then return end
    if not resourceName or resourceName == '' then return end
    StartResource(resourceName)
    notify(src, 'success', 'Pornit: ' .. resourceName)
end)

RegisterNetEvent('admin:server:stopResource', function(resourceName)
    local src = source
    if not perm(src, 'admin.world.resources') then return end
    if not resourceName or resourceName == '' then return end
    StopResource(resourceName)
    notify(src, 'success', 'Oprit: ' .. resourceName)
end)

local function getTargetCharacterId(adminSrc, targetId)
    if not isOnline(targetId) then
        notify(adminSrc, 'error', 'Țintă invalidă.')
        return nil
    end
    local charId = getCharacterIdSafe(targetId)
    if not charId then
        notify(adminSrc, 'error', 'Ținta nu are personaj activ.')
        return nil
    end
    return charId
end

local auditSchemaReady = false
CreateThread(function()
    while not exports.postgres:isReady() do Wait(500) end
    exports.postgres:query([[
        CREATE TABLE IF NOT EXISTS admin_audit_log (
            id          BIGSERIAL PRIMARY KEY,
            admin_src   INT,
            admin_name  TEXT,
            admin_db_id INT,
            action      TEXT NOT NULL,
            target_src  INT,
            target_name TEXT,
            details     JSONB,
            created_at  TIMESTAMP DEFAULT NOW()
        )
    ]], {})
    exports.postgres:query(
        'CREATE INDEX IF NOT EXISTS admin_audit_log_created_idx ON admin_audit_log (created_at DESC)',
        {}
    )
    auditSchemaReady = true
end)

local function logAdminAction(adminSrc, action, targetId, details)
    local adminName  = GetPlayerName(adminSrc) or 'console'
    local targetName = (targetId and GetPlayerName(targetId)) or nil
    local adminDbId  = (adminSrc and adminSrc > 0) and exports.core:getPlayerId(adminSrc) or nil

    print(('[ADMIN] %s (%s) -> %s on %s (%s) details=%s'):format(
        adminName, adminSrc, action, targetName or '-', targetId or '-', json.encode(details or {})
    ))

    if not auditSchemaReady then return end
    exports.postgres:query([[
        INSERT INTO admin_audit_log
            (admin_src, admin_name, admin_db_id, action, target_src, target_name, details)
        VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
    ]], {
        adminSrc, adminName, adminDbId, action, targetId, targetName,
        json.encode(details or {})
    })
end

local function buildInventoryPayload(charId)
    local invId = 'char:' .. tostring(charId)
    local inv = exports.inventory:GetInventory(invId)
    if not inv then return nil end

    local items = {}
    for slot, data in pairs(inv.slots or {}) do
        local cfg = exports.inventory:GetItemConfig(data.name)
        items[#items + 1] = {
            slot     = slot,
            name     = data.name,
            label    = (cfg and cfg.label) or data.name,
            amount   = data.amount,
            weight   = cfg and cfg.weight or 0,
            stackable = cfg and cfg.stackable or false,
            metadata = data.metadata or {},
        }
    end
    table.sort(items, function(a, b) return a.slot < b.slot end)

    return {
        invId     = invId,
        maxSlots  = inv.maxSlots,
        maxWeight = inv.maxWeight,
        items     = items,
    }
end

RegisterNetEvent('admin:server:getPlayerInventory', function(targetId)
    local src = source
    if not perm(src, 'admin.players.inventory') then return end
    targetId = tonumber(targetId)
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    local function send()
        local payload = buildInventoryPayload(charId)
        if not payload then
            return notify(src, 'error', 'Inventarul nu este încărcat.')
        end
        payload.targetId = targetId
        TriggerClientEvent('admin:client:playerInventory', src, payload)
    end

    local invId = 'char:' .. tostring(charId)
    if exports.inventory:GetInventory(invId) then
        send()
    else
        exports.inventory:LoadInventory(invId, function() send() end)
    end
end)

RegisterNetEvent('admin:server:getItemCatalog', function()
    local src = source
    if not perm(src, 'admin.players.inventory') then return end

    local catalog = {}
    local ok, rows = pcall(function()
        return exports.postgres:queryAll('SELECT name, label, weight, stackable FROM items ORDER BY label ASC', {})
    end)
    if ok and rows then
        for _, r in ipairs(rows) do
            catalog[#catalog + 1] = {
                name      = r.name,
                label     = r.label or r.name,
                weight    = tonumber(r.weight) or 0,
                stackable = r.stackable == true or r.stackable == 't' or r.stackable == 1,
            }
        end
    end
    TriggerClientEvent('admin:client:itemCatalog', src, catalog)
end)

local function ensureInventoryLoaded(charId, cb)
    local invId = 'char:' .. tostring(charId)
    if exports.inventory:GetInventory(invId) then
        cb(invId)
    else
        exports.inventory:LoadInventory(invId, function() cb(invId) end)
    end
end

RegisterNetEvent('admin:server:givePlayerItem', function(targetId, itemName, amount)
    local src = source
    if not perm(src, 'admin.players.inventory') then return end
    targetId = tonumber(targetId)
    amount = tonumber(amount) or 1
    if type(itemName) ~= 'string' or itemName == '' or amount <= 0 then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    ensureInventoryLoaded(charId, function(invId)
        local ok, err = exports.inventory:AddItem(invId, itemName, amount, nil, nil)
        if not ok then
            return notify(src, 'error', 'Adăugare eșuată: ' .. tostring(err))
        end
        logAdminAction(src, 'inventory.give', targetId, { item = itemName, amount = amount })
        notify(src, 'success', ('Adăugat %dx %s.'):format(amount, itemName))

        local payload = buildInventoryPayload(charId)
        if payload then
            payload.targetId = targetId
            TriggerClientEvent('admin:client:playerInventory', src, payload)
        end
    end)
end)

RegisterNetEvent('admin:server:takePlayerItem', function(targetId, itemName, amount, slot)
    local src = source
    if not perm(src, 'admin.players.inventory') then return end
    targetId = tonumber(targetId)
    amount = tonumber(amount) or 1
    if type(itemName) ~= 'string' or itemName == '' or amount <= 0 then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    ensureInventoryLoaded(charId, function(invId)
        local ok, err = exports.inventory:RemoveItem(invId, itemName, amount, tonumber(slot))
        if not ok then
            return notify(src, 'error', 'Ștergere eșuată: ' .. tostring(err))
        end
        logAdminAction(src, 'inventory.take', targetId, { item = itemName, amount = amount, slot = slot })
        notify(src, 'success', ('Șters %dx %s.'):format(amount, itemName))

        local payload = buildInventoryPayload(charId)
        if payload then
            payload.targetId = targetId
            TriggerClientEvent('admin:client:playerInventory', src, payload)
        end
    end)
end)

local function toBool(v)
    if type(v) == 'boolean' then return v end
    if type(v) == 'string'  then v = v:lower(); return v == 'true' or v == 't' or v == '1' or v == 'yes' end
    if type(v) == 'number'  then return v ~= 0 end
    return false
end

local function broadcastItemsCatalog(src)
    local ok, rows = pcall(function()
        return exports.postgres:queryAll(
            'SELECT name, label, weight, type, usable, stackable, description, image_url, drop_prop, drop_anim_dict, drop_anim_name FROM items ORDER BY name ASC',
            {}
        )
    end)
    local list = {}
    if ok and rows then
        for _, r in ipairs(rows) do
            list[#list + 1] = {
                name           = r.name,
                label          = r.label,
                weight         = tonumber(r.weight) or 0,
                type           = r.type,
                usable         = toBool(r.usable),
                stackable      = toBool(r.stackable),
                description    = r.description,
                image_url      = r.image_url,
                drop_prop      = r.drop_prop,
                drop_anim_dict = r.drop_anim_dict,
                drop_anim_name = r.drop_anim_name,
            }
        end
    end
    TriggerClientEvent('admin:client:itemsCatalog', src, list)
end

RegisterNetEvent('admin:server:getItemsCatalog', function()
    local src = source
    if not perm(src, 'admin.items.manage') then return end
    broadcastItemsCatalog(src)
end)

RegisterNetEvent('admin:server:saveItem', function(payload)
    local src = source
    if not perm(src, 'admin.items.manage') then return end
    if type(payload) ~= 'table' then return notify(src, 'error', 'Date invalide.') end

    local name = tostring(payload.name or ''):lower():gsub('%s+', '_')
    if name == '' or #name > 50 or not name:match('^[a-z0-9_]+$') then
        return notify(src, 'error', 'Nume invalid (doar a-z, 0-9, _, max 50).')
    end

    local label = tostring(payload.label or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if label == '' or #label > 100 then
        return notify(src, 'error', 'Label invalid (1-100 caractere).')
    end

    local weight = tonumber(payload.weight) or 0
    if weight < 0 or weight > 999.99 then
        return notify(src, 'error', 'Greutate invalidă (0-999.99).')
    end

    local itype = tostring(payload.type or 'misc'):lower()
    if itype == '' or #itype > 50 then itype = 'misc' end

    local usable    = toBool(payload.usable)
    local stackable = toBool(payload.stackable)
    local description = payload.description and tostring(payload.description) or nil

    local function cleanText(v, maxLen)
        if v == nil then return nil end
        local s = tostring(v):gsub('^%s+', ''):gsub('%s+$', '')
        if s == '' then return nil end
        if #s > maxLen then return nil, 'prea lung' end
        return s
    end

    local image_url      = cleanText(payload.image_url, 500)
    local drop_prop      = cleanText(payload.drop_prop, 100)
    local drop_anim_dict = cleanText(payload.drop_anim_dict, 100)
    local drop_anim_name = cleanText(payload.drop_anim_name, 100)

    if drop_prop and not drop_prop:match('^[%w_@%-]+$') then
        return notify(src, 'error', 'Drop prop invalid (doar litere, cifre, _, -, @).')
    end
    if drop_anim_dict and not drop_anim_dict:match('^[%w_@%-]+$') then
        return notify(src, 'error', 'Anim dict invalid.')
    end
    if drop_anim_name and not drop_anim_name:match('^[%w_@%-]+$') then
        return notify(src, 'error', 'Anim name invalid.')
    end

    local ok, err = pcall(function()
        exports.postgres:query([[
            INSERT INTO items (name, label, weight, type, usable, stackable, description, image_url, drop_prop, drop_anim_dict, drop_anim_name)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            ON CONFLICT (name) DO UPDATE SET
                label = EXCLUDED.label,
                weight = EXCLUDED.weight,
                type = EXCLUDED.type,
                usable = EXCLUDED.usable,
                stackable = EXCLUDED.stackable,
                description = EXCLUDED.description,
                image_url = EXCLUDED.image_url,
                drop_prop = EXCLUDED.drop_prop,
                drop_anim_dict = EXCLUDED.drop_anim_dict,
                drop_anim_name = EXCLUDED.drop_anim_name
        ]], { name, label, weight, itype, usable, stackable, description, image_url, drop_prop, drop_anim_dict, drop_anim_name })
    end)
    if not ok then return notify(src, 'error', 'Eroare DB: ' .. tostring(err)) end

    pcall(function() exports.inventory:ReloadItems() end)

    logAdminAction(src, 'items.save', nil, { name = name, label = label, type = itype })
    notify(src, 'success', 'Item salvat: ' .. name)
    broadcastItemsCatalog(src)
end)

RegisterNetEvent('admin:server:deleteItem', function(itemName)
    local src = source
    if not perm(src, 'admin.items.manage') then return end
    if type(itemName) ~= 'string' or itemName == '' then
        return notify(src, 'error', 'Nume invalid.')
    end

    local row = exports.postgres:queryOne(
        'SELECT COUNT(*) AS c FROM inventory_items WHERE item_name = $1',
        { itemName }
    )
    if row and tonumber(row.c) and tonumber(row.c) > 0 then
        return notify(src, 'error', ('Itemul este folosit de %d jucători. Nu se poate șterge.'):format(row.c))
    end

    local ok, err = pcall(function()
        exports.postgres:query('DELETE FROM items WHERE name = $1', { itemName })
    end)
    if not ok then return notify(src, 'error', 'Eroare DB: ' .. tostring(err)) end

    pcall(function() exports.inventory:ReloadItems() end)

    logAdminAction(src, 'items.delete', nil, { name = itemName })
    notify(src, 'success', 'Item șters: ' .. itemName)
    broadcastItemsCatalog(src)
end)

RegisterNetEvent('admin:server:reloadItemsCatalog', function()
    local src = source
    if not perm(src, 'admin.items.manage') then return end
    pcall(function() exports.inventory:ReloadItems() end)
    notify(src, 'success', 'Catalog reîncărcat.')
    broadcastItemsCatalog(src)
end)

RegisterNetEvent('admin:server:getPlayerNeeds', function(targetId)
    local src = source
    if not perm(src, 'admin.players.needs') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end

    local hunger, thirst = 0, 0
    local ok1, h = pcall(function() return exports.needs:GetHunger(targetId) end)
    if ok1 then hunger = tonumber(h) or 0 end
    local ok2, t = pcall(function() return exports.needs:GetThirst(targetId) end)
    if ok2 then thirst = tonumber(t) or 0 end

    local stats = {}
    local okS, st = pcall(function() return exports.characters:getCharacterStatistics(targetId) end)
    if okS and st then stats = st end

    TriggerClientEvent('admin:client:playerNeeds', src, {
        targetId = targetId,
        hunger   = hunger,
        thirst   = thirst,
        stats    = stats,
    })
end)

RegisterNetEvent('admin:server:setPlayerNeed', function(targetId, key, value)
    local src = source
    if not perm(src, 'admin.players.needs') then return end
    targetId = tonumber(targetId)
    value = tonumber(value)
    if not isOnline(targetId) or not value then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    value = math.max(0, math.min(100, value))

    if key == 'hunger' then
        exports.needs:SetHunger(targetId, value)
    elseif key == 'thirst' then
        exports.needs:SetThirst(targetId, value)
    else
        return notify(src, 'error', 'Cheie necunoscută: ' .. tostring(key))
    end
    logAdminAction(src, 'needs.set', targetId, { key = key, value = value })
    notify(src, 'success', ('%s setat la %d.'):format(key, value))
end)

local function clearMedicalState(targetId)
    pcall(function()
        if exports.ems:IsUnconscious(targetId) then
            exports.ems:RevivePlayer(targetId, nil)
        end
    end)
    pcall(function() exports.medical:TreatAllInjuries(targetId) end)
    pcall(function() exports.medical:CureAll(targetId) end)
end

RegisterNetEvent('admin:server:healTarget', function(targetId)
    local src = source
    if not perm(src, 'admin.players.needs') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    TriggerClientEvent('admin:client:applyHeal', targetId)
    pcall(function() exports.needs:SetHunger(targetId, 100); exports.needs:SetThirst(targetId, 100) end)
    clearMedicalState(targetId)
    logAdminAction(src, 'needs.heal', targetId, {})
    notify(src, 'success', 'Țintă vindecată.')
end)

RegisterNetEvent('admin:server:reviveTarget', function(targetId)
    local src = source
    if not perm(src, 'admin.players.needs') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end
    TriggerClientEvent('admin:client:applyRevive', targetId)
    clearMedicalState(targetId)
    logAdminAction(src, 'needs.revive', targetId, {})
    notify(src, 'success', 'Țintă reînviată.')
end)

RegisterNetEvent('admin:server:healSelf', function()
    local src = source
    if not perm(src, 'admin.self.heal') then return end
    clearMedicalState(src)
    pcall(function() exports.needs:SetHunger(src, 100); exports.needs:SetThirst(src, 100) end)
    logAdminAction(src, 'self.heal', src, {})
end)

RegisterNetEvent('admin:server:reviveSelf', function()
    local src = source
    if not perm(src, 'admin.self.heal') then return end
    clearMedicalState(src)
    logAdminAction(src, 'self.revive', src, {})
end)

RegisterNetEvent('admin:server:getPlayerCharacterInfo', function(targetId)
    local src = source
    if not perm(src, 'admin.players.character') then return end
    targetId = tonumber(targetId)
    if not isOnline(targetId) then return notify(src, 'error', 'Țintă invalidă.') end

    local pd = exports.core:getPlayerData(targetId)
    local active
    local okA, ch = pcall(function() return exports.characters:getActiveCharacter(targetId) end)
    if okA then active = ch end

    local characters = {}
    if pd and pd.dbId then
        local okL, rows = pcall(function()
            return exports.postgres:queryAll(
                'SELECT id, first_name, last_name, age, last_played, created_at FROM characters WHERE player_id = $1 ORDER BY last_played DESC NULLS LAST, created_at DESC',
                { pd.dbId }
            )
        end)
        if okL and rows then
            for _, r in ipairs(rows) do
                characters[#characters + 1] = {
                    id        = r.id,
                    firstName = r.first_name,
                    lastName  = r.last_name,
                    age       = r.age,
                    lastPlayed = r.last_played and tostring(r.last_played) or nil,
                    createdAt = r.created_at and tostring(r.created_at) or nil,
                }
            end
        end
    end

    local ped = GetPlayerPed(targetId)
    local coords = ped ~= 0 and GetEntityCoords(ped) or nil

    TriggerClientEvent('admin:client:playerCharacterInfo', src, {
        targetId   = targetId,
        active     = active and {
            id        = active.id,
            firstName = active.first_name or active.firstname,
            lastName  = active.last_name or active.lastname,
            age       = active.age,
            gender    = active.gender or (active.metadata and active.metadata.gender),
        } or nil,
        characters = characters,
        coords     = coords and { x = coords.x, y = coords.y, z = coords.z } or nil,
    })
end)

RegisterNetEvent('admin:server:teleportTargetToCoords', function(targetId, x, y, z)
    local src = source
    if not perm(src, 'admin.players.character') then return end
    targetId = tonumber(targetId)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not isOnline(targetId) or not (x and y and z) then
        return notify(src, 'error', 'Parametri invalizi.')
    end
    TriggerClientEvent('admin:client:teleport', targetId, { x = x, y = y, z = z })
    logAdminAction(src, 'character.teleport', targetId, { x = x, y = y, z = z })
    notify(src, 'success', ('Țintă teleportată la (%.1f, %.1f, %.1f).'):format(x, y, z))
end)

RegisterNetEvent('admin:server:getPlayerVehicles', function(targetId)
    local src = source
    if not perm(src, 'admin.players.vehicles') then return end
    targetId = tonumber(targetId)
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    local list = {}
    local ok, vehs = pcall(function() return exports.vehicles:getCharacterVehicles(charId) end)
    if ok and vehs then
        for _, v in ipairs(vehs) do
            list[#list + 1] = {
                id        = v.id,
                plate     = v.plate,
                model     = v.model,
                label     = v.label or v.model,
                category  = v.category,
                stored    = v.stored == true,
                impounded = v.impounded == true,
                mileage   = tonumber(v.mileage) or 0,
                fuel      = tonumber(v.fuel) or 0,
            }
        end
    end
    TriggerClientEvent('admin:client:playerVehicles', src, { targetId = targetId, vehicles = list })
end)

RegisterNetEvent('admin:server:spawnPlayerVehicle', function(targetId, vehicleId)
    local src = source
    if not perm(src, 'admin.players.vehicles') then return end
    targetId = tonumber(targetId); vehicleId = tonumber(vehicleId)
    if not isOnline(targetId) or not vehicleId then return notify(src, 'error', 'Parametri invalizi.') end
    local ok, err = exports.vehicles:spawnVehicleForPlayer(targetId, vehicleId)
    if not ok then return notify(src, 'error', 'Spawn eșuat: ' .. tostring(err)) end
    logAdminAction(src, 'vehicles.spawn', targetId, { vehicleId = vehicleId })
    notify(src, 'success', 'Vehicul spawnat la țintă.')
end)

RegisterNetEvent('admin:server:impoundPlayerVehicle', function(vehicleId, reason)
    local src = source
    if not perm(src, 'admin.players.vehicles') then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return notify(src, 'error', 'ID invalid.') end
    exports.vehicles:impoundVehicle(vehicleId, reason or 'Admin impound')
    logAdminAction(src, 'vehicles.impound', nil, { vehicleId = vehicleId, reason = reason })
    notify(src, 'success', 'Vehicul sechestrat.')
end)

RegisterNetEvent('admin:server:releasePlayerVehicle', function(vehicleId)
    local src = source
    if not perm(src, 'admin.players.vehicles') then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return notify(src, 'error', 'ID invalid.') end
    exports.vehicles:releaseVehicle(vehicleId)
    logAdminAction(src, 'vehicles.release', nil, { vehicleId = vehicleId })
    notify(src, 'success', 'Vehicul eliberat.')
end)

RegisterNetEvent('admin:server:setVehicleFuelAdmin', function(vehicleId, amount)
    local src = source
    if not perm(src, 'admin.players.vehicles') then return end
    vehicleId = tonumber(vehicleId); amount = tonumber(amount)
    if not vehicleId or not amount then return notify(src, 'error', 'Parametri invalizi.') end
    amount = math.max(0, math.min(100, amount))
    exports.vehicles:setVehicleFuel(vehicleId, amount)
    logAdminAction(src, 'vehicles.fuel', nil, { vehicleId = vehicleId, amount = amount })
    notify(src, 'success', ('Combustibil setat la %d%%.'):format(amount))
end)

RegisterNetEvent('admin:server:getJobsCatalog', function()
    local src = source
    if not perm(src, 'admin.players.jobs') then return end

    local catalog = {}
    local okJ, jobs = pcall(function() return exports.postgres:queryAll(
        'SELECT name, label, type FROM jobs WHERE is_active = TRUE ORDER BY label ASC', {}) end)
    if okJ and jobs then
        for _, j in ipairs(jobs) do
            local grades = {}
            local okG, gl = pcall(function() return exports.postgres:queryAll(
                'SELECT grade, label, salary FROM job_grades WHERE job_name = $1 ORDER BY grade ASC',
                { j.name }) end)
            if okG and gl then
                for _, g in ipairs(gl) do
                    grades[#grades + 1] = {
                        grade  = tonumber(g.grade) or 0,
                        label  = g.label or ('Grade ' .. tostring(g.grade)),
                        salary = tonumber(g.salary) or 0,
                    }
                end
            end
            catalog[#catalog + 1] = {
                name   = j.name,
                label  = j.label or j.name,
                type   = j.type,
                grades = grades,
            }
        end
    end
    TriggerClientEvent('admin:client:jobsCatalog', src, catalog)
end)

RegisterNetEvent('admin:server:getPlayerJob', function(targetId)
    local src = source
    if not perm(src, 'admin.players.jobs') then return end
    targetId = tonumber(targetId)
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    local job
    local ok, j = pcall(function() return exports.jobs:GetCharacterJob(charId) end)
    if ok and j then job = j end

    TriggerClientEvent('admin:client:playerJob', src, {
        targetId = targetId,
        job      = job and {
            name      = job.job_name or job.name,
            label     = job.job_label or job.label,
            grade     = tonumber(job.grade) or 0,
            gradeLabel = job.grade_label,
            salary    = tonumber(job.salary) or 0,
            onDuty    = job.is_on_duty == true,
        } or nil,
    })
end)

RegisterNetEvent('admin:server:setPlayerJob', function(targetId, jobName, grade)
    local src = source
    if not perm(src, 'admin.players.jobs') then return end
    targetId = tonumber(targetId)
    grade = tonumber(grade) or 0
    if type(jobName) ~= 'string' or jobName == '' then
        return notify(src, 'error', 'Job invalid.')
    end
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    local ok = pcall(function() exports.jobs:SetCharacterJob(charId, jobName, grade) end)
    if not ok then return notify(src, 'error', 'Setare job eșuată.') end
    logAdminAction(src, 'jobs.set', targetId, { job = jobName, grade = grade })
    notify(src, 'success', ('Job setat: %s (grad %d).'):format(jobName, grade))
    notify(targetId, 'info', ('Job nou: %s (grad %d).'):format(jobName, grade))
end)

RegisterNetEvent('admin:server:firePlayer', function(targetId)
    local src = source
    if not perm(src, 'admin.players.jobs') then return end
    targetId = tonumber(targetId)
    local charId = getTargetCharacterId(src, targetId)
    if not charId then return end

    local defaultJob = exports.settings:GetSetting('jobs.default_job', 'unemployed')
    local defaultGrade = exports.settings:GetSettingNumber('jobs.default_grade', 0)
    pcall(function() exports.jobs:SetCharacterJob(charId, defaultJob, defaultGrade) end)
    logAdminAction(src, 'jobs.fire', targetId, {})
    notify(src, 'success', 'Țintă concediată.')
    notify(targetId, 'warning', 'Ai fost concediat de un admin.')
end)

RegisterCommand('tpm', function(src)
    if src == 0 then return end
    if not perm(src, 'admin.self.teleport') then
        return notify(src, 'error', 'Acces interzis.')
    end
    TriggerClientEvent('admin:client:teleportToWaypoint', src)
end, false)
