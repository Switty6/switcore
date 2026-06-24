-- Trimite limba serverului către NUI-ul de loadscreen cât mai devreme.
-- sw_locale e un convar replicat (setr), deci e disponibil pe client și în
-- timpul încărcării, înainte să existe switcore:localeData. JS-ul pornește
-- cu fallback 'ro' până ajunge mesajul.
local function PushLocale()
    SendLoadingScreenMessage(json.encode({
        action = 'sw:i18n:lang',
        lang = GetConvar('sw_locale', 'ro')
    }))
end

PushLocale()

-- Retrimitem o dată, în caz că NUI-ul nu era gata la primul mesaj
-- (setLang e idempotent pentru aceeași limbă).
CreateThread(function()
    Wait(1000)
    PushLocale()
end)

local screenShutdown = false

local function Shutdown()
    if screenShutdown then return end
    screenShutdown = true
    DoScreenFadeOut(500)
    Wait(550)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

RegisterNetEvent('switcore:openCharacterSelection', function()
    Shutdown()
end)

CreateThread(function()
    Wait(35000)
    if not screenShutdown then
        print('[loadscreen] Failsafe: forțat după 35s')
        Shutdown()
    end
end)
