version     '1.0.0'
description 'Sistem showroom pentru SwitCore. Catalog vehicule, cumpărare cash/finanțare, test drive.'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'vehicles',
    'notifications',
    'proximity',
    'settings',
    'banking',
    'interiors'
}

shared_script 'config.lua'

server_scripts {
    'server/showroom_database.lua',
    'server/showroom_manager.lua',
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
    'getActiveDealerships',
    'getDealershipCatalog',
    'purchaseVehicle',
    'startTestDrive',
    'endTestDrive',
    'getActiveTestDrive'
}

lua54 'yes'
