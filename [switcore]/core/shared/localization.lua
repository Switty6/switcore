Localization = {}

function Localization.interpolate(str, ...)
    if not str or type(str) ~= 'string' then
        return str or ''
    end
    
    local args = {...}
    local result = str
    
    for i, arg in ipairs(args) do
        local placeholder = '{' .. i .. '}'
        result = result:gsub(placeholder, tostring(arg))
    end
    
    return result
end

return Localization

