local spectating     = false
local spectateTarget = nil

function StartSpectate(targetId)
    if spectating then StopSpectate() end
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if not targetPed or targetPed == 0 then return false end
    spectateTarget  = targetId
    spectating      = true
    NetworkSetInSpectatorMode(true, targetPed)
    return true
end

function StopSpectate()
    if not spectating then return end
    spectating      = false
    spectateTarget  = nil
    NetworkSetInSpectatorMode(false, PlayerPedId())
end

function IsSpectating()
    return spectating
end
