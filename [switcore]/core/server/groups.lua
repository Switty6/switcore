Groups = {}

local groupsCache = {}
local groupsById = {}

function Groups.initializeDefaults()
    if not Config or not Config.DefaultGroups then
        return
    end
    
    print('[CORE] Inițializăm grupurile default...')
    
    for _, groupData in ipairs(Config.DefaultGroups) do
        local group = Database.findOrCreateGroup(
            groupData.name,
            groupData.display_name,
            groupData.priority,
            groupData.description
        )
        
        if group then
            groupsCache[group.name] = group
            groupsById[group.id] = group
            print('[CORE] Grup inițializat: ' .. group.display_name .. ' (' .. group.name .. ')')
        end
    end
    
    if Config.DefaultGroupPermissions then
        for groupName, permissions in pairs(Config.DefaultGroupPermissions) do
            local group = groupsCache[groupName]
            if not group then
                group = Database.findGroupByName(groupName)
                if group then
                    groupsCache[group.name] = group
                    groupsById[group.id] = group
                end
            end
            
            if group then
                for _, permissionName in ipairs(permissions) do
                    local permission = Database.findOrCreatePermission(permissionName)
                    if permission then
                        Database.addPermissionToGroup(group.id, permission.id)
                    end
                end
            end
        end
    end
    
    print('[CORE] Grupurile default au fost inițializate')
end

function Groups.getGroupByName(groupName)
    if groupsCache[groupName] then
        return groupsCache[groupName]
    end
    
    local group = Database.findGroupByName(groupName)
    if group then
        groupsCache[group.name] = group
        groupsById[group.id] = group
        return group
    end
    
    return nil
end

function Groups.getGroupById(groupId)
    if groupsById[groupId] then return groupsById[groupId] end
    local group = Database.findGroupById(groupId)
    if group then
        groupsCache[group.name] = group
        groupsById[group.id] = group
    end
    return group
end

function Groups.createGroup(groupName, displayName, priority, description)
    local group = Database.findOrCreateGroup(groupName, displayName, priority, description)
    
    if group then
        groupsCache[group.name] = group
        groupsById[group.id] = group
    end
    
    return group
end

function Groups.getAllGroups()
    local result = {}
    for _, group in pairs(groupsCache) do
        table.insert(result, group)
    end
    return result
end

function Groups.deleteGroup(groupName)
    local group = Groups.getGroupByName(groupName)
    if not group then
        return false
    end
    
    local success = Database.deleteGroup(group.id)
    if success then
        groupsCache[group.name] = nil
        groupsById[group.id] = nil
    end
    
    return success
end

function Groups.updateGroup(groupName, displayName, priority, description)
    local group = Groups.getGroupByName(groupName)
    if not group then
        return false
    end
    
    local success = Database.updateGroup(group.id, displayName, priority, description)
    if success then
        if displayName then group.display_name = displayName end
        if priority then group.priority = priority end
        if description then group.description = description end
    end
    
    return success
end

return Groups
