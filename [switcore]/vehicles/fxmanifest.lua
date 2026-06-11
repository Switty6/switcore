version     '1.1.0'
description 'Sistem de vehicule pentru SwitCore. Ownership, chei, combustibil, mileage și persistență stare.'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'inventory',
    'notifications',
    'settings',
    'banking',
    'proximity'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/logo.svg'
}

server_scripts {
    '@core/server/secure.lua',
    'server/vehicles_database.lua',
    'server/vehicles_manager.lua',
    'server/fuel_manager.lua',
    'server/keys_manager.lua',
    'server/exports.lua',
    'server/callbacks.lua',
    'server/fuel_station_server.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua',
    'client/fuel_station.lua'
}

exports {
    'getOwnedVehicle',
    'getOwnedVehicleByPlate',
    'getCharacterVehicles',
    'createVehicle',
    'saveVehicleState',
    'spawnVehicleForPlayer',

    'giveVehicleKey',
    'removeVehicleKey',
    'hasVehicleKey',
    'getVehicleKeys',
    'transferOwnership',

    'impoundVehicle',
    'releaseVehicle',

    'getVehicleFuel',
    'setVehicleFuel',

    'addMileage'
}

lua54 'yes'
