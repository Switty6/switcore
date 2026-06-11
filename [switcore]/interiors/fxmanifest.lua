version '1.1.0'
description 'Sistem dinamic de incarcare interioare GTA V'
author 'Switty'

fx_version 'bodacious'
game 'gta5'

client_scripts {
    'client/client.lua',
}

exports {
    'RegisterInterior',
    'UnregisterInterior',
    'ForceLoadInterior',
    'IsInteriorLoaded',
}

lua54 'yes'
