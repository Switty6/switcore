Moderation = {}

-- Helper pentru a găsi un jucător după source (online)
local function findPlayerBySource(source)
    if not source then
        return nil
    end
    
    local sourceNum = tonumber(source)
    if not sourceNum then
        return nil
    end
    
    local player = PlayerCache.getFromCache(sourceNum)
    return player, sourceNum
end

-- Helper pentru a găsi un jucător după nume (doar online)
local function findPlayerByName(name)
    if not name then
        return nil, nil
    end
    
    local allPlayers = PlayerCache.getAllPlayers()
    local matches = {}
    for src, player in pairs(allPlayers) do
        if player.name and string.lower(player.name) == string.lower(name) then
            table.insert(matches, {player = player, source = tonumber(src)})
        end
    end
    
    if #matches == 1 then
        return matches[1].player, matches[1].source
    elseif #matches > 1 then
        return matches[1].player, matches[1].source
    end
    
    return nil, nil
end

-- Helper pentru a găsi jucător după target (source sau nume)
local function findPlayerByTarget(target)
    if not target then
        return nil, nil
    end
    
    local source = tonumber(target)
    if source then
        local player, src = findPlayerBySource(source)
        if player then
            return player, src
        end
    end
    
    return findPlayerByName(target)
end

-- Helper pentru a obține jucător după dbId (din DB)
local function getPlayerByDbId(dbId)
    if not dbId then
        return nil
    end
    
    local source = PlayerCache.getSourceById(dbId)
    if source then
        local player = PlayerCache.getFromCache(source)
        if player then
            return player, source
        end
    end
    
    local postgres = exports.postgres
    if postgres and postgres:isReady() then
        local result = postgres:queryOne(
            'SELECT * FROM players WHERE id = $1',
            {dbId}
        )
        if result then
            local identifiers = Database.getPlayerIdentifiers(result.id)
            return {
                dbId = result.id,
                name = result.name,
                identifiers = identifiers,
                last_seen = result.last_seen,
                playtime = result.playtime or 0,
                created_at = result.created_at
            }, nil
        end
    end
    
    return nil, nil
end

-- Helper pentru a parsa durata (ex: "1d", "2h", "30m", "1d2h30m")
-- Daacă nu e setat, returnează nil - adica permanent
-- Dacă este setat, returnează timestamp-ul viitor
-- Daca e pus doar un numar, consideram ca e in ore.
local function parseDuration(durationStr)
    if not durationStr or durationStr == '' or string.lower(durationStr) == 'permanent' or string.lower(durationStr) == 'perm' then
        return nil -- Permanent
    end
    
    -- Parsează formatul: "1d2h30m" sau "1d", "2h", "30m"
    local totalSeconds = 0
    
    local days = durationStr:match('(%d+)d')
    if days then
        totalSeconds = totalSeconds + (tonumber(days) * 86400)
    end
    
    local hours = durationStr:match('(%d+)h')
    if hours then
        totalSeconds = totalSeconds + (tonumber(hours) * 3600)
    end
    
    local minutes = durationStr:match('(%d+)m')
    if minutes then
        totalSeconds = totalSeconds + (tonumber(minutes) * 60)
    end
    
    if totalSeconds == 0 then
        local duration = tonumber(durationStr)
        if duration then
            totalSeconds = duration * 3600
        end
    end
    
    if totalSeconds > 0 then
        return os.time() + totalSeconds
    end
    
    return nil
end

-- Helper pentru a formata durata
local function formatDuration(expiresAt)
    if not expiresAt then
        return 'permanent'
    end
    
    local now = os.time()
    local remaining = expiresAt - now
    
    if remaining <= 0 then
        return 'expired'
    end
    
    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    
    local parts = {}
    if days > 0 then
        table.insert(parts, days .. 'd')
    end
    if hours > 0 then
        table.insert(parts, hours .. 'h')
    end
    if minutes > 0 then
        table.insert(parts, minutes .. 'm')
    end
    
    if #parts == 0 then
        return 'expired'
    end
    
    return table.concat(parts, ' ')
end

-- Ban un jucător după source (pentru jucători online)
function Moderation.banPlayerBySource(source, bannedBySource, reason, durationStr)
    local targetPlayer, targetSource = findPlayerBySource(source)
    if not targetPlayer then
        return false, Localize('moderation.player_not_found_online')
    end
    
    local existingBan = Database.getActiveBan(targetPlayer.dbId)
    if existingBan then
        return false, Localize('moderation.player_already_banned')
    end
    
    local bannedById = nil
    if bannedBySource then
        local bannedByPlayer = PlayerCache.getFromCache(bannedBySource)
        if bannedByPlayer then
            bannedById = bannedByPlayer.dbId
        end
    end
    
    local expiresAt = parseDuration(durationStr)
    
    local ban = Database.createBan(targetPlayer.dbId, bannedById, reason or (targetSource and Localize('moderation.no_reason', targetSource) or 'No reason'), expiresAt, {
        target_name = targetPlayer.name,
        duration_str = durationStr,
        target_source = targetSource
    })
    
    if not ban then
        return false, Localize('moderation.error_creating_ban')
    end
    
    local banMessage = Localize('moderation.you_were_banned', targetSource)
    if reason then
        banMessage = banMessage .. Localize('moderation.banned_for', targetSource, reason)
    end
    if expiresAt then
        banMessage = banMessage .. Localize('moderation.expires_in', targetSource, formatDuration(expiresAt))
    else
        banMessage = banMessage .. Localize('moderation.ban_permanent', targetSource)
    end
    
    DropPlayer(targetSource, banMessage)
    
    return true, ban
end

-- Ban un jucător după dbId (pentru jucători offline sau direct după ID)
function Moderation.banPlayerByDbId(dbId, bannedBySource, reason, durationStr)
    local targetPlayer, targetSource = getPlayerByDbId(dbId)
    if not targetPlayer then
        return false, Localize('moderation.player_not_found_db')
    end
    
    local existingBan = Database.getActiveBan(targetPlayer.dbId)
    if existingBan then
        return false, Localize('moderation.player_already_banned')
    end
    
    local bannedById = nil
    if bannedBySource then
        local bannedByPlayer = PlayerCache.getFromCache(bannedBySource)
        if bannedByPlayer then
            bannedById = bannedByPlayer.dbId
        end
    end
    
    local expiresAt = parseDuration(durationStr)
    
    local ban = Database.createBan(targetPlayer.dbId, bannedById, reason or (targetSource and Localize('moderation.no_reason', targetSource) or 'No reason'), expiresAt, {
        target_name = targetPlayer.name,
        duration_str = durationStr,
        target_source = targetSource
    })
    
    if not ban then
        return false, Localize('moderation.error_creating_ban')
    end
    
    if targetSource then
        local banMessage = Localize('moderation.you_were_banned', targetSource)
        if reason then
            banMessage = banMessage .. Localize('moderation.banned_for', targetSource, reason)
        end
        if expiresAt then
            banMessage = banMessage .. Localize('moderation.expires_in', targetSource, formatDuration(expiresAt))
        else
            banMessage = banMessage .. Localize('moderation.ban_permanent', targetSource)
        end
        
        DropPlayer(targetSource, banMessage)
    end
    
    return true, ban
end

-- Unban un jucător după dbId
function Moderation.unbanPlayerByDbId(dbId, unbannedBySource, reason)
    local targetPlayer, targetSource = getPlayerByDbId(dbId)
    if not targetPlayer then
        return false, Localize('moderation.player_not_found_db')
    end
    
    local activeBan = Database.getActiveBan(targetPlayer.dbId)
    if not activeBan then
        return false, Localize('moderation.player_no_active_ban')
    end
    
    local unbannedById = nil
    if unbannedBySource then
        local unbannedByPlayer = PlayerCache.getFromCache(unbannedBySource)
        if unbannedByPlayer then
            unbannedById = unbannedByPlayer.dbId
        end
    end
    
    local success = Database.unban(activeBan.id, unbannedById, reason or (targetSource and Localize('moderation.unban_reason', targetSource) or 'Manual unban'))
    
    if not success then
        return false, Localize('moderation.error_unban')
    end
    
    return true, activeBan
end

-- Unban un jucător (compatibilitate)
function Moderation.unbanPlayer(target, unbannedBySource, reason)
    local targetPlayer, targetSource = findPlayerByTarget(target)
    if not targetPlayer then
        local dbId = tonumber(target)
        if dbId then
            return Moderation.unbanPlayerByDbId(dbId, unbannedBySource, reason)
        end
        return false, Localize('moderation.player_not_found')
    end
    
    return Moderation.unbanPlayerByDbId(targetPlayer.dbId, unbannedBySource, reason)
end

-- Warn un jucător după source
function Moderation.warnPlayerBySource(source, warnedBySource, reason)
    local targetPlayer, targetSource = findPlayerBySource(source)
    if not targetPlayer then
        return false, Localize('moderation.player_not_online')
    end
    
    local warnedById = nil
    if warnedBySource then
        local warnedByPlayer = PlayerCache.getFromCache(warnedBySource)
        if warnedByPlayer then
            warnedById = warnedByPlayer.dbId
        end
    end
    
    local warn = Database.createWarn(targetPlayer.dbId, warnedById, reason or (targetSource and Localize('moderation.no_reason', targetSource) or 'No reason'), {
        target_name = targetPlayer.name,
        target_source = targetSource
    })
    
    if not warn then
        return false, Localize('moderation.error_creating_warn')
    end
    
    TriggerClientEvent('chat:addMessage', targetSource, {
        color = {255, 165, 0},
        multiline = true,
        args = {'[WARN]', Localize('moderation.you_received_warning', targetSource, reason or Localize('moderation.no_reason', targetSource))}
    })
    
    return true, warn
end

-- Warn un jucător după dbId
function Moderation.warnPlayerByDbId(dbId, warnedBySource, reason)
    local targetPlayer, targetSource = getPlayerByDbId(dbId)
    if not targetPlayer then
        return false, Localize('moderation.player_not_found_db')
    end
    
    local warnedById = nil
    if warnedBySource then
        local warnedByPlayer = PlayerCache.getFromCache(warnedBySource)
        if warnedByPlayer then
            warnedById = warnedByPlayer.dbId
        end
    end
    
    local warn = Database.createWarn(targetPlayer.dbId, warnedById, reason or (targetSource and Localize('moderation.no_reason', targetSource) or 'No reason'), {
        target_name = targetPlayer.name,
        target_source = targetSource
    })
    
    if not warn then
        return false, Localize('moderation.error_creating_warn')
    end
    
    if targetSource then
        TriggerClientEvent('chat:addMessage', targetSource, {
            color = {255, 165, 0},
            multiline = true,
            args = {'[WARN]', Localize('moderation.you_received_warning', targetSource, reason or Localize('moderation.no_reason', targetSource))}
        })
    end
    
    return true, warn
end

-- Warn un jucător (compatibilitate)
function Moderation.warnPlayer(target, warnedBySource, reason)
    local targetPlayer, targetSource = findPlayerByTarget(target)
    if not targetPlayer then
        return false, Localize('moderation.player_not_found_use_warnid')
    end
    
    return Moderation.warnPlayerByDbId(targetPlayer.dbId, warnedBySource, reason)
end

-- Remove warn
function Moderation.removeWarn(warnId, removedBySource, reason)
    local removedById = nil
    if removedBySource then
        local removedByPlayer = PlayerCache.getFromCache(removedBySource)
        if removedByPlayer then
            removedById = removedByPlayer.dbId
        end
    end
    
    local success = Database.removeWarn(warnId, removedById, reason or (removedBySource and Localize('moderation.removed_manual', removedBySource) or 'Manually removed'))
    
    if not success then
        return false, Localize('moderation.error_removing_warn')
    end
    
    return true
end

-- Kick un jucător după source
function Moderation.kickPlayerBySource(source, kickedBySource, reason)
    local targetPlayer, targetSource = findPlayerBySource(source)
    if not targetPlayer then
        return false, Localize('moderation.player_not_online')
    end
    
    local kickedById = nil
    if kickedBySource then
        local kickedByPlayer = PlayerCache.getFromCache(kickedBySource)
        if kickedByPlayer then
            kickedById = kickedByPlayer.dbId
        end
    end
    
    Database.logKick(targetPlayer.dbId, kickedById, reason or (targetSource and Localize('moderation.no_reason', targetSource) or 'No reason'), {
        target_name = targetPlayer.name,
        target_source = targetSource
    })
    
    local kickMessage = Localize('moderation.you_were_kicked', targetSource)
    if reason then
        kickMessage = kickMessage .. Localize('moderation.kicked_reason', targetSource, reason)
    end
    
    DropPlayer(targetSource, kickMessage)
    
    return true
end

-- Kick un jucător (compatibilitate)
function Moderation.kickPlayer(target, kickedBySource, reason)
    local targetPlayer, targetSource = findPlayerByTarget(target)
    if not targetPlayer or not targetSource then
        return false, Localize('moderation.player_not_online')
    end
    
    return Moderation.kickPlayerBySource(targetSource, kickedBySource, reason)
end

-- Obține ban-urile unui jucător după dbId
function Moderation.getPlayerBansByDbId(dbId, includeInactive)
    local targetPlayer = getPlayerByDbId(dbId)
    if not targetPlayer then
        return nil, Localize('moderation.player_not_found_db')
    end
    
    local bans = Database.getPlayerBans(targetPlayer.dbId, includeInactive)
    return bans
end

-- Obține ban-urile unui jucător (compatibilitate)
function Moderation.getPlayerBans(target, includeInactive)
    local targetPlayer, targetSource = findPlayerByTarget(target)
    if not targetPlayer then
        local dbId = tonumber(target)
        if dbId then
            return Moderation.getPlayerBansByDbId(dbId, includeInactive)
        end
        return nil, Localize('moderation.player_not_found')
    end
    
    return Moderation.getPlayerBansByDbId(targetPlayer.dbId, includeInactive)
end

-- Obține warn-urile unui jucător după dbId
function Moderation.getPlayerWarnsByDbId(dbId, includeInactive)
    local targetPlayer = getPlayerByDbId(dbId)
    if not targetPlayer then
        return nil, Localize('moderation.player_not_found_db')
    end
    
    local warns = Database.getPlayerWarns(targetPlayer.dbId, includeInactive)
    return warns
end

-- Obține warn-urile unui jucător (compatibilitate)
function Moderation.getPlayerWarns(target, includeInactive)
    local targetPlayer, targetSource = findPlayerByTarget(target)
    if not targetPlayer then
        local dbId = tonumber(target)
        if dbId then
            return Moderation.getPlayerWarnsByDbId(dbId, includeInactive)
        end
        return nil, Localize('moderation.player_not_found')
    end
    
    return Moderation.getPlayerWarnsByDbId(targetPlayer.dbId, includeInactive)
end

-- Verifică dacă un jucător este banat după dbId
function Moderation.isPlayerBannedByDbId(dbId)
    local ban = Database.getActiveBan(dbId)
    if ban then
        return true, ban
    end
    return false, nil
end

-- Verifică dacă un jucător este banat (compatibilitate)
function Moderation.isPlayerBanned(target)
    local targetPlayer, targetSource = findPlayerByTarget(target)
    if not targetPlayer then
        local dbId = tonumber(target)
        if dbId then
            return Moderation.isPlayerBannedByDbId(dbId)
        end
        return false, nil
    end
    
    return Moderation.isPlayerBannedByDbId(targetPlayer.dbId)
end

return Moderation


