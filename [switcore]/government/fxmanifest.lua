fx_version 'bodacious'
game 'gta5'
lua54 'yes'
author 'Switty'
description 'SwitCore Government System'
version '1.0.0'

server_scripts {
    'server/database.lua',
    'server/government_manager.lua',
    'server/exports.lua',
    'server/callbacks.lua',
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css',
}

dependencies {
    'postgres',
    'settings',
    'core',
    'characters',
    'banking',
    'notifications',
}
