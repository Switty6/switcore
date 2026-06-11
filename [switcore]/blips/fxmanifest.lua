fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'switcore-blips'
description 'Blips și markere 3D pentru locații - SwitCore'
version     '1.1.0'

dependencies {
    'settings',
    'banking',
}

server_scripts {
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}
