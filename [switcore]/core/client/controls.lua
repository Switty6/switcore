CreateThread(function()
    while true do
        if GetConvar('sw_disable_weapon_wheel', 'true') == 'true' then
            DisableControlAction(0, 37, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
