version '1.1.0'
description 'Settings - Configurare centralizată în baza de date (key-value + typed)'
author 'Switty'

fx_version 'bodacious'
game 'common'

dependencies {
    'core',
    'postgres'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

shared_scripts {
    '@core/shared/lib.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

exports {
    'GetSetting',
    'GetSettingNumber',
    'GetSettingBool',
    'GetSettingJSON',
    'GetSettingList',
    'SetSetting',
    'ReloadSettings',
    'IsReady'
}

lua54 'yes'
