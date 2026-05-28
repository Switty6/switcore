version     '1.0.0'
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

shared_script 'config.lua'

server_scripts {
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
