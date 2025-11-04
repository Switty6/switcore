Permissions = {}

-- Verifică dacă un jucător are o permisiune
function Permissions.hasPermission(source, permission)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    -- Verifică în cache
    if player.permissions then
        for _, perm in ipairs(player.permissions) do
            if perm == permission then
                return true
            end
            -- Suport pentru wildcard (ex: admin.all permite tot ce începe cu admin. Să notez asta în docs)
            local prefix = perm:match('^([^.]+)%.all$')
            if prefix then
                if permission:match('^' .. prefix:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1') .. '%..*') then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Verifică dacă un jucător are unul dintre grupurile specificate
function Permissions.hasGroup(source, groupName)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    if player.groups then
        for _, group in ipairs(player.groups) do
            if group.name == groupName then
                if not group.expires_at then
                    return true
                end

                if type(group.expires_at) == 'string' then
                    -- Parsează timestamp-ul PostgreSQL
                    local year, month, day, hour, min, sec = group.expires_at:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
                    if year and month and day and hour and min and sec then
                        local expiresTime = os.time({
                            year = tonumber(year),
                            month = tonumber(month),
                            day = tonumber(day),
                            hour = tonumber(hour),
                            min = tonumber(min),
                            sec = tonumber(sec)
                        })
                        if expiresTime > os.time() then
                            return true
                        end
                    end
                elseif type(group.expires_at) == 'number' then
                    if group.expires_at > os.time() then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Obține toate permisiunile unui jucător
function Permissions.getPlayerPermissions(source)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return {}
    end
    
    return player.permissions or {}
end

-- Obține toate grupurile unui jucător
function Permissions.getPlayerGroups(source)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return {}
    end
    
    return player.groups or {}
end

-- Reîncarcă permisiunile unui jucător din DB
function Permissions.reloadPlayerPermissions(source)
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    local groups = Database.getPlayerGroups(player.dbId)
    local permissions = Database.getPlayerPermissions(player.dbId)
    
    PlayerCache.updateInCache(source, {
        groups = groups,
        permissions = permissions
    })
    
    return true
end

return Permissions

