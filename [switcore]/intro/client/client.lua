-- Overlay full-screen pe fiecare conectare (paralel cu character selection).
local introActive = false
local hasPlayedIntroThisSession = false

AddEventHandler('switcore:playIntroMenu', function()
    if introActive or hasPlayedIntroThisSession then
        -- Skip → continua direct la character selection
        TriggerEvent('switcore:introFinished')
        return
    end

    hasPlayedIntroThisSession = true
    PlayIntro()
end)

function PlayIntro()
    if introActive then return end
    introActive = true

    DoScreenFadeOut(0)

    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'play' })

    CreateThread(function()
        Wait(120)
        DoScreenFadeIn(800)
    end)
end

RegisterNUICallback('introDone', function(_, cb)
    cb('ok')
    CloseIntro()
end)

function CloseIntro()
    if not introActive then return end

    DoScreenFadeOut(400)
    Wait(420)

    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })

    introActive = false

    Wait(50)
    DoScreenFadeIn(600)
    
    TriggerEvent('switcore:introFinished')
end
