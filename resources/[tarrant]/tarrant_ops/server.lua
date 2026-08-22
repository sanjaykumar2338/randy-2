local requiredResources = {
    'ox_lib', 'oxmysql', 'qbx_core', 'qbx_vehicles', 'ox_target',
    'ox_inventory', 'qbx_spawn', 'illenium-appearance', 'pma-voice', 'qbx_hud'
}

local function identifierSuffix(source, kind)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, #kind + 1) == kind .. ':' then
            return kind .. ':...' .. identifier:sub(-6)
        end
    end
end

local function contextFor(source)
    if not source or source <= 0 then return { source = 0, name = 'console' } end
    return {
        source = source,
        name = GetPlayerName(source) or 'unknown',
        license = identifierSuffix(source, 'license'),
        discord = identifierSuffix(source, 'discord')
    }
end

local function emit(category, message, fields, level)
    local entry = {
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        environment = GetConvar('tarrant_environment', 'development'),
        level = level or 'info', category = category, message = message,
        fields = fields or {}
    }
    print(('[tarrant_ops] %s'):format(json.encode(entry)))
    if GetConvar('tarrant_discord_enabled', 'false') ~= 'true' then return end
    local webhook = GetConvar('tarrant_discord_webhook', '')
    if webhook == '' then return end
    PerformHttpRequest(webhook, function(status)
        if status < 200 or status >= 300 then
            print(('[tarrant_ops] Discord webhook returned HTTP %s'):format(status))
        end
    end, 'POST', json.encode({
        username = 'Tarrant Ops',
        content = ('[%s] **%s**: %s\n```json\n%s\n```'):format(entry.level, category, message, json.encode(entry.fields))
    }), { ['Content-Type'] = 'application/json' })
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local source = source
    local context = contextFor(source)
    emit('player.connecting', 'Player connecting', context)
    if GetConvar('tarrant_whitelist_enabled', 'false') == 'true' and not IsPlayerAceAllowed(source, 'tarrant.whitelist') then
        deferrals.defer(); Wait(0)
        emit('security.whitelist_denied', 'Connection denied by whitelist', context, 'warning')
        deferrals.done('Tarrant County RP whitelist access is required.')
        CancelEvent()
    end
end)

AddEventHandler('playerJoining', function()
    emit('player.joined', 'Player joined session', contextFor(source))
end)

AddEventHandler('playerDropped', function(reason)
    local context = contextFor(source)
    context.reason = tostring(reason or 'unknown')
    emit('player.left', 'Player left session', context)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local data = player and player.PlayerData or {}
    emit('character.loaded', 'Character loaded', {
        source = data.source, citizenid = data.citizenid,
        job = data.job and data.job.name,
        cash = data.money and data.money.cash,
        bank = data.money and data.money.bank
    })
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    emit('character.unloaded', 'Character unloaded', contextFor(source))
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    emit('character.job_changed', 'Character job updated', {
        source = source, job = job and job.name,
        grade = job and job.grade and job.grade.level,
        onduty = job and job.onduty
    })
end)

AddEventHandler('QBCore:Server:OnMoneyChange', function(source, moneyType, amount, action, reason)
    emit('character.money_changed', 'Character money updated', {
        source = source, moneyType = moneyType, amount = amount,
        action = action, reason = reason or 'unspecified'
    })
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource:match('^tarrant_') then
        emit('resource.started', 'Resource started', { resource = resource })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource:match('^tarrant_') then
        emit('resource.stopped', 'Resource stopped', { resource = resource }, 'warning')
    end
end)

local function health()
    local result = { database = false, resources = {} }
    local ok, value = pcall(function() return MySQL.scalar.await('SELECT 1') end)
    result.database = ok and value == 1
    result.healthy = result.database
    for _, resource in ipairs(requiredResources) do
        local state = GetResourceState(resource)
        result.resources[resource] = state
        if state ~= 'started' then result.healthy = false end
    end
    return result
end

RegisterCommand('tarrant_health', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'tarrant.support') then
        emit('admin.denied', 'Health command denied', contextFor(source), 'warning')
        return
    end
    local result = health()
    emit('health.check', result.healthy and 'Runtime healthy' or 'Runtime unhealthy', result, result.healthy and 'info' or 'error')
end, false)

RegisterCommand('tarrant_admin_note', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'tarrant.support') then
        emit('admin.denied', 'Administrative audit note denied', contextFor(source), 'warning')
        return
    end
    local context = contextFor(source)
    context.note = table.concat(args, ' '):sub(1, 500)
    emit('admin.action', 'Administrative audit note', context)
end, false)

CreateThread(function()
    Wait(5000)
    local result = health()
    emit('health.startup', result.healthy and 'Startup readiness passed' or 'Startup readiness failed', result, result.healthy and 'info' or 'error')
end)
