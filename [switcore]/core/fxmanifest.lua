version '1.0.0'
description 'SwitCore Core - Sistemul de player management (core an plm)'
author 'Switty'

fx_version 'bodacious'
game 'common'

dependencies {
    'postgres'
}

shared_script 'config.lua'

server_scripts {
    'server/player_cache.lua',
    'server/database.lua',
    'server/playtime.lua',
    'server/commands.lua',
    'server/server.lua'
}

lua54 'yes'

