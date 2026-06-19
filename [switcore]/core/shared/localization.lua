Localization = {}

function Localization.interpolate(str, ...)
    if not str or type(str) ~= 'string' then
        return str or ''
    end
    
    local args = {...}
    local result = str
    
    for i, arg in ipairs(args) do
        local placeholder = '{' .. i .. '}'
        -- forma cu functie, altfel un '%' din argument e interpretat ca referinta de captura
        result = result:gsub(placeholder, function() return tostring(arg) end)
    end
    
    return result
end

return Localization

