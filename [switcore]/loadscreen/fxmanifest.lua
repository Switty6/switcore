fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Loading screen custom pentru SwitCore.'
author 'Switty'
version '1.1.0'

loadscreen 'ui/index.html'
loadscreen_manual_shutdown 'yes'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/logo.svg',
    'ui/audio/intro.wav',
    'ui/locales/ro.json',
    'ui/locales/en.json'
}

client_scripts {
    'client/client.lua'
}
