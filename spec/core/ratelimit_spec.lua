local FivemEnv = dofile('spec/support/fivem_env.lua')

describe('RateLimit', function()
    local RateLimit
    local fakeNow

    before_each(function()
        FivemEnv.install()
        RateLimit = dofile('[switcore]/core/server/ratelimit.lua')
        fakeNow = 1000
        RateLimit._now = function() return fakeNow end
    end)

    it('permite pana la limita si blocheaza apelul urmator', function()
        for _ = 1, 3 do
            assert.is_false(RateLimit.isLimited(1, 'withdraw', 3, 10))
        end
        -- al 4-lea depaseste
        assert.is_true(RateLimit.isLimited(1, 'withdraw', 3, 10))
    end)

    it('reseteaza dupa expirarea ferestrei', function()
        for _ = 1, 3 do RateLimit.isLimited(1, 'withdraw', 3, 10) end
        assert.is_true(RateLimit.isLimited(1, 'withdraw', 3, 10))

        fakeNow = fakeNow + 10 -- fereastra a expirat
        assert.is_false(RateLimit.isLimited(1, 'withdraw', 3, 10))
    end)

    it('tine evidenta separat per identificator si actiune', function()
        RateLimit.isLimited(1, 'withdraw', 1, 10)
        assert.is_true(RateLimit.isLimited(1, 'withdraw', 1, 10))
        -- alt jucator, neafectat
        assert.is_false(RateLimit.isLimited(2, 'withdraw', 1, 10))
        -- alta actiune, neafectata
        assert.is_false(RateLimit.isLimited(1, 'deposit', 1, 10))
    end)

    it('reset curata limita pentru o actiune', function()
        RateLimit.isLimited(1, 'withdraw', 1, 10)
        assert.is_true(RateLimit.isLimited(1, 'withdraw', 1, 10))
        RateLimit.reset(1, 'withdraw')
        assert.is_false(RateLimit.isLimited(1, 'withdraw', 1, 10))
    end)

    it('reset fara actiune curata tot pentru identificator', function()
        RateLimit.isLimited(1, 'withdraw', 1, 10)
        RateLimit.isLimited(1, 'deposit', 1, 10)
        RateLimit.reset(1)
        assert.is_false(RateLimit.isLimited(1, 'withdraw', 1, 10))
        assert.is_false(RateLimit.isLimited(1, 'deposit', 1, 10))
    end)

    it('nu limiteaza la parametri lipsa', function()
        assert.is_false(RateLimit.isLimited(nil, 'withdraw', 1, 10))
        assert.is_false(RateLimit.isLimited(1, nil, 1, 10))
    end)

    it('sweep inlatura bucket-urile expirate', function()
        RateLimit.isLimited(1, 'withdraw', 5, 10)
        fakeNow = fakeNow + 10
        RateLimit.sweep()
        -- dupa sweep, contorul reincepe de la zero
        assert.is_false(RateLimit.isLimited(1, 'withdraw', 1, 10))
    end)
end)
