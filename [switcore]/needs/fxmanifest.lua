version '1.2.0'
description 'Needs - Sistem de hunger & thirst pentru SwitCore.'
author 'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'inventory',
    'notifications',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua'
}

server_scripts {
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

exports {
    'GetHunger',
    'GetThirst',
    'SetHunger',
    'SetThirst',
    'AddHunger',
    'AddThirst'
}

lua54 'yes'
