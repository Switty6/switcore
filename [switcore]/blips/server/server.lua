local function buildBlipsConfig()
    local enabled = exports.settings:GetSettingBool('blips.enabled', true)
    if not enabled then
        return { enabled = false, blips = {} }
    end

    local drawDistance = exports.settings:GetSettingNumber('blips.marker_draw_distance', 30.0)

    local cfgBanking  = exports.settings:GetSettingJSON('blips.banking',  { sprite = 108, color = 34, scale = 0.8, label = 'Bancă',    showMarker = true, markerType = 1, markerColor = { r = 0,   g = 180, b = 255, a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgGarages  = exports.settings:GetSettingJSON('blips.garages',  { sprite = 357, color = 2,  scale = 0.8, label = 'Garaj',    showMarker = true, markerType = 1, markerColor = { r = 0,   g = 255, b = 100, a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgImpound  = exports.settings:GetSettingJSON('blips.impound',  { sprite = 68,  color = 1,  scale = 0.8, label = 'Sechestru',showMarker = true, markerType = 1, markerColor = { r = 255, g = 60,  b = 60,  a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgShowroom = exports.settings:GetSettingJSON('blips.showroom', { sprite = 326, color = 5,  scale = 0.8, label = 'Showroom', showMarker = true, markerType = 1, markerColor = { r = 255, g = 200, b = 0,   a = 150 }, markerScale = { x = 0.5, y = 0.5, z = 0.5 } })
    local cfgFuel     = exports.settings:GetSettingJSON('blips.fuel',     { sprite = 361, color = 1,  scale = 0.7, label = 'Benzinărie',showMarker = false })

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

    local blipsList = {}

    local bankLocations = exports.settings:GetSettingList('banking.bank_locations', {})
    for _, loc in ipairs(bankLocations) do
        blipsList[#blipsList + 1] = {
            x = loc.x, y = loc.y, z = loc.z,
            label       = loc.label or cfgBanking.label,
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
        local cfg = ((loc.code == impoundCode) or (loc.type == 'impound')) and cfgImpound or cfgGarages
        local x, y, z = locCoords(loc)
        blipsList[#blipsList + 1] = {
            x = x, y = y, z = z,
            label       = loc.name or cfg.label,
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
            label       = loc.name or cfgShowroom.label,
            sprite      = cfgShowroom.sprite,  color       = cfgShowroom.color,
            scale       = cfgShowroom.scale,   showMarker  = cfgShowroom.showMarker,
            markerType  = cfgShowroom.markerType, markerColor = cfgShowroom.markerColor, markerScale = cfgShowroom.markerScale,
        }
    end

    for _, loc in ipairs(fuelStations) do
        blipsList[#blipsList + 1] = {
            x = loc.x, y = loc.y, z = loc.z,
            label       = loc.label or cfgFuel.label,
            sprite      = cfgFuel.sprite, color       = cfgFuel.color,
            scale       = cfgFuel.scale,  showMarker  = cfgFuel.showMarker,
            markerType  = cfgFuel.markerType, markerColor = cfgFuel.markerColor, markerScale = cfgFuel.markerScale,
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
    TriggerClientEvent('blips:client:config', src, buildBlipsConfig())
end)

