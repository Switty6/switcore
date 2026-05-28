local CAM_DURATION = 3200
local CAM_HEIGHT   = 28.0
local CAM_TILT     = 38.0

local function playCinematicSpawn(ped)
    local pos = GetEntityCoords(ped)

    local startCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(startCam,
        pos.x + 4.0,
        pos.y - 8.0,
        pos.z + CAM_HEIGHT
    )
    PointCamAtCoord(startCam, pos.x, pos.y, pos.z + 1.0)
    SetCamFov(startCam, 55.0)

    local endCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(endCam,
        pos.x + 0.6,
        pos.y - 1.2,
        pos.z + 0.6
    )
    PointCamAtCoord(endCam, pos.x, pos.y + 6.0, pos.z + 0.5)
    SetCamFov(endCam, 70.0)

    RenderScriptCams(true, false, 0, true, true)
    SetCamActiveWithInterp(endCam, startCam, CAM_DURATION, 1, 1)

    Wait(CAM_DURATION + 200)
    RenderScriptCams(false, true, 600, true, true)

    DestroyCam(startCam, false)
    DestroyCam(endCam, false)
end

local function notify(notifType, message, duration)
    TriggerEvent('switcore:notify:local', notifType, message, duration or 6000)
end

RegisterNetEvent('welcome:client:spawn', function(data)
    local firstName  = data.firstName  or 'Jucător'
    local firstSpawn = data.firstSpawn or false

    CreateThread(function()
        Wait(800)

        local ped = PlayerPedId()

        if firstSpawn then
            playCinematicSpawn(ped)

            Wait(600)
            notify('info',
                'Bine ai venit pe SwitCore, ' .. firstName .. '!',
                7000
            )

            Wait(3500)
            notify('info',
                'Apasă TAB pentru inventar sau /help pentru lista de comenzi.',
                6000
            )

            Wait(4000)
            notify('info',
                'Probleme? Folosește /report pentru a contacta un admin online.',
                6000
            )

        else
            Wait(300)
            notify('success',
                'Bine ai revenit, ' .. firstName .. '!',
                4000
            )
        end
    end)
end)
