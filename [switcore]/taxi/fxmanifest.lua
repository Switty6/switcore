version     '1.0.0'
description 'Job Taxi - transport la cerere, plata per km'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core', 'postgres', 'characters', 'banking',
    'notifications', 'proximity', 'settings', 'jobs'
}

shared_script 'config.lua'

server_scripts {
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
