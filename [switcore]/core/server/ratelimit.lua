local buckets = {}

local function checkRateLimit(source, key, max, window)
    source = tonumber(source)
    if not source then return false end

    max    = max or 5
    window = window or 1000

    local now = GetGameTimer()

    local bySource = buckets[source]
    if not bySource then
        bySource = {}
        buckets[source] = bySource
    end

    local hits = bySource[key]
    if not hits then
        hits = {}
        bySource[key] = hits
    end

    local cutoff = now - window
    local kept = {}
    for i = 1, #hits do
        if hits[i] > cutoff then
            kept[#kept + 1] = hits[i]
        end
    end

    if #kept >= max then
        bySource[key] = kept
        return false
    end

    kept[#kept + 1] = now
    bySource[key] = kept
    return true
end

exports('checkRateLimit', checkRateLimit)

AddEventHandler('playerDropped', function()
    local src = source
    if src then buckets[src] = nil end
end)
