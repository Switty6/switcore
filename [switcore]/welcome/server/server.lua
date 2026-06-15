exports.core:registerModuleLocales(GetCurrentResourceName())

-- Personajul e considerat „nou" (declanșează cinematic) dacă playtime < prag SAU dacă a fost creat în ultimele 5 min.
-- Dublul check există pentru că playtime poate fi 0 fără ca personajul să fie chiar nou (ex: prim login după restore din backup).
local NEW_PLAYER_THRESHOLD_SECONDS = 300

local function isNewCharacter(character)
    if not character then return false end

    local playtime = tonumber(character.playtime) or 0
    if playtime < NEW_PLAYER_THRESHOLD_SECONDS then
        print(string.format('[WELCOME] Personaj nou detectat (playtime: %ds)', playtime))
        return true
    end

    if not character.created_at then return false end

    local y, mo, d, h, mi, s = tostring(character.created_at):match(
        '(%d+)-(%d+)-(%d+)[T ](%d+):(%d+):(%d+)'
    )

    if y then
        local createdTs = os.time({
            year  = tonumber(y),
            month = tonumber(mo),
            day   = tonumber(d),
            hour  = tonumber(h),
            min   = tonumber(mi),
            sec   = tonumber(s)
        })

        local now = os.time()
        local diff = now - createdTs

        if diff >= 0 and diff <= NEW_PLAYER_THRESHOLD_SECONDS then
            print(string.format('[WELCOME] Personaj nou detectat (creat acum %ds)', diff))
            return true
        end
    end

    return false
end
proxy_isNewCharacter = isNewCharacter

RegisterNetEvent('switcore:characterLoaded', function(character)
    local source = source
    if not character then return end

    local firstName  = character.first_name or 'Jucător'
    local firstSpawn = isNewCharacter(character)

    TriggerClientEvent('welcome:client:spawn', source, {
        firstName  = firstName,
        firstSpawn = firstSpawn,
    })
end)

print('[WELCOME] Server module loaded.')
