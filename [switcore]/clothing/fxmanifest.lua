fx_version 'bodacious'
game 'gta5'
lua54 'yes'

description 'Sistem de magazine de haine pentru SwitCore'
author 'Switty'
version '1.1.0'

dependencies {
    'core',
    'postgres',
    'characters',
    'inventory',
    'banking',
    'notifications',
    'proximity',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/clothing_manager.lua',
    'server/exports.lua',
    'server/callbacks.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css'
}

exports {
    'GetStoreItems',
    'GetEquippedClothing'
}
