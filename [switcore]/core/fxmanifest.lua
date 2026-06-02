version '1.0.0'
description 'Core - Sistemul de player management (core an plm)'
author 'Switty'

fx_version 'bodacious'
game 'common'

dependencies {
    'postgres',
    'settings'
}

shared_script 'config.lua'

shared_scripts {
    'shared/lib.lua',
    'shared/localization.lua'
}

server_scripts {
    'server/ratelimit.lua',
    'server/secure.lua',
    'server/localization.lua',
    'server/player_cache.lua',
    'server/database.lua',
    'server/playtime.lua',
    'server/groups.lua',
    'server/permissions.lua',
    'server/moderation.lua',
    'server/commands.lua',
    'server/server.lua'
}

client_scripts {
    'client/localization.lua',
    'client/language.lua',
    'client/npc_management.lua'
}

lua54 'yes'
