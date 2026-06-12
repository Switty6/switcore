-- Mock minimal al mediului FiveM (exports, json, layerul DB) pentru a testa
-- logica de server in afara runtime-ului. Apeleaza FivemEnv.install() in before_each.

local FivemEnv = {}

local settingsStore = {}

-- Sw.T/Sw.TP cu lookup real in locales/ro.lua al modulului (dedus din primul
-- segment al cheii), ca asertiile din specuri sa vada textul final, nu cheia.
local localeCache = {}

local function loadLocaleNamespace(ns)
    if localeCache[ns] ~= nil then return localeCache[ns] end
    local chunk = loadfile(('[switcore]/%s/locales/ro.lua'):format(ns))
    local ok, data = false, nil
    if chunk then ok, data = pcall(chunk) end
    localeCache[ns] = (ok and type(data) == 'table') and data or false
    return localeCache[ns]
end

local function translateKey(key, ...)
    local ns = tostring(key):match('^([^.]+)')
    local data = ns and loadLocaleNamespace(ns)
    if not data then return key end

    local node = data
    for part in tostring(key):gmatch('[^.]+') do
        if type(node) ~= 'table' then return key end
        node = node[part]
    end
    if type(node) ~= 'string' then return key end

    local args = {...}
    for i, arg in ipairs(args) do
        node = node:gsub('{' .. i .. '}', function() return tostring(arg) end)
    end
    return node
end

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

    _G.Sw = {
        T = translateKey,
        TP = function(_, key, ...) return translateKey(key, ...) end,
    }

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
