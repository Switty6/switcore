fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Sistem de inventar pentru SwitCore. Extensie pentru Core.'
author 'Switty'
version '1.0.0'

dependencies {
    'core',
    'postgres',
    'proximity',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/main.lua',
    'server/database_sync.lua',
    'server/actions.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css',
    'ui/img/items/*.png',
    'ui/img/*.png'
}

exports {
    'AddItem',
    'RemoveItem',
    'GetInventory',
    'HasItem',
    'RegisterUsableItem',
    'GetItemConfig',
    'GetInventoryTotalWeight',
    'AddInventoryBonus',
    'RemoveInventoryBonus',
    'SetInventoryBonuses'
}
