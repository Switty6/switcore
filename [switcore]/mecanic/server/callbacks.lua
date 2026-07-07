Sw.SecureEvent('mecanic:server:vehicleDamaged', {
    character = true,
    silent = true,
    rateLimit = { max = 1, window = 3000 },
    args = {
        { name = 'data', type = 'table' },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local data = ctx.args.data

    if not data.vehicleId then return end

    local vehicleId    = tonumber(data.vehicleId)
    local bodyHealth   = tonumber(data.bodyHealth)
    local engineHealth = tonumber(data.engineHealth)
    local compDelta    = data.components

    if not vehicleId then return end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle or tostring(vehicle.character_id) ~= tostring(char.id) then return end

    local stateUpdate = {}
    if bodyHealth   then stateUpdate.body_health   = math.max(0, math.min(1000, bodyHealth))   end
    if engineHealth then stateUpdate.engine_health = math.max(0, math.min(1000, engineHealth)) end
    if next(stateUpdate) then
        pcall(function() exports.vehicles:saveVehicleState(vehicleId, stateUpdate) end)
    end

    if compDelta and type(compDelta) == 'table' and next(compDelta) then
        local components = MecanicDB.getComponents(vehicleId) or {
            oil=100, battery=100, brakes=100, exhaust=100,
            tires={fl=100,fr=100,rl=100,rr=100},
            suspension={fl=100,fr=100,rl=100,rr=100}
        }

        for k, v in pairs(compDelta) do
            if type(v) == 'table' then
                if not components[k] or type(components[k]) ~= 'table' then
                    components[k] = {}
                end
                for pos, val in pairs(v) do
                    val = math.max(0, math.min(100, tonumber(val) or 100))
                    if not components[k][pos] or val < components[k][pos] then
                        components[k][pos] = val
                    end
                end
            else
                v = math.max(0, math.min(100, tonumber(v) or 100))
                if not components[k] or v < components[k] then
                    components[k] = v
                end
            end
        end

        MecanicDB.saveComponents(vehicleId, components)
    end
end)

local function getActiveChar(src)
    local ok, char = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    return ok and char or nil
end

local function notify(src, notifType, title, message)
    TriggerClientEvent('notifications:client:send', src, {
        type = notifType, title = title, message = message, duration = 5000
    })
end

local function hasPermission(characterId, perm)
    local ok, result = pcall(function()
        return exports.jobs:HasJobPermission(characterId, perm)
    end)
    return ok and result == true
end

local function findSourceForChar(characterId)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local char = getActiveChar(src)
        if char and char.id == characterId then return src end
    end
    return nil
end

Sw.SecureEvent('mecanic:server:openTablet', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not hasPermission(char.id, 'inspect') then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_access_denied'), Sw.TP(src, 'mecanic.err_no_mechanic'))
        return
    end

    local stats   = MecanicDB.getMechanicStats(char.id)
    local recent  = MecanicDB.getRecentServices(char.id, 10)
    local calls   = MecanicDB.getOpenCalls()

    TriggerClientEvent('mecanic:client:tabletData', src, {
        stats   = stats,
        recent  = recent,
        calls   = calls,
        prices  = Config.Prices,
    })
end)

Sw.SecureEvent('mecanic:server:requestService', {
    character = true,
    silent = true,
    rateLimit = { max = 5, window = 3000 },
    args = {
        { name = 'data', type = 'table' },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local data = ctx.args.data

    if not data.problemType or not data.location then return end

    local vehicleId   = tonumber(data.vehicleId)
    local problemType = tostring(data.problemType)
    local location    = data.location

    local call = MecanicDB.createCall(char.id, vehicleId, problemType, location)
    if not call then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_generic'), Sw.TP(src, 'mecanic.call_create_failed'))
        return
    end

    notify(src, 'info', Sw.TP(src, 'mecanic.mechanic_called_title'),
        Sw.TP(src, 'mecanic.mechanic_called_msg'))

    local callData = {
        id          = call.id,
        clientName  = char.first_name .. ' ' .. char.last_name,
        vehicleId   = vehicleId,
        plate       = data.plate or '-',
        problemType = problemType,
        location    = location,
    }
    BroadcastCallToMechanics(callData)
end)

Sw.SecureEvent('mecanic:server:acceptCall', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'callId', type = 'int', min = 1 },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local callId = ctx.args.callId

    if not hasPermission(char.id, 'roadside') then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_access_denied'), Sw.TP(src, 'mecanic.err_no_roadside_perm'))
        return
    end

    local call = MecanicDB.getCallById(callId)
    if not call or call.status ~= 'pending' then
        notify(src, 'error', Sw.TP(src, 'mecanic.call_invalid_title'), Sw.TP(src, 'mecanic.call_unavailable'))
        return
    end

    local ok = MecanicDB.acceptCall(callId, char.id)
    if not ok then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_generic'), Sw.TP(src, 'mecanic.call_accept_failed'))
        return
    end

    notify(src, 'success', Sw.TP(src, 'mecanic.call_accepted_title'), Sw.TP(src, 'mecanic.call_accepted_msg'))
    TriggerClientEvent('mecanic:client:callAccepted', src, {
        callId   = callId,
        location = type(call.location) == 'string' and json.decode(call.location) or call.location,
    })

    local clientSrc = findSourceForChar(call.client_char_id)
    if clientSrc then
        notify(clientSrc, 'info', Sw.TP(clientSrc, 'mecanic.mechanic_enroute_title'),
            Sw.TP(clientSrc, 'mecanic.mechanic_enroute_msg', char.first_name, char.last_name))
    end
end)

Sw.SecureEvent('mecanic:server:cancelCall', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'callId', type = 'int', min = 1 },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local callId = ctx.args.callId

    local call = MecanicDB.getCallById(callId)
    if not call or call.client_char_id ~= char.id then return end

    MecanicDB.cancelCall(callId)
    notify(src, 'warning', Sw.TP(src, 'mecanic.call_cancelled_title'), Sw.TP(src, 'mecanic.call_cancelled_msg'))
end)

Sw.SecureEvent('mecanic:server:performService', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'data', type = 'table' },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local data = ctx.args.data

    if not data.serviceType or not data.vehicleId then return end

    local serviceType = tostring(data.serviceType)
    local vehicleId   = tonumber(data.vehicleId)
    local clientSrc   = tonumber(data.clientSrc)
    local clientChar  = getActiveChar(clientSrc)

    if not clientChar then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_generic'), Sw.TP(src, 'mecanic.client_disconnected'))
        return
    end

    local permMap = {
        inspect    = 'inspect',
        oil_change = 'oil_change',
        brakes     = 'brakes',
        tire       = 'tires',
        suspension = 'suspension',
        battery    = 'battery',
        engine     = 'engine',
        bodywork   = 'bodywork',
        roadside_engine  = 'roadside',
        roadside_tire    = 'roadside',
        roadside_battery = 'roadside',
        roadside_tow     = 'roadside',
    }

    local requiredPerm = permMap[serviceType]
    if not requiredPerm or not hasPermission(char.id, requiredPerm) then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_access_denied'), Sw.TP(src, 'mecanic.err_no_service_perm'))
        return
    end

    local vehicle = exports.vehicles:getOwnedVehicle(vehicleId)
    if not vehicle then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_generic'), Sw.TP(src, 'mecanic.vehicle_not_found'))
        return
    end

    if serviceType == 'inspect' then
        local components = MecanicDB.getComponents(vehicleId)
        local price      = Config.Prices.inspect

        local paid = CompleteService(src, clientSrc, vehicleId, Sw.T('mecanic.service.inspect'),
            price, clientChar.id, char.id)
        if not paid then return end

        TriggerClientEvent('mecanic:client:inspectResult', src, {
            vehicleId     = vehicleId,
            plate         = vehicle.plate,
            model         = vehicle.model,
            engineHealth  = tonumber(vehicle.engine_health) or 1000,
            bodyHealth    = tonumber(vehicle.body_health) or 1000,
            mileage       = tonumber(vehicle.mileage) or 0,
            components    = components,
        })

        TriggerClientEvent('mecanic:client:inspectResult', clientSrc, {
            vehicleId     = vehicleId,
            plate         = vehicle.plate,
            model         = vehicle.model,
            engineHealth  = tonumber(vehicle.engine_health) or 1000,
            bodyHealth    = tonumber(vehicle.body_health) or 1000,
            mileage       = tonumber(vehicle.mileage) or 0,
            components    = components,
        })
        return
    end

    local components = MecanicDB.getComponents(vehicleId)
    if not components then
        components = {
            oil=100, battery=100, brakes=100, exhaust=100,
            tires={fl=100,fr=100,rl=100,rr=100},
            suspension={fl=100,fr=100,rl=100,rr=100}
        }
    end

    local price       = 0
    local itemNeeded  = nil
    local itemAmount  = 1
    local newState    = {}
    local newComps    = {}
    local description = serviceType

    if serviceType == 'oil_change' then
        price      = Config.Prices.oil_change
        itemNeeded = 'ulei_motor'
        newComps.oil = 100
        description  = Sw.T('mecanic.service.oil_change')

    elseif serviceType == 'brakes' then
        price      = Config.Prices.brakes
        itemNeeded = 'placute_frana'
        newComps.brakes = 100
        description     = Sw.T('mecanic.service.brakes')

    elseif serviceType == 'battery' then
        price      = Config.Prices.battery
        itemNeeded = 'baterie_auto'
        newComps.battery = 100
        description      = Sw.T('mecanic.service.battery')

    elseif serviceType == 'tire' then
        local positions = data.tirePositions or { 'fl', 'fr', 'rl', 'rr' }
        itemAmount = #positions
        price      = Config.Prices.tire * itemAmount
        itemNeeded = 'anvelopa'
        newComps.tires = {}
        for _, pos in ipairs(positions) do
            newComps.tires[pos] = 100
        end
        description = Sw.T('mecanic.service.tire', itemAmount)

    elseif serviceType == 'suspension' then
        local positions = data.suspensionPositions or { 'fl', 'fr', 'rl', 'rr' }
        price      = Config.Prices.suspension * math.ceil(#positions / 2)
        itemNeeded = 'piesa_suspensie'
        itemAmount = math.ceil(#positions / 2)
        newComps.suspension = {}
        for _, pos in ipairs(positions) do
            newComps.suspension[pos] = 100
        end
        description = Sw.T('mecanic.service.suspension')

    elseif serviceType == 'engine' then
        price      = Config.Prices.engine
        itemNeeded = 'piesa_motor'
        newState.engine_health = 1000
        newComps.exhaust       = 100
        description            = Sw.T('mecanic.service.engine')

    elseif serviceType == 'bodywork' then
        price      = Config.Prices.bodywork
        itemNeeded = 'piesa_caroserie'
        newState.body_health = 1000
        description          = Sw.T('mecanic.service.bodywork')

    elseif serviceType == 'roadside_engine' then
        price      = Config.Prices.roadside_engine
        itemNeeded = 'piesa_motor'
        newState.engine_health = 400
        description            = Sw.T('mecanic.service.roadside_engine')

    elseif serviceType == 'roadside_tire' then
        local pos  = data.tirePositions and data.tirePositions[1] or 'fl'
        price      = Config.Prices.roadside_tire
        itemNeeded = 'anvelopa'
        newComps.tires = { [pos] = 100 }
        description    = Sw.T('mecanic.service.roadside_tire')

    elseif serviceType == 'roadside_battery' then
        price = Config.Prices.roadside_battery
        newComps.battery = 50
        description      = Sw.T('mecanic.service.roadside_battery')

    elseif serviceType == 'roadside_tow' then
        price       = Config.Prices.roadside_tow
        description = Sw.T('mecanic.service.roadside_tow')
    end

    if itemNeeded then
        local invId = 'char:' .. char.id
        local ok, removed = pcall(function()
            return exports.inventory:RemoveItem(invId, itemNeeded, itemAmount)
        end)
        if not ok or not removed then
            notify(src, 'error', Sw.TP(src, 'mecanic.part_missing_title'),
                Sw.TP(src, 'mecanic.part_missing_msg', itemAmount, itemNeeded))
            return
        end
    end

    local paid = CompleteService(src, clientSrc, vehicleId, description,
        price, clientChar.id, char.id)
    if not paid then
        if itemNeeded then
            pcall(function()
                exports.inventory:AddItem('char:' .. char.id, itemNeeded, itemAmount)
            end)
        end
        return
    end

    if next(newState) then
        exports.vehicles:saveVehicleState(vehicleId, newState)
    end

    if next(newComps) then
        for k, v in pairs(newComps) do
            if type(v) == 'table' then
                if not components[k] or type(components[k]) ~= 'table' then
                    components[k] = {}
                end
                for pos, val in pairs(v) do
                    components[k][pos] = val
                end
            else
                components[k] = v
            end
        end
        MecanicDB.saveComponents(vehicleId, components)
    end

    local updatedState = {}
    if next(newState) then updatedState = newState end
    updatedState.components = components
    local repairPayload = {
        vehicleId = vehicleId,
        plate     = vehicle.plate,
        state     = updatedState,
    }
    TriggerClientEvent('mecanic:client:vehicleRepaired', clientSrc, repairPayload)
    if src ~= clientSrc then
        TriggerClientEvent('mecanic:client:vehicleRepaired', src, repairPayload)
    end

    if data.callId then
        MecanicDB.completeCall(tonumber(data.callId), price)
    end

    if serviceType == 'roadside_tow' then
        exports.vehicles:saveVehicleState(vehicleId, { stored = true })
        TriggerClientEvent('mecanic:client:vehicleTowed', clientSrc, { vehicleId = vehicleId })
        notify(clientSrc, 'info', Sw.TP(clientSrc, 'mecanic.vehicle_towed_title'),
            Sw.TP(clientSrc, 'mecanic.vehicle_towed_msg'))
    end
end)

Sw.SecureEvent('mecanic:server:buyParts', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'data', type = 'table' },
    },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character
    local data = ctx.args.data

    if not hasPermission(char.id, 'buy_parts') then
        notify(src, 'error', Sw.TP(src, 'mecanic.err_access_denied'), Sw.TP(src, 'mecanic.err_only_manager_parts'))
        return
    end

    if not data.itemName or not data.amount then return end

    local amount    = math.max(1, math.min(50, tonumber(data.amount) or 1))
    local unitPrice = tonumber(data.unitPrice) or 0
    local total     = amount * unitPrice

    local currencyId = MecanicDB.getRonCurrencyId()
    if not currencyId then return end

    local ok, errMsg = pcall(function()
        return exports.banking:orgSystemDebit(
            Config.OrgCode, total, currencyId,
            Sw.T('mecanic.tx_buy_parts', data.itemName, amount)
        )
    end)

    if not ok then
        notify(src, 'error', Sw.TP(src, 'mecanic.insufficient_funds'), Sw.TP(src, 'mecanic.firm_no_funds'))
        return
    end

    local added = pcall(function()
        exports.inventory:AddItem('char:' .. char.id, data.itemName, amount)
    end)

    if added then
        notify(src, 'success', Sw.TP(src, 'mecanic.parts_bought_title'),
            Sw.TP(src, 'mecanic.parts_bought_msg', amount, data.itemName, total))
    end
end)

Sw.SecureEvent('mecanic:server:getVehicleByPlate', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
    args = {
        { name = 'plate', type = 'string', minLen = 1, maxLen = 12 },
    },
}, function(ctx)
    local src   = ctx.source
    local char  = ctx.character
    local plate = ctx.args.plate

    if not hasPermission(char.id, 'inspect') then return end

    local vehicle = exports.vehicles:getOwnedVehicleByPlate(plate)
    if not vehicle then
        notify(src, 'error', Sw.TP(src, 'mecanic.vehicle_not_registered_title'), Sw.TP(src, 'mecanic.vehicle_not_registered_msg', plate))
        return
    end

    local ownerSrc = nil
    local components = exports.vehicles:getVehicleComponents(vehicle.id)

    for _, pid in ipairs(GetPlayers()) do
        local pSrc  = tonumber(pid)
        local pChar = getActiveChar(pSrc)
        if pChar and pChar.id == vehicle.character_id then
            ownerSrc = pSrc
            break
        end
    end

    TriggerClientEvent('mecanic:client:vehicleByPlate', src, {
        vehicleId    = vehicle.id,
        plate        = vehicle.plate,
        model        = vehicle.model,
        engineHealth = tonumber(vehicle.engine_health) or 1000,
        bodyHealth   = tonumber(vehicle.body_health) or 1000,
        mileage      = tonumber(vehicle.mileage) or 0,
        components   = components,
        ownerSrc     = ownerSrc,
    })
end)

Sw.SecureEvent('mecanic:server:getOpenCalls', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src  = ctx.source
    local char = ctx.character

    if not hasPermission(char.id, 'inspect') then return end

    local calls = MecanicDB.getOpenCalls()
    TriggerClientEvent('mecanic:client:openCalls', src, calls)
end)
