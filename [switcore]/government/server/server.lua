CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end

    local seeds = {
        { 'government.vote_quorum', '3',          'Numar minim de voturi DA pentru adoptarea unei legi' },
        { 'government.org_code',    'government', 'Codul organizatiei guvernamentale in sistemul banking' },
        { 'government.org_name',    'Guvernul Romaniei', 'Numele oficial al organizatiei' },
    }
    for _, s in ipairs(seeds) do
        exports.postgres:query(
            'INSERT INTO settings (key, value, description) VALUES ($1,$2,$3) ON CONFLICT (key) DO NOTHING',
            s
        )
    end

    local orgName = exports.settings:GetSetting('government.org_name', 'Guvernul Romaniei')
    pcall(function()
        exports.banking:ensureOrgAccount(1, orgName, 'BCR', 'RON')
    end)

    print('[Government] Sistem guvernamental initializat.')
end)
