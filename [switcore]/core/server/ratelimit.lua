local slidingBuckets = {}

local function checkRateLimit(source, key, max, window)
    source = tonumber(source)
    if not source then return false end

    max    = max or 5
    window = window or 1000

    local now = GetGameTimer()

    local bySource = slidingBuckets[source]
    if not bySource then
        bySource = {}
        slidingBuckets[source] = bySource
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

if GetGameTimer then
    exports('checkRateLimit', checkRateLimit)

    AddEventHandler('playerDropped', function()
        local src = source
        if src then slidingBuckets[src] = nil end
    end)
end

RateLimit = {}

local buckets = {}

function RateLimit._now()
    return os.time()
end

function RateLimit.isLimited(identifier, action, maxRequests, windowSeconds)
    if identifier == nil or action == nil then
        return false
    end

    maxRequests = maxRequests or 5
    windowSeconds = windowSeconds or 10

    local key = tostring(identifier) .. ':' .. tostring(action)
    local now = RateLimit._now()
    local bucket = buckets[key]

    if not bucket or now >= bucket.resetAt then
        buckets[key] = { count = 1, resetAt = now + windowSeconds }
        return false
    end

    bucket.count = bucket.count + 1
    return bucket.count > maxRequests
end

function RateLimit.reset(identifier, action)
    if identifier == nil then
        return
    end

    if action ~= nil then
        buckets[tostring(identifier) .. ':' .. tostring(action)] = nil
        return
    end

    local prefix = tostring(identifier) .. ':'
    for key in pairs(buckets) do
        if key:sub(1, #prefix) == prefix then
            buckets[key] = nil
        end
    end
end

function RateLimit.sweep()
    local now = RateLimit._now()
    for key, bucket in pairs(buckets) do
        if now >= bucket.resetAt then
            buckets[key] = nil
        end
    end
end

return RateLimit
