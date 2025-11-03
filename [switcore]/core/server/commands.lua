CommandLogger = {}

local function shouldLogCommands()
    return Config and Config.LOG_COMMANDS ~= false
end

function CommandLogger.logCommand(source, commandName, args, metadata)
    if not shouldLogCommands() then
        return false
    end
    
    local player = PlayerCache.getFromCache(source)
    if not player then
        return false
    end
    
    local logMetadata = metadata or {}
    if args then
        logMetadata.args = args
    end
    
    return Database.logActivity(
        player.dbId,
        'command',
        commandName,
        logMetadata
    )
end

function CommandLogger.registerCommand(commandName, handler, restricted)
    RegisterCommand(commandName, function(source, args, rawCommand)
        handler(source, args, rawCommand)
        
        CommandLogger.logCommand(source, commandName, args, {
            rawCommand = rawCommand
        })
    end, restricted)
    
    return commandName
end

return CommandLogger

