local FivemEnv = dofile('spec/support/fivem_env.lua')

describe('CurrencyManager', function()
    local CurrencyManager

    before_each(function()
        FivemEnv.install()
        -- Reincarcam modulul la fiecare test ca sa resetam cache-ul intern de cursuri.
        CurrencyManager = dofile('[switcore]/banking/server/currency_manager.lua')
    end)

    describe('setExchangeRate', function()
        it('respinge cursul intre aceeasi valuta', function()
            local ok, err = CurrencyManager.setExchangeRate(1, 1, 2.0)
            assert.is_false(ok)
            assert.equals('Nu poți seta cursul între aceeași valută', err)
        end)

        it('respinge parametri lipsa', function()
            assert.is_false((CurrencyManager.setExchangeRate(1, 2, nil)))
        end)
    end)

    describe('getExchangeRate', function()
        it('returneaza 1.0 pentru aceeasi valuta', function()
            assert.equals(1.0, CurrencyManager.getExchangeRate(1, 1))
        end)

        it('aplica fluctuatia peste cursul de baza', function()
            CurrencyManager.getLatestExchangeRate = function() return 2.0 end
            CurrencyManager.calculateVolumeFluctuation = function() return 0.0 end
            assert.near(2.0, CurrencyManager.getExchangeRate(1, 2), 1e-9)
        end)

        it('cade pe cursul invers cand cel direct lipseste', function()
            CurrencyManager.getLatestExchangeRate = function(from, to)
                if from == 1 and to == 2 then return nil end
                if from == 2 and to == 1 then return 0.5 end
            end
            CurrencyManager.calculateVolumeFluctuation = function() return 0.0 end
            -- 1 / 0.5 = 2.0
            assert.near(2.0, CurrencyManager.getExchangeRate(1, 2), 1e-9)
        end)
    end)

    describe('calculateVolumeFluctuation', function()
        it('returneaza 0 cand interogarea nu da rezultat', function()
            _G.exports.postgres = { queryOne = function() return nil end }
            assert.equals(0.0, CurrencyManager.calculateVolumeFluctuation(1, 2))
        end)

        it('da fluctuatie negativa la volum si activitate zero', function()
            _G.exports.postgres = {
                queryOne = function() return { transaction_count = 0, total_volume = 0 } end,
            }
            -- maxFluctuation implicit 5% -> 0.05; fluctuatie = (0 - 0.025) * (0.5) = -0.0125
            assert.near(-0.0125, CurrencyManager.calculateVolumeFluctuation(1, 2), 1e-9)
        end)

        it('atinge fluctuatia maxima la volum si activitate maxime', function()
            _G.exports.postgres = {
                queryOne = function()
                    return { transaction_count = 100, total_volume = 1000000 }
                end,
            }
            -- normalizat 1.0 -> (0.05 - 0.025) * (0.5 + 0.5) = 0.025
            assert.near(0.025, CurrencyManager.calculateVolumeFluctuation(1, 2), 1e-9)
        end)
    end)

    describe('exchangeCurrency', function()
        it('respinge sume invalide', function()
            local ok, err = CurrencyManager.exchangeCurrency(0, 1, 2)
            assert.is_false(ok)
            assert.equals('Sumă invalidă', err)
        end)

        it('returneaza suma neschimbata pentru aceeasi valuta', function()
            local ok, _, converted = CurrencyManager.exchangeCurrency(100, 1, 1)
            assert.is_true(ok)
            assert.equals(100, converted)
        end)

        it('converteste folosind cursul si nu pica daca update-ul dinamic ruleaza', function()
            CurrencyManager.getExchangeRate = function() return 3.0 end
            CurrencyManager.updateDynamicExchangeRate = function() return true end
            local ok, _, converted = CurrencyManager.exchangeCurrency(100, 1, 2)
            assert.is_true(ok)
            assert.equals(300, converted)
        end)

        it('esueaza cand nu exista curs de schimb', function()
            CurrencyManager.getExchangeRate = function() return nil end
            local ok = CurrencyManager.exchangeCurrency(100, 1, 2)
            assert.is_false(ok)
        end)
    end)
end)
