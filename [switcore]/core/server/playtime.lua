PlaytimeTracker = {}

local playtimeTimers = {}
local updateInterval = 60

function PlaytimeTracker.startTracking(source)
    source = tostring(source)
    local player = PlayerCache.getFromCache(source)
    
    if not player then
        return false
    end
    
    playtimeTimers[source] = {
        startTime = os.time(),
        totalPlaytime = player.playtime or 0
    }
    
    return true
end

function PlaytimeTracker.stopTracking(source)
    source = tostring(source)
    local timer = playtimeTimers[source]
    
    if timer then
        local elapsed = os.time() - timer.startTime
        local newPlaytime = timer.totalPlaytime + elapsed
        
        PlayerCache.updateInCache(source, {playtime = newPlaytime})
        
        playtimeTimers[source] = nil
        
        return newPlaytime
    end
    
    return nil
end

function PlaytimeTracker.getCurrentPlaytime(source)
    source = tostring(source)
    local timer = playtimeTimers[source]
    
    if not timer then
        local player = PlayerCache.getFromCache(source)
        return player and player.playtime or 0
    end
    
    local elapsed = os.time() - timer.startTime
    return timer.totalPlaytime + elapsed
end

function PlaytimeTracker.updateAllPlaytimes()
    local timersToRemove = {}
    local entries = {}
    local sourcesById = {}
    local now = os.time()

    for source, timer in pairs(playtimeTimers) do
        local player = PlayerCache.getFromCache(source)
        if player then
            local newPlaytime = timer.totalPlaytime + (now - timer.startTime)
            entries[#entries + 1] = { dbId = player.dbId, seconds = newPlaytime }
            sourcesById[player.dbId] = { source = source, newPlaytime = newPlaytime }
        else
            timersToRemove[#timersToRemove + 1] = source
        end
    end

    if #entries > 0 then
        local ok = Database.updatePlayerPlaytimes(entries)
        if ok then
            for _, info in pairs(sourcesById) do
                PlayerCache.updateInCache(info.source, { playtime = info.newPlaytime })
                playtimeTimers[info.source] = {
                    startTime = now,
                    totalPlaytime = info.newPlaytime
                }
            end
        else
            print('[CORE] Batch playtime esuat (' .. #entries .. ' randuri), timerele nu sunt resetate; retry la urmatorul tick')
        end
    end

    for _, source in ipairs(timersToRemove) do
        playtimeTimers[source] = nil
    end
end

function PlaytimeTracker.setUpdateInterval(interval)
    updateInterval = interval
end

function PlaytimeTracker.isTracking(source)
    source = tostring(source)
    return playtimeTimers[source] ~= nil
end

CreateThread(function()
    while true do
        Wait(updateInterval * 1000)
        
        PlaytimeTracker.updateAllPlaytimes()
    end
end)

return PlaytimeTracker

