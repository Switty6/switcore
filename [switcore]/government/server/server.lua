CreateThread(function()
    while not exports.postgres:isReady() or not exports.settings:IsReady() do
        Wait(500)
    end

    local seeds = {
        { 'government.vote_quorum', '3',          'Numar minim de voturi DA pentru adoptarea unei legi' },
        { 'government.vote_duration_minutes', '1440', 'Termen implicit de vot pentru o propunere (minute)' },
        { 'government.org_code',    'government', 'Codul organizatiei guvernamentale in sistemul banking' },
        { 'government.org_name',    'Guvernul Romaniei', 'Numele oficial al organizatiei' },
    }
    for _, s in ipairs(seeds) do
        exports.postgres:query(
            'INSERT INTO settings (key, value, description) VALUES ($1,$2,$3) ON CONFLICT (key) DO NOTHING',
            s
        )
    end

    -- Asigura contul bancar al organizatiei guvernamentale (cod 'gov', seedat in banking).
    -- Semnatura corecta: ensureOrgAccount(orgCode, bankCode).
    pcall(function()
        exports.banking:ensureOrgAccount('gov', 'MAZE')
    end)

    print('[Government] Sistem guvernamental initializat.')
end)
