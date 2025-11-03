Config = {}

-- Identifiers care vor fi ignorate (low-trust/high-variance)
Config.IDENTIFIER_BLOCKLIST = {
    ['ip'] = true
}

-- Interval pentru actualizarea playtime în baza de date (în secunde)
Config.PLAYTIME_UPDATE_INTERVAL = 60

-- Activează logging-ul comenzilor
Config.LOG_COMMANDS = true

return Config

