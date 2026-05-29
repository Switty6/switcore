-- Mock minimal al mediului FiveM pentru testarea logicii de server in afara runtime-ului.
--
-- Modulele SwitCore depind de cateva globale injectate de FXServer: `exports`,
-- `json`, `TriggerEvent` si tabelele globale setate de celelalte fisiere ale
-- modulului (BankingDatabase, BankingManager etc.). Niciunul dintre modulele
-- testate aici nu acceseaza aceste globale la incarcare, ci doar in interiorul
-- functiilor, deci e suficient sa le stubuim inainte de a apela o functie.
--
-- Apeleaza FivemEnv.install() in before_each ca fiecare test sa porneasca curat.

local FivemEnv = {}

local settingsStore = {}

local function resolveSetting(key, default)
    local value = settingsStore[key]
    if value == nil then return default end
    return value
end

function FivemEnv.install()
    settingsStore = {}

    -- Stub-uri pentru layerul de date; specurile atribuie doar metodele
    -- de care au nevoie (ex. BankingDatabase.createLoan).
    _G.BankingDatabase = {}
    _G.BankingManager = {}

    _G.TriggerEvent = function() end

    -- `json` din FiveM. decode e suprascris per-test acolo unde conteaza
    -- (parseBalance), ca sa nu depindem de un parser JSON real in teste.
    _G.json = {
        encode = function(value) return tostring(value) end,
        decode = function() error('json.decode neimplementat in mock') end,
    }

    -- In Lua, `exports.resursa:Metoda(arg)` paseaza tabelul ca prim argument
    -- (self), deci semnaturile mock incep cu un parametru ignorat.
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

    -- Orice export neasteptat ridica o eroare clara, ca testul sa spuna exact
    -- ce dependenta lipseste in loc sa esueze cu "index a nil value".
    _G.exports = setmetatable({ settings = settingsExport }, {
        __index = function(_, resource)
            error(('exports.%s nu este stubuit in acest test'):format(resource), 2)
        end,
    })
end

-- Seteaza o valoare de setare vizibila prin exports.settings:GetSetting*.
function FivemEnv.setSetting(key, value)
    settingsStore[key] = value
end

return FivemEnv
