version '1.1.0'
description 'Sistem de magazine statice NPC pentru SwitCore.'
author 'Switty'

fx_version 'bodacious'
game 'gta5'

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
    'server/shop_manager.lua',
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
    'ui/style.css',
    'ui/script.js'
}

exports {
    'GetShopByName',
    'GetShopItems',
    'BuyItem'
}

lua54 'yes'
