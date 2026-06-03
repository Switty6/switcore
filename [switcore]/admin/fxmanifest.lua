fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'admin'
description 'SwitCore Admin Menu - Player Management, Dev Tools, Vehicle Tools, World'
author      'SwitCore'
version     '1.0.0'

ui_page 'ui/index.html'

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua',
}

client_scripts {
    'client/noclip.lua',
    'client/spectate.lua',
    'client/devoverlay.lua',
    'client/client.lua',
}

server_scripts {
    '@core/server/secure.lua',
    'server/server.lua',
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/logo.svg',
}

dependencies {
    'core',
    'notifications',
    'banking',
    'characters',
    'postgres',
}
