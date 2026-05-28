CreateThread(function()
    while true do
        local pid = PlayerId()
        local ped = PlayerPedId()

        if GetPlayerWantedLevel(pid) ~= 0 then
            SetPlayerWantedLevel(pid, 0, false)
            SetPlayerWantedLevelNow(pid, false)
        end

        SetPoliceIgnorePlayer(pid, true)
        SetDispatchCopsForPlayer(pid, false)
        SetAudioFlag("PoliceScannerDisabled", true)

        for i = 1, 15 do
            EnableDispatchService(i, false)
        end

        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        SetCanAttackFriendly(ped, true, false)

        Wait(2000)
    end
end)
