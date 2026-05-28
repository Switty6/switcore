local noclipActive = false

local function noclipThread()
    while noclipActive do
        local ped    = PlayerPedId()
        local camRot = GetGameplayCamRot(2)
        local camFwd = {
            x = -math.sin(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
            y =  math.cos(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
            z =  math.sin(math.rad(camRot.x)),
        }
        local camRight = {
            x = math.cos(math.rad(camRot.z)),
            y = math.sin(math.rad(camRot.z)),
            z = 0.0,
        }

        local fwd   = IsDisabledControlPressed(0, 32)  -- W
        local back  = IsDisabledControlPressed(0, 33)  -- S
        local left  = IsDisabledControlPressed(0, 34)  -- A
        local right = IsDisabledControlPressed(0, 35)  -- D
        local up    = IsDisabledControlPressed(0, 22)  -- Space
        local down  = IsDisabledControlPressed(0, 36)  -- Ctrl
        local sprint = IsDisabledControlPressed(0, 21) -- LShift

        local speed = sprint and 4.0 or 1.0
        local pos = GetEntityCoords(ped, false)
        local dx, dy, dz = 0.0, 0.0, 0.0

        if fwd   then dx = dx + camFwd.x * speed;  dy = dy + camFwd.y * speed;  dz = dz + camFwd.z * speed  end
        if back  then dx = dx - camFwd.x * speed;  dy = dy - camFwd.y * speed;  dz = dz - camFwd.z * speed  end
        if left  then dx = dx - camRight.x * speed; dy = dy - camRight.y * speed end
        if right then dx = dx + camRight.x * speed; dy = dy + camRight.y * speed end
        if up    then dz = dz + speed end
        if down  then dz = dz - speed end

        local newPos = vector3(pos.x + dx * 0.1, pos.y + dy * 0.1, pos.z + dz * 0.1)

        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityCollision(ped, false, false)
        SetEntityCoordsNoOffset(ped, newPos.x, newPos.y, newPos.z, false, false, false)

        DisableControlAction(0, 32, true)  -- W
        DisableControlAction(0, 33, true)  -- S
        DisableControlAction(0, 34, true)  -- A
        DisableControlAction(0, 35, true)  -- D
        DisableControlAction(0, 22, true)  -- Space (jump)
        DisableControlAction(0, 36, true)  -- Ctrl (duck)
        DisableControlAction(0, 21, true)  -- LShift (sprint)
        DisablePlayerFiring(PlayerId(), true)

        Wait(0)
    end
    SetEntityCollision(PlayerPedId(), true, true)
end

function ToggleNoclip()
    noclipActive = not noclipActive
    if noclipActive then
        local ped = PlayerPedId()
        SetEntityCollision(ped, false, false)
        SetEntityVisible(ped, true, false)
        CreateThread(noclipThread)
    end
    return noclipActive
end

function IsNoclipActive()
    return noclipActive
end
