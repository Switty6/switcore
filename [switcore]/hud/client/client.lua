local cfg = {
    hideNativeHUD   = Config.HideNativeHUD,
    tickInterval    = Config.TickInterval,
    primaryCurrency = Config.PrimaryCurrency,
    primarySymbol   = Config.PrimarySymbol,
    maxSpeed        = Config.MaxSpeed,
    components      = Config.Components or {},
}

local hudVisible = false
local inVehicle  = false
local lastHealth = 100
local lastArmor  = 0
local lastSpeed  = 0
local lastGear   = 0
local lastFuel   = 0
local lastMileage = -1
local lastSigL   = false
local lastSigR   = false
local lastLights = false
local lastHigh   = false
local lastStamina= 100
local lastOxygen = 100
local lastVehHandle = 0
local lastVehModel  = 0
local cachedTankVol = 65.0

local function Send(data)
    SendNUIMessage(data)
end

local function pushI18n()
    SendNUIMessage({ action = 'sw:i18n', dict = exports.core:getLocaleDict() })
end

AddEventHandler('switcore:client:localeUpdated', pushI18n)

-- UI mereu vizibil: push o data la pornire, cu un mic delay
CreateThread(function()
    Wait(2000)
    pushI18n()
end)

local function getTankVolume(veh)
    -- Cache pe (handle + model hash). Handle singur nu e sigur: GTA refoloseste
    -- handle-uri pentru entitati noi dupa despawn. Daca un Adder (tank 65L) e
    -- inlocuit de un Truck cu acelasi handle (tank 100L), invalidam pe model schimbat.
    local model = GetEntityModel(veh)
    if veh ~= lastVehHandle or model ~= lastVehModel then
        lastVehHandle = veh
        lastVehModel  = model
        local v = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
        cachedTankVol = (v and v > 0) and v or 65.0
    end
    return cachedTankVol
end

local function ShowHUD()
    if hudVisible then return end
    hudVisible = true
    Send({ action = 'show' })

    if cfg.hideNativeHUD then
        DisplayHud(false)
        DisplayRadar(true)
    end
end

local function HideHUD()
    if not hudVisible then return end
    hudVisible = false
    Send({ action = 'hide' })

    if cfg.hideNativeHUD then
        DisplayHud(true)
    end
end

-- La restart de resursa: verificam direct prin export daca un caracter e deja selectat.
-- Evita race-ul cu pattern-ul vechi (TriggerEvent -> alt handler re-emite event) care
-- esua daca characters nu mai era pornit sau evenimentul firea inainte ca HUD-ul sa
-- termine de incarcat handler-ele.
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.CreateThread(function()
        Citizen.Wait(500)
        local ok, char = pcall(function() return exports.characters:GetCurrentCharacter() end)
        if ok and char then
            ShowHUD()
        end
    end)
end)

CreateThread(function()
    while true do
        -- 100ms in vehicul (10 FPS NUI - suficient pentru speedometer fluid)
        -- in loc de 50ms (20 FPS - inutil, depaseste perceptia umana).
        Wait(inVehicle and 100 or cfg.tickInterval)
        if not hudVisible then goto continue end

        local ped    = PlayerPedId()
        local health = math.max(0, math.floor(((GetEntityHealth(ped) - 100) / 100) * 100))
        local armor  = math.floor(GetPedArmour(ped))
        local inVeh  = IsPedInAnyVehicle(ped, false)
        
        local speed   = 0
        local gear    = 0
        local fuel    = 0
        local mileage = -1
        local sigL    = false
        local sigR    = false
        local lights  = false
        local high    = false
        
        local stamina = math.floor(100 - GetPlayerSprintStaminaRemaining(PlayerId()))
        local oxygen  = math.floor(GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10)

        if inVeh then
            local veh = GetVehiclePedIsIn(ped, false)
            speed = math.floor(GetEntitySpeed(veh) * 3.6)
            
            gear = GetVehicleCurrentGear(veh)
            if gear == 0 and speed > 1.0 and GetEntitySpeedVector(veh, true).y < 0.0 then
                gear = -1
            end
            
            fuel = math.floor(math.min(100, GetVehicleFuelLevel(veh) * 100.0 / getTankVolume(veh)))
            
            local _, lOn, hOn = GetVehicleLightsState(veh)
            lights = (lOn == 1 or lOn == true or hOn == 1 or hOn == true)
            high   = (hOn == 1 or hOn == true)
            
            -- ind: 1=left, 2=right, 3=both
            local ind = GetVehicleIndicatorLights(veh)
            sigL = (ind == 1 or ind == 3)
            sigR = (ind == 2 or ind == 3)

            local okKm, km = pcall(function() return exports.vehicles:GetCurrentVehicleKm() end)
            if okKm and km ~= nil then
                mileage = math.floor(km * 10) / 10
            end
        end

        if health ~= lastHealth or armor ~= lastArmor or speed ~= lastSpeed or inVeh ~= inVehicle
           or gear ~= lastGear or fuel ~= lastFuel or sigL ~= lastSigL or sigR ~= lastSigR
           or lights ~= lastLights or high ~= lastHigh or stamina ~= lastStamina or oxygen ~= lastOxygen
           or mileage ~= lastMileage then
           
            lastHealth = health
            lastArmor  = armor
            lastSpeed  = speed
            inVehicle  = inVeh
            lastGear   = gear
            lastFuel   = fuel
            lastMileage = mileage
            lastSigL   = sigL
            lastSigR   = sigR
            lastLights = lights
            lastHigh   = high
            lastStamina= stamina
            lastOxygen = oxygen

            Send({
                action      = 'updateGame',
                health      = health,
                armor       = armor,
                inVehicle   = inVeh,
                speed       = speed,
                gear        = gear,
                fuel        = fuel,
                mileage     = mileage,
                signalLeft  = sigL,
                signalRight = sigR,
                lights      = lights,
                highBeam    = high,
                stamina     = stamina,
                oxygen      = oxygen
            })
        end

        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(15000)
        if hudVisible then
            local h, m = GetClockHours(), GetClockMinutes()
            Send({ action = 'updateTime', hour = h, minute = m })
        end
    end
end)

RegisterNetEvent('hud:client:config', function(data)
    if not data then return end
    cfg.hideNativeHUD   = data.hideNativeHUD   ~= nil and data.hideNativeHUD   or cfg.hideNativeHUD
    cfg.tickInterval    = data.tickInterval    or cfg.tickInterval
    cfg.primaryCurrency = data.primaryCurrency or cfg.primaryCurrency
    cfg.primarySymbol   = data.primarySymbol   or cfg.primarySymbol
    cfg.maxSpeed        = data.maxSpeed        or cfg.maxSpeed
    if data.components then
        cfg.components = data.components
    end
    Send({ action = 'config', maxSpeed = cfg.maxSpeed, components = cfg.components })
end)

AddEventHandler('switcore:characterLoaded', function(character)
    ShowHUD()
    local h, m = GetClockHours(), GetClockMinutes()
    Send({ action = 'updateTime', hour = h, minute = m })

    -- Forteaza ascunderea barelor optionale la start
    Send({
        action = 'updateGame',
        stamina = 100,
        oxygen = 100
    })
end)

RegisterNetEvent('switcore:openCharacterSelection', function()
    HideHUD()
    if cfg.hideNativeHUD then DisplayHud(true) end
end)

RegisterNetEvent('hud:client:init', function(data)
    Send({
        action = 'init',
        cash   = data.cash   or 0,
        symbol = data.symbol or '$',
        hunger = data.hunger or 100,
        thirst = data.thirst or 100,
    })
end)

RegisterNetEvent('hud:client:cashUpdate', function(amount, symbol)
    Send({ action = 'updateCash', amount = amount, symbol = symbol or '$' })
end)

RegisterNetEvent('banking:client:cashData', function(cashData)
    if not cashData then return end
    for _, entry in ipairs(cashData) do
        if entry.currency_code == cfg.primaryCurrency then
            Send({ action = 'updateCash', amount = tonumber(entry.amount) or 0, symbol = cfg.primarySymbol })
            break
        end
    end
end)

RegisterNetEvent('switcore:needsUpdate', function(hunger, thirst)
    Send({ action = 'updateNeeds', hunger = hunger, thirst = thirst })
end)

AddEventHandler('switcore:timeUpdate', function(hour, minute)
    Send({ action = 'updateTime', hour = hour, minute = minute })
end)

AddEventHandler('hud:setJobInfo', function(job)
    if not job then return end
    Send({
        action     = 'updateJob',
        name       = job.name       or '',
        label      = job.label      or '',
        gradeLabel = job.gradeLabel or '',
        type       = job.type       or 'self_serve',
        isOnDuty   = job.isOnDuty  == true,
    })
end)

exports('ShowHUD', ShowHUD)
exports('HideHUD', HideHUD)
exports('SetHUDComponent', function(component, value)
    Send({ action = 'setComponent', component = component, value = value })
end)
