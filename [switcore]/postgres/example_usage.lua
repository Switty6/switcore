-- Exemple de utilizare a resursei PostgreSQL din Lua
-- Acest fișier este doar pentru referință, să nu vă așteptați să facă ceva.
-- Mai bine îl ștergeți.

-- Exemplu 1: Execută o interogare simplă
local function getPlayerData(playerId)
    local result = exports.postgres:query('SELECT * FROM players WHERE id = $1', {playerId})
    if result and result.rows and result.rows[1] then
        return result.rows[1]
    end
    return nil
end

-- Exemplu 2: Obține un singur rând
local function findUserBySteamId(steamId)
    local user = exports.postgres:queryOne('SELECT * FROM users WHERE steam_id = $1', {steamId})
    return user
end

-- Exemplu 3: Inserează un jucător nou
local function createPlayer(source)
    local identifiers = GetPlayerIdentifiers(source)
    local steamId = nil
    
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, "steam:") then
            steamId = identifier
            break
        end
    end
    
    if not steamId then
        return nil
    end
    
    local newPlayer = exports.postgres:insert('players', {
        steam_id = steamId,
        name = GetPlayerName(source),
        created_at = os.time()
    })
    
    return newPlayer
end

-- Exemplu 4: Actualizează datele jucătorului
local function updatePlayerMoney(playerId, amount)
    local updated = exports.postgres:update('players', {
        money = amount,
        last_update = os.time()
    }, 'id = $1', {playerId})
    
    return updated[1] -- Returnează primul rând actualizat
end

-- Exemplu 5: Exemplu de tranzacție (interogări multiple)
local function transferMoney(fromPlayerId, toPlayerId, amount)
    exports.postgres:transaction(function(client)
        -- Scade de la expeditor
        client.query('UPDATE players SET money = money - $1 WHERE id = $2', {amount, fromPlayerId})
        -- Adaugă la destinatar
        client.query('UPDATE players SET money = money + $1 WHERE id = $2', {amount, toPlayerId})
        -- Loghează tranzacția
        client.query('INSERT INTO transactions (from_player, to_player, amount) VALUES ($1, $2, $3)', {fromPlayerId, toPlayerId, amount})
    end)
end

-- Exemplu 6: Obține toți jucătorii online
local function getAllPlayers()
    local players = exports.postgres:queryAll('SELECT * FROM players WHERE online = $1', {true})
    return players
end

-- Exemplu 7: Șterge înregistrări vechi
local function cleanupOldLogs(daysOld)
    local cutoffTime = os.time() - (daysOld * 24 * 60 * 60)
    local deleted = exports.postgres:delete('logs', 'created_at < $1', {cutoffTime})
    print('Au fost șterse ' .. deleted .. ' intrări vechi din log')
    return deleted
end
