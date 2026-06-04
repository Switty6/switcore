version     '1.0.0'
description 'Sistem de tuning pentru SwitCore. Upgrade motor, frâne, suspensie, culori și mai mult.'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'banking',
    'notifications',
    'settings',
    'proximity',
    'vehicles'
}

shared_scripts {
    '@core/shared/lib.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

server_scripts {
    '@core/server/secure.lua',
    'server/tuning_data.lua',
    'server/tuning_database.lua',
    'server/tuning_manager.lua',
    'server/exports.lua',
    'server/callbacks.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

exports {
    'GetTuningShops',
    'GetTuningPrices',
    'GetVehicleMods',
    'ApplyMod',
    'ResetMods',
    'CalculateUpgradeCost'
}

lua54 'yes'
