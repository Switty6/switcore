version     '1.0.0'
description 'Job Mecanic Auto - service player-owned cu sistem de componente vehicul'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'banking',
    'notifications',
    'proximity',
    'settings',
    'jobs',
    'vehicles',
    'inventory'
}

shared_script 'config.lua'

server_scripts {
    'server/database.lua',
    'server/server.lua',
    'server/callbacks.lua'
}

client_scripts {
    'client/client.lua',
    'client/workshop.lua',
    'client/roadside.lua',
    'client/components.lua',
    'client/progress.lua',
    'client/damage.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}

lua54 'yes'
