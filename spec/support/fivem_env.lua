-- Mock minimal al mediului FiveM (exports, json, layerul DB) pentru a testa
-- logica de server in afara runtime-ului. Apeleaza FivemEnv.install() in before_each.

local FivemEnv = {}

local settingsStore = {}

local function resolveSetting(key, default)
    local value = settingsStore[key]
    if value == nil then return default end
    return value
end

function FivemEnv.install()
    settingsStore = {}

    -- Stub-uri pentru layerul de date; specurile atribuie doar metodele necesare.
    _G.BankingDatabase = {}
    _G.BankingManager = {}

    _G.TriggerEvent = function() end

    -- decode e suprascris per-test (parseBalance), ca sa nu depindem de un parser real.
    _G.json = {
        encode = function(value) return tostring(value) end,
        decode = function() error('json.decode neimplementat in mock') end,
    }

    -- exports.resursa:Metoda(arg) paseaza tabelul ca self, de aici primul param ignorat.
    local settingsExport = {
        GetSetting = function(_, key, default)
            return resolveSetting(key, default)
        end,
        GetSettingNumber = function(_, key, default)
            return tonumber(resolveSetting(key, default)) or default
        end,
        GetSettingBool = function(_, key, default)
            local value = resolveSetting(key, default)
            if value == nil then return default end
            return value == true or value == 'true' or value == 1
        end,
    }

    -- Un export nestubuit ridica o eroare clara despre ce dependenta lipseste.
    _G.exports = setmetatable({ settings = settingsExport }, {
        __index = function(_, resource)
            error(('exports.%s nu este stubuit in acest test'):format(resource), 2)
        end,
    })
end

function FivemEnv.setSetting(key, value)
    settingsStore[key] = value
end

return FivemEnv
