-- Rate limiting cu fereastra fixa per (identificator, actiune), pentru a preveni
-- spam-ul pe evenimentele sensibile. Folosit prin exports.core:isRateLimited.

RateLimit = {}

local buckets = {}

function RateLimit._now() -- extras pentru a putea controla timpul in teste
    return os.time()
end

-- Returneaza true daca apelul depaseste limita (deci trebuie respins).
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
