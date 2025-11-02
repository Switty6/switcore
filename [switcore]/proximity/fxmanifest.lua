version '1.0.0'
description 'Sistem de interacțiuni pentru FiveM'
author 'Switty'
repository ''

fx_version 'bodacious'
game 'gta5'

client_scripts {
    'config.lua',
    'client.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

exports {
    'AddInteraction',
    'AddEntityInteraction',
    'AddModelInteraction',
    'AddTriangleZone',
    'AddRectangleZone',
    'RemoveInteraction',
    'GetCurrentInteraction',
    'IsNearInteraction',
    'AddStaticInteraction',
    'AddStaticEntityInteraction',
    'AddStaticModelInteraction',
    'AddStaticTriangleZone',
    'AddStaticRectangleZone'
}

lua54 'yes'

