Sw = Sw or {}

function Sw.Trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s*(.-)%s*$', '%1'))
end

function Sw.Truncate(s, maxLen)
    s = tostring(s or '')
    if #s <= maxLen then return s end
    return s:sub(1, maxLen)
end

function Sw.IsBlank(s)
    return Sw.Trim(s) == ''
end

function Sw.Round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(tonumber(n) * mult + 0.5) / mult
end

function Sw.Clamp(n, min, max)
    n = tonumber(n) or 0
    if n < min then return min end
    if n > max then return max end
    return n
end

function Sw.FormatMoney(amount, symbol)
    local n = math.floor(math.abs(tonumber(amount) or 0))
    local s = tostring(n)
    local formatted = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    local sign = (tonumber(amount) or 0) < 0 and '-' or ''
    return sign .. (symbol or '') .. formatted
end

function Sw.TableContains(tbl, value)
    if type(tbl) ~= 'table' then return false end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function Sw.TableCount(tbl)
    if type(tbl) ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function Sw.DeepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Sw.DeepCopy(v)
    end
    return copy
end

local isServerContext = type(IsDuplicityVersion) == 'function' and IsDuplicityVersion() or false

-- Traducere cu limba activa (server: limba serverului, client: limba curenta).
-- Cade pe cheie daca core nu e inca pornit. Ex: Sw.T('banking.deposit_success', suma)
function Sw.T(key, ...)
    local ok, res = pcall(function(...)
        return exports.core:t(key, ...)
    end, ...)
    if ok and res ~= nil then return res end
    return key
end

if isServerContext then
    -- Traducere adresata unui jucator anume. Pe public e identica cu Sw.T;
    -- pe premium foloseste limba aleasa de jucator (Config.ALLOW_PLAYER_LANGUAGE).
    -- Foloseste-o pentru orice mesaj trimis unui source, ca migrarea sa fie gratuita.
    function Sw.TP(source, key, ...)
        local ok, res = pcall(function(...)
            return exports.core:tp(source, key, ...)
        end, ...)
        if ok and res ~= nil then return res end
        return key
    end
else
    function Sw.TP(_, key, ...)
        return Sw.T(key, ...)
    end
end

local function validateOne(rule, value)
    local t = rule.type or 'any'

    if value == nil then
        if rule.optional then
            return true, rule.default
        end
        return false, Sw.T('core.validation.required_field', rule.name or '?')
    end

    if t == 'int' then
        local n = tonumber(value)
        if not n or n ~= math.floor(n) then
            return false, Sw.T('core.validation.field_int', rule.name or '?')
        end
        if rule.min and n < rule.min then
            return false, Sw.T('core.validation.field_min', rule.name or '?', rule.min)
        end
        if rule.max and n > rule.max then
            return false, Sw.T('core.validation.field_max', rule.name or '?', rule.max)
        end
        return true, n
    elseif t == 'number' then
        local n = tonumber(value)
        if not n then
            return false, Sw.T('core.validation.field_number', rule.name or '?')
        end
        if rule.min and n < rule.min then
            return false, Sw.T('core.validation.field_min', rule.name or '?', rule.min)
        end
        if rule.max and n > rule.max then
            return false, Sw.T('core.validation.field_max', rule.name or '?', rule.max)
        end
        return true, n
    elseif t == 'string' then
        if type(value) ~= 'string' then
            return false, Sw.T('core.validation.field_string', rule.name or '?')
        end
        local s = value
        if rule.maxLen then s = s:sub(1, rule.maxLen) end
        if rule.minLen and #Sw.Trim(s) < rule.minLen then
            return false, Sw.T('core.validation.field_too_short', rule.name or '?')
        end
        return true, s
    elseif t == 'boolean' then
        if type(value) ~= 'boolean' then
            return false, Sw.T('core.validation.field_boolean', rule.name or '?')
        end
        return true, value
    elseif t == 'table' then
        if type(value) ~= 'table' then
            return false, Sw.T('core.validation.field_table', rule.name or '?')
        end
        return true, value
    end

    return true, value
end

function Sw.ValidateArgs(rawArgs, schema)
    rawArgs = rawArgs or {}
    local cleaned = {}
    for i, rule in ipairs(schema) do
        local ok, result = validateOne(rule, rawArgs[i])
        if not ok then
            return false, result
        end
        cleaned[i] = result
        if rule.name then cleaned[rule.name] = result end

        if rule.oneOf and result ~= nil and not Sw.TableContains(rule.oneOf, result) then
            return false, Sw.T('core.validation.invalid_value', rule.name or '?')
        end
    end
    return true, cleaned
end
