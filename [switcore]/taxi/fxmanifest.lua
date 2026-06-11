version     '1.1.0'
description 'Job Taxi - transport la cerere, plata per km'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core', 'postgres', 'characters', 'banking',
    'notifications', 'proximity', 'settings', 'jobs'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/server.lua',
    'server/callbacks.lua'
}

client_scripts {
    'client/client.lua',
    'client/dispatch.lua',
    'client/npc.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}

lua54 'yes'
