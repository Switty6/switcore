version '1.0.0'
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
