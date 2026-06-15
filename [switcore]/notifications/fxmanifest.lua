fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Sistem de notificări NUI pentru SwitCore.'
author 'Switty'
version '1.1.0'

dependencies {
    'core',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
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
    'Notify',
    'NotifyCash'
}
