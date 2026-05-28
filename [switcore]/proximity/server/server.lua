
local function getProximitySettings()
    return {
        proximityDistance        = exports.settings:GetSettingNumber('proximity.proximity_distance', 2.0),
        showMarker               = exports.settings:GetSettingBool('proximity.show_marker', true),
        showText                 = exports.settings:GetSettingBool('proximity.show_text', true),
        debug                    = exports.settings:GetSettingBool('proximity.debug', false),
        entityOffset             = exports.settings:GetSettingJSON('proximity.entity_offset', { x = 0.0, y = 0.0, z = 0.5 }),
        textOffset               = exports.settings:GetSettingJSON('proximity.text_offset', { x = 0.0, y = 0.0, z = 0.5 }),
        markerColor              = exports.settings:GetSettingJSON('proximity.marker_color', { r = 0, g = 255, b = 0, a = 200 }),
    }
end

AddEventHandler('playerSpawned', function()
    TriggerClientEvent('proximity:client:settings', source, getProximitySettings())
end)

AddEventHandler('switcore:characterSelected', function(source)
    TriggerClientEvent('proximity:client:settings', source, getProximitySettings())
end)
