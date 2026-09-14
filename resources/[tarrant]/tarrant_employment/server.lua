local cfg = TarrantEmployment
local shifts, busy = {}, {}
local function near(src, coords)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetPlayerRoutingBucket(src) == 0
        and GetEntityHealth(ped) > 0 and #(GetEntityCoords(ped) - coords) <= 4.0
end
local function validPlayer(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p or p.PlayerData.metadata.isdead or p.PlayerData.metadata.inlaststand then return end
    return p
end
local function shiftFor(src)
    local p, shift = validPlayer(src), shifts[src]
    if not p or not shift or shift.citizen ~= p.PlayerData.citizenid
        or p.PlayerData.job.name ~= shift.job or not p.PlayerData.job.onduty
        or os.time() - shift.started > cfg.routeLifetime then
        shifts[src] = nil
        return
    end
    return shift, cfg.jobs[shift.job]
end
lib.callback.register('tarrant_employment:select', function(src, job)
    if busy[src] or type(job) ~= 'string' or not cfg.jobs[job] or not near(src, cfg.center) then return false end
    local p = validPlayer(src)
    -- Avoid replacing an appointed job through the civilian center.
    if not p or (p.PlayerData.job.name ~= 'unemployed' and not cfg.jobs[p.PlayerData.job.name]) then return false end
    busy[src] = true
    shifts[src] = nil
    local ok, result = pcall(function()
        if not exports.qbx_core:SetJob(src, job, 0) then return false end
        exports.qbx_core:SetJobDuty(src, true)
        exports.qbx_core:Save(src)
        shifts[src] = { job = job, citizen = p.PlayerData.citizenid, index = 1, started = os.time() }
        return true
    end)
    busy[src] = nil
    if not ok then print('[tarrant_employment] Job selection failed; inspect QBX logs.') end
    return ok and result or false
end)
lib.callback.register('tarrant_employment:begin', function(src)
    if busy[src] then return false end
    local shift, job = shiftFor(src)
    if not shift or not near(src, job.stops[shift.index]) then return false end
    shift.ready = os.time() + cfg.secondsPerStop
    return true
end)
lib.callback.register('tarrant_employment:finish', function(src)
    if busy[src] then return false end
    local shift, job = shiftFor(src)
    if not shift or not shift.ready or os.time() < shift.ready or not near(src, job.stops[shift.index]) then return false end
    shift.ready = nil
    if shift.index < #job.stops then
        shift.index = shift.index + 1
        return shift.index
    end
    -- Consume before payment: replayed or concurrent calls cannot pay twice.
    shifts[src] = nil
    busy[src] = true
    local ok, paid = pcall(function()
        if not exports.qbx_core:AddMoney(src, 'cash', job.pay, 'tarrant-civilian-route') then return false end
        exports.qbx_core:Save(src)
        return true
    end)
    busy[src] = nil
    if not ok then print('[tarrant_employment] Payment/save failed; inspect QBX logs before retrying.') end
    return ok and paid and 0 or false
end)
lib.callback.register('tarrant_employment:stop', function(src)
    if busy[src] or not near(src, cfg.center) then return false end
    shifts[src] = nil
    local p = validPlayer(src)
    if p and cfg.jobs[p.PlayerData.job.name] then
        exports.qbx_core:SetJobDuty(src, false)
        exports.qbx_core:Save(src)
    end
    return true
end)
AddEventHandler('playerDropped', function() shifts[source], busy[source] = nil, nil end)
AddEventHandler('qbx_core:server:playerLoggedOut', function(src) shifts[src] = nil end)
