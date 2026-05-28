fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'SwitCore - Intro Cinematic'
description 'First-join cinematic overlay cu logo reveal si tagline'
author      'Switty'
version     '1.0.0'

dependencies { 'core' }

server_scripts { 'server/server.lua' }
client_scripts { 'client/client.lua' }

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
}
