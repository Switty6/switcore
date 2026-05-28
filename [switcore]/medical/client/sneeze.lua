local lastSneezeAt = 0
local lastCoughAt  = 0

local function PlayConditionAnim(ef)
    local ped = PlayerPedId()
    RequestAnimDict(ef.animDict)
    local timeout = 0
    while not HasAnimDictLoaded(ef.animDict) and timeout < 50 do
        Wait(50); timeout = timeout + 1
    end
    if not HasAnimDictLoaded(ef.animDict) then return end
    TaskPlayAnim(ped, ef.animDict, ef.animName, 8.0, -8.0, ef.duration, 0, 0.0, false, false, false)
    Wait(ef.duration)
    ClearPedTasksImmediately(ped)
end

CreateThread(function()
    while true do
        Wait(1000)

        if not activeSymptoms or #activeSymptoms == 0 then goto cont end

        local hasSneeze = false
        local hasCough  = false
        for _, s in ipairs(activeSymptoms) do
            if s == 'sneezing' then hasSneeze = true end
            if s == 'cough'    then hasCough  = true end
        end

        local now = os.time()

        if hasSneeze then
            local ef = Config.SymptomEffects.sneezing
            if (now - lastSneezeAt) >= ef.intervalSeconds then
                lastSneezeAt = now
                CreateThread(function()
                    PlayConditionAnim(ef)
                    local coords = GetEntityCoords(PlayerPedId())
                    TriggerServerEvent('medical:server:playerSneezed', { x = coords.x, y = coords.y, z = coords.z })
                end)
            end
        end

        if hasCough then
            local ef = Config.SymptomEffects.cough
            if (now - lastCoughAt) >= ef.intervalSeconds then
                lastCoughAt = now
                CreateThread(function() PlayConditionAnim(ef) end)
            end
        end

        ::cont::
    end
end)
