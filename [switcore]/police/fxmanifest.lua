version     '1.0.0'
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

server_scripts {
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

exports {
    'IsPlayerJailed',
    'JailCharacter',
    'ReleaseCharacter',
    'GetActiveWarrant',
    'IsCharacterHandcuffed'
}

lua54 'yes'
