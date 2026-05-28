RegisterNetEvent('medical:server:playerSneezed')
AddEventHandler('medical:server:playerSneezed', function(clientCoords)
    local src = source

    local sneezerData = GetPlayerConditionsData()[src]
    if not sneezerData then return end

    local symptoms = GetActiveSymptoms(src)
    local hasSneeze = false
    for _, sym in ipairs(symptoms) do
        if sym == 'sneezing' then hasSneeze = true; break end
    end
    if not hasSneeze then return end

    -- Anti-cheat: client poate trimite coords falsificate; verificam contra pozitia server-side
    local sneezerPed    = GetPlayerPed(src)
    local serverCoords  = GetEntityCoords(sneezerPed)
    local clientVec     = vector3(clientCoords.x, clientCoords.y, clientCoords.z)
    if #(serverCoords - clientVec) > 20.0 then
        print(string.format('[MEDICAL] Anti-cheat: player %d a trimis coordonate invalide la stranut.', src))
        return
    end

    local contagious = {}
    for condName, condData in pairs(sneezerData.conditions) do
        local cfg = Config.Conditions[condName]
        if cfg and cfg.contagious then
            contagious[#contagious + 1] = { name = condName, baseChance = cfg.baseChance }
        end
    end
    if #contagious == 0 then return end

    local radius   = Config.SneezeTransmissionRadius
    local maskMult = Config.MaskProtectionMultiplier

    for _, targetSrc in ipairs(GetPlayers()) do
        targetSrc = tonumber(targetSrc)
        if targetSrc == src then goto continue end

        local targetData = GetPlayerConditionsData()[targetSrc]
        if not targetData then goto continue end

        local targetPed = GetPlayerPed(targetSrc)
        if not targetPed or targetPed == 0 then goto continue end

        local targetCoords = GetEntityCoords(targetPed)
        if #(serverCoords - targetCoords) > radius then goto continue end

        -- Component slot 1 = masca in GTA5; drawable > 0 inseamna ca jucatorul poarta masca
        local maskDrawable = GetPedDrawableVariation(targetPed, 1)
        local hasMask      = maskDrawable > 0

        local immune = IsImmune(targetSrc)

        for _, cond in ipairs(contagious) do
            if HasCondition(targetSrc, cond.name) then goto nextCond end

            local chance = cond.baseChance
            if hasMask   then chance = chance * maskMult end
            if immune    then chance = chance * Config.VitaminImmunityMultiplier end

            local roll = math.random()
            if roll <= chance then
                InfectCharacter(targetSrc, cond.name)
                print(string.format('[MEDICAL] Player %d infectat de %d cu %s (roll=%.3f <= %.3f, masca=%s)',
                    targetSrc, src, cond.name, roll, chance, tostring(hasMask)))
            end

            ::nextCond::
        end

        ::continue::
    end
end)
