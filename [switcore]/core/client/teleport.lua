-- Teleport sigur: fade, freeze si asteptarea coliziunii inainte sa predam
-- controlul, ca jucatorul sa nu cada prin harta la destinatii neincarcate.
local function SafeTeleport(coords, heading)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped

    DoScreenFadeOut(300)
    local fadeDeadline = GetGameTimer() + 1000
    while not IsScreenFadedOut() and GetGameTimer() < fadeDeadline do Wait(10) end

    FreezeEntityPosition(ent, true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ent, coords.x, coords.y, coords.z, false, false, false)

    local collisionDeadline = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
    end

    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, false)
    if found and math.abs(groundZ - coords.z) > 2.0 then
        SetEntityCoordsNoOffset(ent, coords.x, coords.y, groundZ + 1.0, false, false, false)
    end

    if heading then
        SetEntityHeading(ent, heading + 0.0)
    end

    FreezeEntityPosition(ent, false)
    DoScreenFadeIn(300)
end

exports('SafeTeleport', SafeTeleport)
