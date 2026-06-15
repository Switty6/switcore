fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'SwitCore - Welcome'
description 'Camera cinematic + notificari de bun venit la primul spawn'
author      'Switty'
version     '1.1.0'

dependencies { 'core', 'notifications' }

shared_scripts {
    '@core/shared/lib.lua',
}

server_scripts { 'server/server.lua' }
client_scripts { 'client/client.lua' }
