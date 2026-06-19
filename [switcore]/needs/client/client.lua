local lastHunger = 100.0
local lastThirst = 100.0
local lastSyncTime = 0
local WARNING_THRESHOLD = 25.0
local SYNC_TIMEOUT_MS = 180000
local needsTintActive = false

RegisterNetEvent('needs:client:applyDamage', function(amount)
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    -- 100 = mort in GTA; clamp aici previne kill direct din damage de needs
    local newHealth = math.max(100, currentHealth - (amount or 2))
    SetEntityHealth(ped, newHealth)

    AnimpostfxPlay('DrugsMichaelAliensFight', 0, false)
    Wait(800)
    AnimpostfxStop('DrugsMichaelAliensFight')
end)

RegisterNetEvent('switcore:needsUpdate', function(hunger, thirst)
    if hunger <= WARNING_THRESHOLD and lastHunger > WARNING_THRESHOLD then
        TriggerEvent('switcore:notify:local', 'warning', Sw.T('needs.warn_hunger'), 4000)
    end

    if thirst <= WARNING_THRESHOLD and lastThirst > WARNING_THRESHOLD then
        TriggerEvent('switcore:notify:local', 'warning', Sw.T('needs.warn_thirst'), 4000)
    end

    -- Aplicam/curatam tint-ul doar la tranzitie. Altfel ClearTimecycleModifier()
    -- pe fiecare update ar sterge si modificatorii setati de medical (febra etc.),
    -- iar tint-ul 'damage' albastrui ar parea ca apare/dispare aleator.
    if hunger <= 10.0 and thirst <= 10.0 then
        if not needsTintActive then
            SetTimecycleModifier('damage')
            SetTimecycleModifierStrength(0.3)
            needsTintActive = true
        end
    elseif needsTintActive then
        ClearTimecycleModifier()
        needsTintActive = false
    end

    lastHunger = hunger
    lastThirst = thirst
    lastSyncTime = GetGameTimer()
end)

CreateThread(function()
    Wait(SYNC_TIMEOUT_MS)
    while true do
        Wait(60000)
        if lastSyncTime > 0 and (GetGameTimer() - lastSyncTime) > SYNC_TIMEOUT_MS then
            print('[NEEDS] Avertisment: niciun update de la server in ultimele ' ..
                  math.floor((GetGameTimer() - lastSyncTime) / 1000) .. 's')
            lastSyncTime = GetGameTimer()
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if GetCurrentResourceName() ~= name then return end
    if needsTintActive then
        ClearTimecycleModifier()
        needsTintActive = false
    end
end)
