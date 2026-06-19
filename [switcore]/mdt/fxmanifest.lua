fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'MDT unificat Politie + EMS - SwitCore'
author 'Switty'
version '1.2.0'

dependencies {
    'core',
    'postgres',
    'characters',
    'jobs',
    'banking',
    'notifications',
    'settings',
    'police',
    'ems'
}

shared_scripts {
    '@core/shared/lib.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/police_mdt.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}
