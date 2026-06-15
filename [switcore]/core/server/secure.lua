Sw = Sw or {}

local function notify(source, kind, msg, duration)
    if msg and msg ~= '' then
        TriggerClientEvent('switcore:notify', source, kind, msg, duration or 4000)
    end
end

function Sw.SecureEvent(name, opts, handler)
    if type(opts) == 'function' then
        handler = opts
        opts = {}
    end
    opts = opts or {}
    handler = handler or opts.handler
    assert(type(handler) == 'function', ('Sw.SecureEvent("%s"): handler lipsa'):format(tostring(name)))

    RegisterNetEvent(name, function(...)
        local source = source
        local fail = opts.silent
            and function() end
            or function(msg) notify(source, 'error', msg) end

        local rl = opts.rateLimit
        if rl and not exports.core:checkRateLimit(source, name, rl.max, rl.window) then
            return fail(opts.rateLimitMessage or Sw.TP(source, 'core.secure.rate_limited'))
        end

        if opts.permission and not exports.core:hasPermission(source, opts.permission) then
            return fail(opts.permissionMessage or Sw.TP(source, 'core.secure.no_permission'))
        end

        local args
        if opts.args then
            local ok, result = Sw.ValidateArgs({ ... }, opts.args)
            if not ok then return fail(result) end
            args = result
        else
            args = { ... }
        end

        local character
        if opts.character then
            character = exports.characters:getActiveCharacter(source)
            if not character then
                return fail(opts.characterMessage or Sw.TP(source, 'core.secure.no_character'))
            end
        end

        local ctx = {
            source    = source,
            character = character,
            args      = args,
            notify    = function(kind, msg, duration) notify(source, kind, msg, duration) end,
            error     = function(msg, duration) notify(source, 'error', msg, duration) end,
            success   = function(msg, duration) notify(source, 'success', msg, duration) end,
        }

        handler(ctx)
    end)
end
