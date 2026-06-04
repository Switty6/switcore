-- Logging centralizat controlat de setarea core.log_level. Un mesaj se afiseaza
-- doar daca nivelul lui e cel putin cel configurat, asa ca pe productie pui
-- 'warn' si consola ramane curata fara sa scoti apelurile din cod.
-- Folosit prin exports.core:log(level, tag, mesaj).

Logger = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }

function Logger._configuredLevel()
    local name = exports.settings:GetSetting('core.log_level', 'info')
    return LEVELS[tostring(name):lower()] or LEVELS.info
end

function Logger.shouldLog(level)
    return (LEVELS[level] or LEVELS.info) >= Logger._configuredLevel()
end

function Logger.log(level, tag, message)
    level = tostring(level):lower()
    if not LEVELS[level] then
        level = 'info'
    end

    if not Logger.shouldLog(level) then
        return
    end

    print(string.format('[%s] [%s] %s', tostring(tag or 'CORE'), level:upper(), tostring(message)))
end

function Logger.debug(tag, message) Logger.log('debug', tag, message) end
function Logger.info(tag, message) Logger.log('info', tag, message) end
function Logger.warn(tag, message) Logger.log('warn', tag, message) end
function Logger.error(tag, message) Logger.log('error', tag, message) end

return Logger
