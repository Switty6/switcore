version     '1.1.0'
description 'Sistem de joburi pentru SwitCore. Joburi legale, facțiuni ilegale și joburi libere.'
author      'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'characters',
    'banking',
    'notifications',
    'proximity',
    'settings',
    'blips'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/server.lua',
    'server/callbacks.lua'
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
    'GetCharacterJob',
    'SetCharacterJob',
    'SetCharacterGrade',
    'HasJobPermission',
    'GetJobRoster',
    'IsJobManager'
}

lua54 'yes'
