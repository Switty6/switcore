exports.core:registerModuleLocales(GetCurrentResourceName())

local function L(src, label)
    if not label or label == '' then return '' end
    return Sw.TP(src, label)
end

local function buildBlipsConfig(src)
    local enabled = exports.settings:GetSettingBool('blips.enabled', true)
    if not enabled then
        return { enabled = false, blips = {} }
    end

    local drawDistance = exports.settings:GetSettingNumber('blips.marker_draw_distance', 30.0)

    local cfgBanking  = exports.settings:GetSettingJSON('blips.banking',  { sprite = 108, color = 34, scale = 0.8, showMarker = true, markerType = 1, markerColor = { r = 0,   g = 180, b = 255, a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgGarages  = exports.settings:GetSettingJSON('blips.garages',  { sprite = 357, color = 2,  scale = 0.8, showMarker = true, markerType = 1, markerColor = { r = 0,   g = 255, b = 100, a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgImpound  = exports.settings:GetSettingJSON('blips.impound',  { sprite = 68,  color = 1,  scale = 0.8, showMarker = true, markerType = 1, markerColor = { r = 255, g = 60,  b = 60,  a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgShowroom = exports.settings:GetSettingJSON('blips.showroom', { sprite = 326, color = 5,  scale = 0.8, showMarker = true, markerType = 1, markerColor = { r = 255, g = 200, b = 0,   a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgFuel     = exports.settings:GetSettingJSON('blips.fuel',     { sprite = 361, color = 1,  scale = 0.7, showMarker = false })

    local defaultFuelStations = {
        { x = 49.4187,    y = 2778.793,   z = 58.043  },
        { x = 263.894,    y = 2606.463,   z = 44.983  },
        { x = 1039.958,   y = 2671.134,   z = 39.550  },
        { x = 1207.260,   y = 2660.175,   z = 37.899  },
        { x = 2539.685,   y = 2594.192,   z = 37.944  },
        { x = 2679.776,   y = 3263.946,   z = 55.240  },
        { x = 2005.055,   y = 3773.887,   z = 32.403  },
        { x = 1687.156,   y = 4929.392,   z = 42.078  },
        { x = 1701.314,   y = 6416.028,   z = 32.763  },
        { x = 179.857,    y = 6602.839,   z = 31.868  },
        { x = -94.4619,   y = 6419.594,   z = 31.489  },
        { x = -2554.999,  y = 2334.402,   z = 33.078  },
        { x = -1800.375,  y = 803.661,    z = 138.651 },
        { x = -1437.622,  y = -276.747,   z = 46.207  },
        { x = -2096.243,  y = -320.286,   z = 13.168  },
        { x = -724.6195,  y = -935.1631,  z = 19.213  },
        { x = -526.0184,  y = -1211.003,  z = 18.184  },
        { x = -70.2148,   y = -1761.792,  z = 29.534  },
        { x = 265.648,    y = -1261.309,  z = 29.292  },
        { x = 819.653,    y = -1028.846,  z = 26.403  },
        { x = 1208.951,   y = -1402.567,  z = 35.224  },
        { x = 1181.381,   y = -330.847,   z = 69.316  },
        { x = 620.843,    y = 269.100,    z = 103.089 },
        { x = 2581.321,   y = 362.039,    z = 108.468 },
        { x = 176.631,    y = -1562.025,  z = 29.263  },
    }
    local fuelStations = exports.settings:GetSettingJSON('blips.fuel_stations', defaultFuelStations)

    -- Puncte de interes (magazine, arme, haine, frizerii, tatuaje). Etichetele sunt
    -- chei, traduse per-jucator. Editabile prin setarea blips.pois.
    local defaultPois = {
        -- Magazine 24/7 / LTD
        { x = 24.5,    y = -1347.3, z = 29.5,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = -48.5,   y = -1757.5, z = 29.4,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = -707.5,  y = -914.3,  z = 19.2,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 1135.8,  y = -982.3,  z = 46.4,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 1163.4,  y = -323.8,  z = 69.2,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 374.0,   y = 325.6,   z = 103.6, sprite = 52,  labelKey = 'blips.label.store' },
        { x = 2557.5,  y = 382.3,   z = 108.6, sprite = 52,  labelKey = 'blips.label.store' },
        { x = 1961.4,  y = 3740.2,  z = 32.3,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 1729.0,  y = 6414.1,  z = 35.0,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 1697.2,  y = 4924.4,  z = 42.1,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 547.4,   y = 2671.7,  z = 42.2,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = 2678.9,  y = 3280.7,  z = 55.2,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = -3038.7, y = 585.9,   z = 7.9,   sprite = 52,  labelKey = 'blips.label.store' },
        { x = -3241.9, y = 1001.5,  z = 12.8,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = -1820.5, y = 792.5,   z = 138.1, sprite = 52,  labelKey = 'blips.label.store' },
        { x = -1487.6, y = -379.1,  z = 40.2,  sprite = 52,  labelKey = 'blips.label.store' },
        { x = -1222.9, y = -908.0,  z = 12.3,  sprite = 52,  labelKey = 'blips.label.store' },
        -- Ammu-Nation
        { x = 22.1,    y = -1107.3, z = 29.8,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = -330.2,  y = -1297.7, z = 31.2,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = 810.2,   y = -2157.5, z = 29.6,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = 1693.4,  y = 3760.2,  z = 34.7,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = 252.6,   y = -50.0,   z = 69.9,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = -1117.6, y = 2698.6,  z = 18.6,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = 2567.7,  y = 294.4,   z = 108.7, sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = -662.1,  y = -935.3,  z = 21.8,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = -1305.2, y = -393.5,  z = 36.7,  sprite = 110, labelKey = 'blips.label.ammunation' },
        { x = 842.4,   y = -1033.4, z = 28.2,  sprite = 110, labelKey = 'blips.label.ammunation' },
        -- Magazine haine
        { x = 72.3,    y = -1399.1, z = 29.4,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = -703.8,  y = -152.3,  z = 37.4,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = -167.9,  y = -298.9,  z = 39.7,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = 428.7,   y = -800.1,  z = 29.5,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = -829.4,  y = -1073.7, z = 11.3,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = -1447.8, y = -242.5,  z = 49.8,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = 11.6,    y = 6514.2,  z = 31.9,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = 123.6,   y = -219.4,  z = 54.6,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = 1696.3,  y = 4829.3,  z = 42.1,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = 618.1,   y = 2759.6,  z = 42.1,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = -3172.5, y = 1048.1,  z = 20.9,  sprite = 73,  labelKey = 'blips.label.clothing' },
        { x = 1190.0,  y = 2713.4,  z = 38.2,  sprite = 73,  labelKey = 'blips.label.clothing' },
        -- Frizerii
        { x = -814.3,  y = -183.8,  z = 37.6,  sprite = 71,  labelKey = 'blips.label.barber' },
        { x = 136.8,   y = -1708.4, z = 29.3,  sprite = 71,  labelKey = 'blips.label.barber' },
        { x = -1282.6, y = -1116.8, z = 6.99,  sprite = 71,  labelKey = 'blips.label.barber' },
        { x = 1931.5,  y = 3729.7,  z = 32.8,  sprite = 71,  labelKey = 'blips.label.barber' },
        { x = -32.9,   y = -152.8,  z = 57.1,  sprite = 71,  labelKey = 'blips.label.barber' },
        { x = -278.0,  y = 6228.5,  z = 31.7,  sprite = 71,  labelKey = 'blips.label.barber' },
        { x = 1212.8,  y = -472.9,  z = 66.2,  sprite = 71,  labelKey = 'blips.label.barber' },
        -- Saloane de tatuaje
        { x = 322.1,   y = 180.5,   z = 103.6, sprite = 75,  labelKey = 'blips.label.tattoo' },
        { x = -1153.6, y = -1425.6, z = 4.9,   sprite = 75,  labelKey = 'blips.label.tattoo' },
        { x = 1864.6,  y = 3747.7,  z = 33.0,  sprite = 75,  labelKey = 'blips.label.tattoo' },
        { x = -3170.0, y = 1075.0,  z = 20.8,  sprite = 75,  labelKey = 'blips.label.tattoo' },
        { x = 1322.7,  y = -1651.6, z = 52.3,  sprite = 75,  labelKey = 'blips.label.tattoo' },
        { x = -293.7,  y = 6200.0,  z = 31.5,  sprite = 75,  labelKey = 'blips.label.tattoo' },
    }
    -- Daca setarea exista dar a fost salvata goala (randuri mai vechi din
    -- baza de date, dinainte sa existe aceste POI-uri implicite), revenim la
    -- lista implicita in loc sa afisam harta fara ele.
    local pois = exports.settings:GetSettingJSON('blips.pois', defaultPois)
    if not pois or #pois == 0 then
        pois = defaultPois
    end

    local blipsList = {}

    local bankLocations = exports.settings:GetSettingList('banking.bank_locations', {})
    for _, loc in ipairs(bankLocations) do
        blipsList[#blipsList + 1] = {
            x = loc.x, y = loc.y, z = loc.z,
            label       = L(src, loc.label or 'blips.label.bank'),
            sprite      = cfgBanking.sprite,  color       = cfgBanking.color,
            scale       = cfgBanking.scale,   showMarker  = cfgBanking.showMarker,
            markerType  = cfgBanking.markerType, markerColor = cfgBanking.markerColor, markerScale = cfgBanking.markerScale,
        }
    end

    local function locCoords(loc)
        local c = loc.coords
        return c and c.x or 0, c and c.y or 0, c and c.z or 0
    end

    local garageLocations = exports.settings:GetSettingList('garages.locations', {})
    local impoundCode     = exports.settings:GetSetting('garages.impound_garage_code', 'IMPOUND_LSIA')
    for _, loc in ipairs(garageLocations) do
        local isImpound = (loc.code == impoundCode) or (loc.type == 'impound')
        local cfg = isImpound and cfgImpound or cfgGarages
        local x, y, z = locCoords(loc)
        blipsList[#blipsList + 1] = {
            x = x, y = y, z = z,
            label       = L(src, loc.name or (isImpound and 'blips.label.impound' or 'blips.label.garage')),
            sprite      = cfg.sprite,  color       = cfg.color,
            scale       = cfg.scale,   showMarker  = cfg.showMarker,
            markerType  = cfg.markerType, markerColor = cfg.markerColor, markerScale = cfg.markerScale,
        }
    end

    local dealershipLocations = exports.settings:GetSettingList('showroom.dealership_locations', {})
    for _, loc in ipairs(dealershipLocations) do
        local x, y, z = locCoords(loc)
        blipsList[#blipsList + 1] = {
            x = x, y = y, z = z,
            label       = L(src, loc.name or 'blips.label.showroom'),
            sprite      = cfgShowroom.sprite,  color       = cfgShowroom.color,
            scale       = cfgShowroom.scale,   showMarker  = cfgShowroom.showMarker,
            markerType  = cfgShowroom.markerType, markerColor = cfgShowroom.markerColor, markerScale = cfgShowroom.markerScale,
        }
    end

    for _, loc in ipairs(fuelStations) do
        blipsList[#blipsList + 1] = {
            x = loc.x, y = loc.y, z = loc.z,
            label       = L(src, loc.label or 'blips.label.fuel'),
            sprite      = cfgFuel.sprite, color       = cfgFuel.color,
            scale       = cfgFuel.scale,  showMarker  = cfgFuel.showMarker,
            markerType  = cfgFuel.markerType, markerColor = cfgFuel.markerColor, markerScale = cfgFuel.markerScale,
        }
    end

    for _, p in ipairs(pois) do
        blipsList[#blipsList + 1] = {
            x = p.x or 0, y = p.y or 0, z = p.z or 0,
            label       = L(src, p.labelKey or p.label or ''),
            sprite      = p.sprite or 1, color = p.color or 0,
            scale       = p.scale or 0.8, showMarker = false,
        }
    end

    return {
        enabled      = true,
        drawDistance = drawDistance,
        blips        = blipsList,
    }
end

RegisterNetEvent('blips:server:getConfig', function()
    local src = source
    TriggerClientEvent('blips:client:config', src, buildBlipsConfig(src))
end)
