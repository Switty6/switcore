-- 37 = deschiderea rotii de arme; 157-165 = tastele rapide 1-9 care selecteaza
-- direct o arma fara sa deschida roata (dezactivarea doar a lui 37 le lasa active).
local WEAPON_WHEEL_CONTROLS = { 37, 157, 158, 159, 160, 161, 162, 163, 164, 165 }

CreateThread(function()
    while true do
        if GetConvar('sw_disable_weapon_wheel', 'true') == 'true' then
            for _, control in ipairs(WEAPON_WHEEL_CONTROLS) do
                DisableControlAction(0, control, true)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
