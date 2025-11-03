PlaytimeTracker = {}

local playtimeTimers = {}  -- playtimeTimers[source] = {startTime, totalPlaytime}
local updateInterval = 60   -- secunde

-- Inițializează tracking-ul pentru un jucător
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

-- Oprește tracking-ul pentru un jucător
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

-- Obține playtime-ul curent pentru un jucător (din cache + timpul curent)
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

-- Actualizează playtime-ul în DB pentru toți jucătorii activi
function PlaytimeTracker.updateAllPlaytimes()
    for source, timer in pairs(playtimeTimers) do
        local elapsed = os.time() - timer.startTime
        local newPlaytime = timer.totalPlaytime + elapsed
        
        local player = PlayerCache.getFromCache(source)
        if player then
            PlayerCache.updateInCache(source, {playtime = newPlaytime})
            
            Database.updatePlayerPlaytime(player.dbId, newPlaytime)
            
            playtimeTimers[source] = {
                startTime = os.time(),
                totalPlaytime = newPlaytime
            }
        end
    end
end

-- Setează intervalul de actualizare
function PlaytimeTracker.setUpdateInterval(interval)
    updateInterval = interval
end

-- Obține intervalul de actualizare
function PlaytimeTracker.getUpdateInterval()
    return updateInterval
end

-- Inițializează thread-ul de actualizare periodică
CreateThread(function()
    while true do
        Wait(updateInterval * 1000)
        
        PlaytimeTracker.updateAllPlaytimes()
    end
end)

return PlaytimeTracker

