-- Închide loadscreen-ul când jucătorul este activ în sesiunea de rețea.
-- Acesta este cel mai fiabil indicator că resursele s-au terminat de încărcat.

local screenShutdown = false

local function Shutdown()
    if screenShutdown then return end
    screenShutdown = true
    DoScreenFadeOut(500)
    Wait(550)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

-- NetworkIsPlayerActive devine true după ce toate resursele sunt încărcate
-- și clientul s-a conectat la sesiunea de joc.
CreateThread(function()
    repeat Wait(150) until NetworkIsPlayerActive(PlayerId())
    Shutdown()
end)

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
