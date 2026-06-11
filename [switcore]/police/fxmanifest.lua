version     '1.1.0'
description 'Sistem de politie pentru SwitCore - arest, inchisoare, MDT, armament, vestiar.'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'jobs',
    'banking',
    'inventory',
    'notifications',
    'proximity',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/server.lua',
    'server/callbacks.lua'
}

client_scripts {
    'client/client.lua',
    'client/handcuffs.lua',
    'client/mdt.lua',
    'client/vehicles.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

exports {
    'IsPlayerJailed',
    'JailCharacter',
    'ReleaseCharacter',
    'GetActiveWarrant',
    'IsCharacterHandcuffed'
}

lua54 'yes'
