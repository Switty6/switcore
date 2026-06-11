fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'HUD custom pentru SwitCore - health, armor, hunger, thirst, cash, timp, speedometer.'
author 'Switty'
version '1.1.0'

dependencies {
    'core',
    'characters',
    'banking',
    'settings'
}

shared_script 'config.lua'

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
    'ShowHUD',
    'HideHUD',
    'SetHUDComponent'
}
