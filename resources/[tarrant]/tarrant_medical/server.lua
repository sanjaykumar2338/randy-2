local cfg = TarrantMedical
local sessions = {}

local function player(src)
    local p = exports.qbx_core:GetPlayer(src)
    if p and Player(src).state.isLoggedIn then return p end
end

local function dead(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityHealth(ped) <= 100
end

local function publish(src, session)
    TriggerClientEvent('tarrant_medical:client:state', src, session and {
        remaining = math.max(0, session.readyAt - os.time()),
        pending = session.pending ~= nil,
    } or false)
end

local function flags(src, value, weapons)
    local state = Player(src).state
    state:set('dead', value, true)
    state:set('isDead', value, true)
    state:set('medicalRecovery', value, true)
    state:set('canUseWeapons', not value and weapons ~= false, true)
end

local function saveDeath(src, session)
    -- Use existing QBX metadata JSON; no schema, inventory or money operations.
    exports.qbx_core:SetMetadata(src, 'tarrantRecovery', {
        readyAt = session.readyAt, weapons = session.weapons,
    })
    exports.qbx_core:SetMetadata(src, 'inlaststand', false)
    exports.qbx_core:SetMetadata(src, 'isdead', true)
    flags(src, true)
end

local function begin(src, p)
    local previous = p.PlayerData.metadata.tarrantRecovery
    local persisted = type(previous) == 'table'
    local readyAt = persisted and tonumber(previous.readyAt)
    local session = {
        citizen = p.PlayerData.citizenid,
        readyAt = readyAt and math.min(readyAt, os.time() + cfg.recoverySeconds)
            or os.time() + cfg.recoverySeconds,
        weapons = persisted and previous.weapons or Player(src).state.canUseWeapons,
        observedDead = dead(src),
    }
    -- Preserve an explicitly disabled weapon state through recovery.
    if persisted and previous.weapons == false then session.weapons = false end
    sessions[src] = session
    saveDeath(src, session)
    TriggerEvent('tarrant_medical:server:death', src)
    publish(src, session)
    return session
end

local function finish(src, session)
    if sessions[src] ~= session then return end
    sessions[src] = nil
    if session.pending then
        -- Prevent immediate starvation death after otherwise successful recovery.
        for _, key in ipairs({ 'hunger', 'thirst' }) do
            exports.qbx_core:SetMetadata(src, key, math.max(25, Player(src).state[key] or 0))
        end
    end
    exports.qbx_core:SetMetadata(src, 'tarrantRecovery', false)
    exports.qbx_core:SetMetadata(src, 'inlaststand', false)
    exports.qbx_core:SetMetadata(src, 'isdead', false)
    flags(src, false, session.weapons)
    exports.qbx_core:Save(src)
    publish(src)
end

local function arrived(src)
    local pos, h = GetEntityCoords(GetPlayerPed(src)), cfg.hospital
    return GetPlayerRoutingBucket(src) == 0
        and (pos.x-h.x)^2 + (pos.y-h.y)^2 + (pos.z-h.z)^2 <= cfg.arrivalRadius^2
end

local function reconcile(src)
    local p = player(src)
    if not p then sessions[src] = nil return end
    local session = sessions[src]
    if session and session.citizen ~= p.PlayerData.citizenid then
        sessions[src] = nil
        session = nil
    end
    local isDead = dead(src)
    if not session then
        if isDead or p.PlayerData.metadata.isdead or p.PlayerData.metadata.tarrantRecovery then
            return begin(src, p)
        end
        if Player(src).state.medicalRecovery then flags(src, false) end
        return
    end
    if isDead then session.observedDead = true end
    if session.observedDead and not isDead and GetPlayerPed(src) ~= 0 then
        -- Native health is authoritative here, including external/admin revives
        -- during a pending relocation. Only hospital arrivals receive recovery needs.
        if session.pending and not arrived(src) then session.pending = nil end
        finish(src, session)
        return
    end
    if session.pending then
        if os.time() >= session.pending.expires then
            session.pending = nil
            publish(src, session)
        end
    end
    return session
end

lib.callback.register('tarrant_medical:status', function(src)
    local session = reconcile(src)
    return session and { remaining = math.max(0, session.readyAt-os.time()), pending = session.pending ~= nil } or false
end)

lib.callback.register('tarrant_medical:request', function(src)
    local session = reconcile(src)
    if not session or session.pending or not dead(src) or os.time() < session.readyAt then return false end
    -- Consume before returning to the client; location and timing are never client supplied.
    session.pending = { expires = os.time() + cfg.requestTimeout }
    if not exports.qbx_core:SetPlayerBucket(src, 0) then
        session.pending = nil
        return false
    end
    return true
end)

CreateThread(function()
    while true do
        for _, src in ipairs(GetPlayers()) do reconcile(tonumber(src)) end
        Wait(500)
    end
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    local session = sessions[src]
    sessions[src] = nil
    -- Release transient bags for the next character; keep the old character's
    -- metadata/deadline persisted so logout cannot bypass their recovery.
    flags(src, false, session and session.weapons)
    publish(src)
end)
-- On stop, persisted death metadata and state remain authoritative. A restart
-- reconstructs sessions; stopping this resource must never grant a free revive.
