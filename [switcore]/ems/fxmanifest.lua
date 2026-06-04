fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Sistem EMS SwitCore - inconștiență, 112, targă, MDT medical, ambulanță.'
author 'Switty'
version '1.0.0'

dependencies {
    'core',
    'postgres',
    'characters',
    'jobs',
    'banking',
    'inventory',
    'notifications',
    'proximity',
    'settings',
    'medical'
}

shared_scripts {
    '@core/shared/lib.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/unconscious.lua',
    'server/calls.lua',
    'server/treatment.lua',
    'server/vehicles.lua'
}

client_scripts {
    'client/main.lua',
    'client/patient.lua',
    'client/mdt.lua',
    'client/ambulance.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

exports {
    'IsUnconscious',
    'GetUnconsciousData',
    'SetUnconscious',
    'RevivePlayer'
}
