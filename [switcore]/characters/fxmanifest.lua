version '1.2.0'
description 'Sistem de caractere pentru SwitCore. Extensie pentru Core.'
author 'Switty'

fx_version 'bodacious'
game 'gta5'

dependencies {
    'core',
    'postgres',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua',
    'config.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/database.lua',
    'server/character_cache.lua',
    'server/character_manager.lua',
    'server/server.lua'
}

client_scripts {
    'client/character_selection.lua',
    'client/client.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css'
}

exports {
    'getCharacter',
    'getActiveCharacter',
    'getCharacterId',
    'getCharacterData',
    'updateCharacterPosition',
    'updateCharacterStat',
    'incrementCharacterStat',
    'getCharacterStatistics'
}

lua54 'yes'
