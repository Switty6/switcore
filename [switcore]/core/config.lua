Config = {}

-- Identifiers care vor fi ignorate (low-trust/high-variance)
Config.IDENTIFIER_BLOCKLIST = {
    ['ip'] = true
}

-- Interval pentru actualizarea playtime în baza de date (în secunde)
Config.PLAYTIME_UPDATE_INTERVAL = 60

-- Activează logging-ul comenzilor
Config.LOG_COMMANDS = true

-- ==================== LOCALIZATION ====================

-- Limba implicită pentru server (ro = română, en = engleză)
Config.DEFAULT_LANGUAGE = 'ro'

-- ==================== PERMISIUNI ȘI GRUPURI ====================

-- Grupuri default care vor fi create automat
Config.DefaultGroups = {
    {
        name = 'player',
        display_name = 'Player',
        priority = 0,
        description = 'Grupul default pentru toți jucătorii'
    },
    {
        name = 'vip',
        display_name = 'VIP',
        priority = 10,
        description = 'Grupul pentru jucători VIP'
    },
    {
        name = 'moderator',
        display_name = 'Moderator',
        priority = 50,
        description = 'Grupul pentru moderatori'
    },
    {
        name = 'admin',
        display_name = 'Administrator',
        priority = 100,
        description = 'Grupul pentru administratori'
    }
}

-- Permisiuni default pentru fiecare grup
Config.DefaultGroupPermissions = {
    ['admin'] = {
        'admin.all',
        'admin.kick',
        'admin.ban',
        'admin.warn',
        'admin.teleport',
        'admin.vehicle',
        'admin.money',
        'admin.weapon'
    },
    ['moderator'] = {
        'moderator.kick',
        'moderator.warn',
        'moderator.ban',
        'moderator.teleport'
    },
    ['vip'] = {
        'vip.vehicle',
        'vip.weapon'
    },
    ['player'] = {} -- Fără permisiuni speciale
}

return Config

