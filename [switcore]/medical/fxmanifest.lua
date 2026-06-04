fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Sistem medical SwitCore - boli, simptome, medicamente, rani, transmitere.'
author 'Switty'
version '1.0.0'

dependencies {
    'core',
    'postgres',
    'characters',
    'inventory',
    'notifications',
    'settings'
}

shared_scripts {
    '@core/shared/lib.lua'
}

server_scripts {
    '@core/server/secure.lua',
    'server/config_loader.lua',
    'server/database.lua',
    'server/conditions.lua',
    'server/injuries.lua',
    'server/transmission.lua',
    'server/medications.lua'
}

client_scripts {
    'client/main.lua',
    'client/symptoms.lua',
    'client/sneeze.lua',
    'client/injuries.lua'
}

exports {
    'GetCharacterConditions',
    'InfectCharacter',
    'CureCharacter',
    'CureAll',
    'HasCondition',
    'GetActiveSymptoms',
    'IsImmune',
    'GetActiveInjuries',
    'ApplyInjury',
    'TreatInjury',
    'TreatAllInjuries',
    'HasInjury',
    'SuppressInjuryBleeding',
    'SuppressSymptom'
}
