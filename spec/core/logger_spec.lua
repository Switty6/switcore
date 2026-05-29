local FivemEnv = dofile('spec/support/fivem_env.lua')

describe('Logger', function()
    local Logger
    local printed

    before_each(function()
        FivemEnv.install()
        printed = {}
        _G.print = function(line) printed[#printed + 1] = line end
        Logger = dofile('[switcore]/core/server/logger.lua')
    end)

    it('afiseaza implicit info si peste, dar nu debug', function()
        Logger.debug('BANKING', 'detaliu')
        Logger.info('BANKING', 'informatie')
        Logger.warn('BANKING', 'avertisment')
        Logger.error('BANKING', 'eroare')

        assert.equals(3, #printed) -- info, warn, error; debug suprimat
    end)

    it('respecta core.log_level setat pe warn', function()
        FivemEnv.setSetting('core.log_level', 'warn')

        Logger.info('BANKING', 'informatie')
        Logger.warn('BANKING', 'avertisment')
        Logger.error('BANKING', 'eroare')

        assert.equals(2, #printed) -- doar warn si error
    end)

    it('arata totul cand log_level e debug', function()
        FivemEnv.setSetting('core.log_level', 'debug')

        Logger.debug('X', 'a')
        Logger.info('X', 'b')

        assert.equals(2, #printed)
    end)

    it('formateaza linia ca [TAG] [LEVEL] mesaj', function()
        Logger.error('BANKING', 'cont inexistent')
        assert.equals('[BANKING] [ERROR] cont inexistent', printed[1])
    end)

    it('trateaza un nivel necunoscut ca info', function()
        FivemEnv.setSetting('core.log_level', 'info')
        Logger.log('ceva', 'X', 'mesaj')
        assert.equals(1, #printed)
        assert.is_truthy(printed[1]:find('%[INFO%]'))
    end)
end)
