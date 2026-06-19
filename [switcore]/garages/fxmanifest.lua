version     '1.2.0'
description 'Sistem de garaje pentru SwitCore. Parcare, scoatere vehicule, sechestru și amenzi.'
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
    'banking'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/garages_database.lua',
    'server/garages_manager.lua',
    'server/impound_manager.lua',
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
    'getGarageByCode',
    'getGarageVehicles',
    'parkVehicle',
    'retrieveVehicle',
    'impoundToGarage',
    'getImpoundedVehicles',
    'issueTicket',
    'payTicket',
    'getCharacterTickets',
    'getImpoundFineTotal'
}

lua54 'yes'
