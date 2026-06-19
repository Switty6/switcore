-- Intro-ul rulează la FIECARE conectare pe server.
-- Nu e nevoie de logică server-side - clientul îl pornește direct.

exports.core:registerModuleLocales(GetCurrentResourceName())

print('[INTRO] Server module loaded.')
