Database = {}

local function getPostgres()
    return exports.postgres
end

local function encodeJson(data)
    if not data then return nil end
    local ok, encoded = pcall(json.encode, data)
    if ok then return encoded end
    print('[CORE] encodeJson fail: ' .. tostring(encoded))
    return nil
end

local function ensurePostgres()
    local postgres = getPostgres()
    if not postgres then
        error('[CORE] Postgres resursa nu este disponibilă!')
        return false
    end
    
    if not postgres:isReady() then
        error('[CORE] Postgres nu este inițializat!')
        return false
    end
    
    return true
end

local function buildIdentifierList(identifierRows)
    local identifierList = {}
    for _, idRow in ipairs(identifierRows) do
        table.insert(identifierList, idRow.type .. ':' .. idRow.value)
    end
    return identifierList
end

function Database.findPlayerByIdentifier(identifier)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local idType, idValue = identifier:match('([^:]+):(.+)')
    if not idType or not idValue then
        return nil
    end
    
    local result = postgres:queryOne(
        'SELECT player_id FROM player_identifiers WHERE type = $1 AND value = $2',
        {idType, idValue}
    )
    
    if not result then
        return nil
    end
    
    local playerId = result.player_id
    
    local player = postgres:queryOne(
        'SELECT * FROM players WHERE id = $1',
        {playerId}
    )
    
    if not player then
        return nil
    end
    
    local identifiers = postgres:queryAll(
        'SELECT type, value FROM player_identifiers WHERE player_id = $1',
        {playerId}
    )
    
    return {
        dbId = player.id,
        name = player.name,
        identifiers = buildIdentifierList(identifiers),
        last_seen = player.last_seen,
        playtime = player.playtime or 0,
        created_at = player.created_at,
        language = player.language
    }
end

function Database.createPlayer(identifiers, name)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    for _, identifier in ipairs(identifiers) do
        local existingPlayer = Database.findPlayerByIdentifier(identifier)
        if existingPlayer then
            print('[CORE] Jucătorul există deja (detectat în createPlayer): ID ' .. existingPlayer.dbId)
            return existingPlayer
        end
    end
    
    local playerResult = postgres:query(
        'INSERT INTO players (name, created_at, updated_at, last_seen, playtime) VALUES ($1, NOW(), NOW(), NOW(), 0) RETURNING *',
        {name}
    )
    
    if not playerResult or not playerResult.rows or not playerResult.rows[1] then
        print('[CORE] Eroare la crearea jucătorului în DB')
        return nil
    end
    
    local player = playerResult.rows[1]
    
    local playerId = player.id
    
    local identifierList = {}
    for _, identifier in ipairs(identifiers) do
        local idType, idValue = identifier:match('([^:]+):(.+)')
        if idType and idValue then
            local success, err = pcall(function()
                postgres:query(
                    'INSERT INTO player_identifiers (player_id, type, value, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (type, value) DO NOTHING',
                    {playerId, idType, idValue}
                )
            end)
            
            if not success then
                print('[CORE] Eroare la inserarea identifier-ului ' .. identifier .. ' pentru jucătorul ' .. playerId .. ': ' .. tostring(err))
            end
            
            table.insert(identifierList, identifier)
        end
    end
    
    return {
        dbId = player.id,
        name = player.name,
        identifiers = identifierList,
        last_seen = player.last_seen,
        playtime = player.playtime or 0,
        created_at = player.created_at
    }
end

function Database.updatePlayerIdentifiers(dbId, identifiers)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    for _, identifier in ipairs(identifiers) do
        local idType, idValue = identifier:match('([^:]+):(.+)')
        if idType and idValue then
            local success, err = pcall(function()
                postgres:query(
                    'INSERT INTO player_identifiers (player_id, type, value, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (type, value) DO NOTHING',
                    {dbId, idType, idValue}
                )
            end)
            
            if not success then
                print('[CORE] Eroare la actualizarea identifier-ului ' .. identifier .. ' pentru jucătorul ' .. dbId .. ': ' .. tostring(err))
            end
        end
    end
    
    return true
end

function Database.updatePlayerLastSeen(dbId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    postgres:query(
        'UPDATE players SET last_seen = NOW(), updated_at = NOW() WHERE id = $1',
        {dbId}
    )
    
    return true
end

function Database.updatePlayerLanguage(dbId, language)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE players SET language = $1, updated_at = NOW() WHERE id = $2',
            {language, dbId}
        )
    end)
    
    if not success then
        print('[CORE] Eroare la actualizarea limbii jucătorului ' .. dbId .. ': ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.updatePlayerPlaytime(dbId, seconds)
    if not ensurePostgres() then return false end
    local postgres = getPostgres()
    local ok, err = pcall(function()
        postgres:query(
            'UPDATE players SET playtime = $1, updated_at = NOW() WHERE id = $2',
            {seconds, dbId}
        )
    end)
    if not ok then
        print('[CORE] Eroare la actualizarea playtime pentru ' .. tostring(dbId) .. ': ' .. tostring(err))
        return false
    end
    return true
end

function Database.updatePlayerPlaytimes(entries)
    if not entries or #entries == 0 then return true end
    if not ensurePostgres() then return false end
    local postgres = getPostgres()

    local values = {}
    local params = {}
    for i, e in ipairs(entries) do
        local idIdx  = (i - 1) * 2 + 1
        local secIdx = idIdx + 1
        values[#values + 1] = '($' .. idIdx .. '::bigint, $' .. secIdx .. '::bigint)'
        params[#params + 1] = e.dbId
        params[#params + 1] = e.seconds
    end

    local sql = [[
        UPDATE players AS p
        SET playtime = v.seconds, updated_at = NOW()
        FROM (VALUES ]] .. table.concat(values, ', ') .. [[) AS v(id, seconds)
        WHERE p.id = v.id
    ]]

    local ok, err = pcall(function() postgres:query(sql, params) end)
    if not ok then
        print('[CORE] Eroare batch playtime (' .. #entries .. ' randuri): ' .. tostring(err))
        return false
    end
    return true
end

function Database.logActivity(dbId, eventType, command, metadata)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local metadataJson = encodeJson(metadata)

    local query, params
    if metadataJson then
        if command then
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, metadata, created_at) VALUES ($1, $2, $3, $4::jsonb, NOW())'
            params = {dbId, eventType, command, metadataJson}
        else
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, metadata, created_at) VALUES ($1, $2, NULL, $3::jsonb, NOW())'
            params = {dbId, eventType, metadataJson}
        end
    else
        if command then
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, created_at) VALUES ($1, $2, $3, NOW())'
            params = {dbId, eventType, command}
        else
            query = 'INSERT INTO player_activity_log (player_id, event_type, command, created_at) VALUES ($1, $2, NULL, NOW())'
            params = {dbId, eventType}
        end
    end
    
    postgres:query(query, params)
    
    return true
end

function Database.getPlayerIdentifiers(dbId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local identifiers = postgres:queryAll(
        'SELECT type, value FROM player_identifiers WHERE player_id = $1',
        {dbId}
    )
    
    return buildIdentifierList(identifiers)
end

function Database.findOrCreateGroup(groupName, displayName, priority, description)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local group = postgres:queryOne(
        'SELECT * FROM groups WHERE name = $1',
        {groupName}
    )
    
    if group then
        return {
            id = group.id,
            name = group.name,
            display_name = group.display_name,
            priority = group.priority,
            description = group.description
        }
    end
    
    local result = postgres:query(
        'INSERT INTO groups (name, display_name, priority, description, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING *',
        {groupName, displayName or groupName, priority or 0, description}
    )
    
    if not result or not result.rows or not result.rows[1] then
        return nil
    end
    
    local newGroup = result.rows[1]
    return {
        id = newGroup.id,
        name = newGroup.name,
        display_name = newGroup.display_name,
        priority = newGroup.priority,
        description = newGroup.description
    }
end

function Database.findPermission(permissionName)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local permission = postgres:queryOne(
        'SELECT * FROM permissions WHERE name = $1',
        {permissionName}
    )
    
    if not permission then
        return nil
    end
    
    return {
        id = permission.id,
        name = permission.name,
        description = permission.description
    }
end

function Database.findOrCreatePermission(permissionName, description)
    local permission = Database.findPermission(permissionName)
    if permission then
        return permission
    end
    
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local desc = description or ''
    local result = postgres:query(
        'INSERT INTO permissions (name, description, created_at) VALUES ($1, $2, NOW()) RETURNING *',
        {permissionName, desc}
    )
    
    if not result or not result.rows or not result.rows[1] then
        return nil
    end
    
    local newPermission = result.rows[1]
    return {
        id = newPermission.id,
        name = newPermission.name,
        description = newPermission.description
    }
end

function Database.addPermissionToGroup(groupId, permissionId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'INSERT INTO group_permissions (group_id, permission_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT (group_id, permission_id) DO NOTHING',
            {groupId, permissionId}
        )
    end)
    
    if not success then
        print('[CORE] Eroare la adăugarea permisiunii la grup: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.getGroupPermissions(groupId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local permissions = postgres:queryAll(
        'SELECT p.id, p.name, p.description FROM permissions p INNER JOIN group_permissions gp ON p.id = gp.permission_id WHERE gp.group_id = $1',
        {groupId}
    )
    
    local result = {}
    for _, perm in ipairs(permissions) do
        table.insert(result, {
            id = perm.id,
            name = perm.name,
            description = perm.description
        })
    end
    
    return result
end

function Database.getPlayerGroups(dbId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local groups = postgres:queryAll(
        'SELECT g.id, g.name, g.display_name, g.priority, pg.assigned_at, pg.expires_at FROM groups g INNER JOIN player_groups pg ON g.id = pg.group_id WHERE pg.player_id = $1 AND (pg.expires_at IS NULL OR pg.expires_at > NOW()) ORDER BY g.priority DESC',
        {dbId}
    )
    
    local result = {}
    for _, group in ipairs(groups) do
        table.insert(result, {
            id = group.id,
            name = group.name,
            display_name = group.display_name,
            priority = group.priority,
            assigned_at = group.assigned_at,
            expires_at = group.expires_at
        })
    end
    
    return result
end

function Database.getPlayerPermissions(dbId)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local permissions = postgres:queryAll(
        'SELECT DISTINCT p.id, p.name, p.description FROM permissions p INNER JOIN group_permissions gp ON p.id = gp.permission_id INNER JOIN player_groups pg ON gp.group_id = pg.group_id WHERE pg.player_id = $1 AND (pg.expires_at IS NULL OR pg.expires_at > NOW())',
        {dbId}
    )
    
    local result = {}
    for _, perm in ipairs(permissions) do
        table.insert(result, perm.name)
    end
    
    return result
end

function Database.addGroupToPlayer(dbId, groupId, assignedBy, expiresAt)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'INSERT INTO player_groups (player_id, group_id, assigned_at, assigned_by, expires_at) VALUES ($1, $2, NOW(), $3, $4) ON CONFLICT (player_id, group_id) DO UPDATE SET expires_at = $4, assigned_at = NOW()',
            {dbId, groupId, assignedBy or json.null, expiresAt or json.null}
        )
    end)
    
    if not success then
        print('[CORE] Eroare la adăugarea grupului la jucător: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.removeGroupFromPlayer(dbId, groupId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    postgres:query(
        'DELETE FROM player_groups WHERE player_id = $1 AND group_id = $2',
        {dbId, groupId}
    )
    
    return true
end

function Database.findGroupByName(groupName)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local group = postgres:queryOne(
        'SELECT * FROM groups WHERE name = $1',
        {groupName}
    )
    
    if not group then
        return nil
    end
    
    return {
        id = group.id,
        name = group.name,
        display_name = group.display_name,
        priority = group.priority,
        description = group.description
    }
end

function Database.deleteGroup(groupId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query('DELETE FROM groups WHERE id = $1', {groupId})
    end)
    
    if not success then
        print('[CORE] Eroare la ștergerea grupului: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.updateGroup(groupId, displayName, priority, description)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local updates = {}
    local params = {groupId}
    local paramCount = 1
    
    if displayName then
        paramCount = paramCount + 1
        table.insert(updates, 'display_name = $' .. paramCount)
        table.insert(params, displayName)
    end
    
    if priority then
        paramCount = paramCount + 1
        table.insert(updates, 'priority = $' .. paramCount)
        table.insert(params, priority)
    end
    
    if description then
        paramCount = paramCount + 1
        table.insert(updates, 'description = $' .. paramCount)
        table.insert(params, description)
    end
    
    if #updates == 0 then
        return false
    end
    
    table.insert(updates, 'updated_at = NOW()')
    
    local query = 'UPDATE groups SET ' .. table.concat(updates, ', ') .. ' WHERE id = $1'
    
    local success, err = pcall(function()
        postgres:query(query, params)
    end)
    
    if not success then
        print('[CORE] Eroare la actualizarea grupului: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.removePermissionFromGroup(groupId, permissionId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'DELETE FROM group_permissions WHERE group_id = $1 AND permission_id = $2',
            {groupId, permissionId}
        )
    end)
    
    if not success then
        print('[CORE] Eroare la eliminarea permisiunii din grup: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.getAllGroups()
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local groups = postgres:queryAll('SELECT * FROM groups ORDER BY priority DESC')
    
    local result = {}
    for _, group in ipairs(groups) do
        table.insert(result, {
            id = group.id,
            name = group.name,
            display_name = group.display_name,
            priority = group.priority,
            description = group.description
        })
    end
    
    return result
end

function Database.getAllPermissions()
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local permissions = postgres:queryAll('SELECT * FROM permissions ORDER BY name')
    
    local result = {}
    for _, perm in ipairs(permissions) do
        table.insert(result, {
            id = perm.id,
            name = perm.name,
            description = perm.description
        })
    end
    
    return result
end

function Database.deletePermission(permissionId)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query('DELETE FROM permissions WHERE id = $1', {permissionId})
    end)
    
    if not success then
        print('[CORE] Eroare la ștergerea permisiunii: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.createBan(playerId, bannedById, reason, expiresAt, metadata)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local metadataJson = encodeJson(metadata)

    local query, params

    if expiresAt and type(expiresAt) == 'number' then
        query = 'INSERT INTO bans (player_id, banned_by, reason, expires_at, is_active, created_at, metadata) VALUES ($1, $2, $3, TO_TIMESTAMP($4), true, NOW(), $5::jsonb) RETURNING *'
        params = {playerId, bannedById, reason, expiresAt, metadataJson}
    else
        query = 'INSERT INTO bans (player_id, banned_by, reason, expires_at, is_active, created_at, metadata) VALUES ($1, $2, $3, $4, true, NOW(), $5::jsonb) RETURNING *'
        params = {playerId, bannedById, reason, expiresAt, metadataJson}
    end
    
    local result = postgres:query(query, params)
    
    if not result or not result.rows or not result.rows[1] then
        return nil
    end
    
    local ban = result.rows[1]
    return {
        id = ban.id,
        player_id = ban.player_id,
        banned_by = ban.banned_by,
        reason = ban.reason,
        expires_at = ban.expires_at,
        is_active = ban.is_active,
        created_at = ban.created_at,
        metadata = ban.metadata
    }
end

function Database.getActiveBan(playerId)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local ban = postgres:queryOne(
        'SELECT * FROM bans WHERE player_id = $1 AND is_active = true AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC LIMIT 1',
        {playerId}
    )
    
    if not ban then
        return nil
    end
    
    return {
        id = ban.id,
        player_id = ban.player_id,
        banned_by = ban.banned_by,
        reason = ban.reason,
        expires_at = ban.expires_at,
        is_active = ban.is_active,
        unbanned_by = ban.unbanned_by,
        unbanned_at = ban.unbanned_at,
        unbanned_reason = ban.unbanned_reason,
        created_at = ban.created_at,
        metadata = ban.metadata
    }
end

function Database.getActiveBanByIdentifier(identifier)
    if not ensurePostgres() then
        return nil
    end
    
    local player = Database.findPlayerByIdentifier(identifier)
    if not player then
        return nil
    end
    
    return Database.getActiveBan(player.dbId)
end

function Database.getPlayerBans(playerId, includeInactive)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local query = 'SELECT * FROM bans WHERE player_id = $1'
    local params = {playerId}
    
    if not includeInactive then
        query = query .. ' AND is_active = true'
    end
    
    query = query .. ' ORDER BY created_at DESC'
    
    local bans = postgres:queryAll(query, params)
    
    local result = {}
    for _, ban in ipairs(bans) do
        table.insert(result, {
            id = ban.id,
            player_id = ban.player_id,
            banned_by = ban.banned_by,
            reason = ban.reason,
            expires_at = ban.expires_at,
            is_active = ban.is_active,
            unbanned_by = ban.unbanned_by,
            unbanned_at = ban.unbanned_at,
            unbanned_reason = ban.unbanned_reason,
            created_at = ban.created_at,
            metadata = ban.metadata
        })
    end
    
    return result
end

function Database.unban(banId, unbannedById, reason)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE bans SET is_active = false, unbanned_by = $1, unbanned_at = NOW(), unbanned_reason = $2 WHERE id = $3',
            {unbannedById, reason, banId}
        )
    end)
    
    if not success then
        print('[CORE] Eroare la unban: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.createWarn(playerId, warnedById, reason, metadata)
    if not ensurePostgres() then
        return nil
    end
    
    local postgres = getPostgres()
    
    local metadataJson = encodeJson(metadata)

    local result = postgres:query(
        'INSERT INTO warns (player_id, warned_by, reason, is_active, created_at, metadata) VALUES ($1, $2, $3, true, NOW(), $4::jsonb) RETURNING *',
        {playerId, warnedById, reason, metadataJson}
    )
    
    if not result or not result.rows or not result.rows[1] then
        return nil
    end
    
    local warn = result.rows[1]
    return {
        id = warn.id,
        player_id = warn.player_id,
        warned_by = warn.warned_by,
        reason = warn.reason,
        is_active = warn.is_active,
        removed_by = warn.removed_by,
        removed_at = warn.removed_at,
        removed_reason = warn.removed_reason,
        created_at = warn.created_at,
        metadata = warn.metadata
    }
end

function Database.getPlayerWarns(playerId, includeInactive)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    local query = 'SELECT * FROM warns WHERE player_id = $1'
    local params = {playerId}
    
    if not includeInactive then
        query = query .. ' AND is_active = true'
    end
    
    query = query .. ' ORDER BY created_at DESC'
    
    local warns = postgres:queryAll(query, params)
    
    local result = {}
    for _, warn in ipairs(warns) do
        table.insert(result, {
            id = warn.id,
            player_id = warn.player_id,
            warned_by = warn.warned_by,
            reason = warn.reason,
            is_active = warn.is_active,
            removed_by = warn.removed_by,
            removed_at = warn.removed_at,
            removed_reason = warn.removed_reason,
            created_at = warn.created_at,
            metadata = warn.metadata
        })
    end
    
    return result
end

function Database.removeWarn(warnId, removedById, reason)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local success, err = pcall(function()
        postgres:query(
            'UPDATE warns SET is_active = false, removed_by = $1, removed_at = NOW(), removed_reason = $2 WHERE id = $3',
            {removedById, reason, warnId}
        )
    end)
    
    if not success then
        print('[CORE] Eroare la eliminarea warn-ului: ' .. tostring(err))
        return false
    end
    
    return true
end

function Database.logKick(playerId, kickedById, reason, metadata)
    if not ensurePostgres() then
        return false
    end
    
    local postgres = getPostgres()
    
    local metadataJson = encodeJson(metadata)

    postgres:query(
        'INSERT INTO kick_logs (player_id, kicked_by, reason, created_at, metadata) VALUES ($1, $2, $3, NOW(), $4::jsonb)',
        {playerId, kickedById, reason, metadataJson}
    )
    
    return true
end

function Database.getPlayerKickLogs(playerId, limit)
    if not ensurePostgres() then
        return {}
    end
    
    local postgres = getPostgres()
    
    limit = limit or 50
    
    local kicks = postgres:queryAll(
        'SELECT * FROM kick_logs WHERE player_id = $1 ORDER BY created_at DESC LIMIT $2',
        {playerId, limit}
    )
    
    local result = {}
    for _, kick in ipairs(kicks) do
        table.insert(result, {
            id = kick.id,
            player_id = kick.player_id,
            kicked_by = kick.kicked_by,
            reason = kick.reason,
            created_at = kick.created_at,
            metadata = kick.metadata
        })
    end
    
    return result
end

function Database.findPlayerById(dbId)
    if not ensurePostgres() then return nil end
    local postgres = getPostgres()
    local result = postgres:queryOne('SELECT * FROM players WHERE id = $1', {dbId})
    if not result then return nil end
    return {
        dbId = result.id,
        name = result.name,
        identifiers = Database.getPlayerIdentifiers(result.id),
        last_seen = result.last_seen,
        playtime = result.playtime or 0,
        created_at = result.created_at
    }
end

function Database.findGroupById(groupId)
    if not ensurePostgres() then return nil end
    local postgres = getPostgres()
    local group = postgres:queryOne('SELECT * FROM groups WHERE id = $1', {groupId})
    if not group then return nil end
    return {
        id = group.id,
        name = group.name,
        display_name = group.display_name,
        priority = group.priority,
        description = group.description
    }
end

function Database.deactivateExpiredBans(reason)
    if not ensurePostgres() then return 0 end
    local postgres = getPostgres()
    local expired = postgres:queryAll(
        'SELECT id FROM bans WHERE is_active = true AND expires_at IS NOT NULL AND expires_at <= NOW()', {}
    )
    if not expired or #expired == 0 then return 0 end
    for _, ban in ipairs(expired) do
        Database.unban(ban.id, nil, reason)
    end
    return #expired
end

return Database

