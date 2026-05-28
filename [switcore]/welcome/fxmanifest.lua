fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'SwitCore - Welcome'
description 'Camera cinematic + notificari de bun venit la primul spawn'
author      'Switty'
version     '1.0.0'

dependencies { 'core', 'notifications' }

server_scripts { 'server/server.lua' }
client_scripts { 'client/client.lua' }
