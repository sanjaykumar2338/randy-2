local cfg = TarrantMedical
local recovering, pending, deadline, stopped = false, false, 0, false
local generation, moving = 0, false
local message
local remotePending = false
local sawNativeDeath = false
local loaded = LocalPlayer.state.isLoggedIn == true
local sceneOwned, focusOwned = false, false
local surveying = false

local function releaseStreaming()
    if sceneOwned then NewLoadSceneStop() sceneOwned = false end
    if focusOwned then ClearFocus() focusOwned = false end
end

local function cleanup()
    generation = generation + 1
    recovering, pending, remotePending, message = false, false, false, nil
    surveying = false
    sawNativeDeath = false
    releaseStreaming()
    if moving then
        DoScreenFadeIn(250)
        moving = false
    end
end

local function enter()
    if recovering then return end
    recovering = true
    sawNativeDeath = IsEntityDead(PlayerPedId())
    deadline = GetGameTimer() + cfg.recoverySeconds * 1000
    TriggerEvent('tarrant_medical:client:death')
    exports.ox_inventory:closeInventory()
end

local function apply(state)
    if not loaded or not LocalPlayer.state.isLoggedIn or stopped then return end
    if not state then
        if not IsEntityDead(PlayerPedId()) and not surveying then cleanup() end
        return
    end
    enter()
    remotePending = state.pending
    deadline = GetGameTimer() + state.remaining * 1000
    -- Persisted death must not be bypassed by a fresh login ped/model.
    if not moving and not state.pending and not sawNativeDeath and not IsEntityDead(PlayerPedId()) then
        SetEntityHealth(PlayerPedId(), 0)
        sawNativeDeath = true
    end
end

RegisterNetEvent('tarrant_medical:client:state', function(state)
    if source ~= 65535 then return end
    apply(state)
end)

-- Query both sources even on disagreement. Evidence is diagnostic only: all
-- existing acceptance predicates must pass together, with no fallback height.
local function sampleSurface(h, ped)
    local found, ground = GetGroundZFor_3dCoord(h.x, h.y, h.z + 1.0, false)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(
        h.x, h.y, h.z + 1.0, h.x, h.y, h.z - 2.5, 1, ped, 7)
    local result, hit, point, normal = GetShapeTestResult(probe)
    local rayFound = result == 2 and hit
    local evidence = ('groundFound=%s; ground=%s; rayStatus=%s; rayHit=%s; rayZ=%s; normalZ=%s')
        :format(tostring(found), tostring(ground), tostring(result), tostring(hit),
            rayFound and tostring(point.z) or 'none', rayFound and tostring(normal.z) or 'none')
    local reason
    if not found then reason = 'ground_not_found'
    elseif math.abs(ground-h.z) > 2.0 then reason = 'ground_z_mismatch'
    elseif not rayFound or math.abs(point.z-ground) > 0.25 then reason = 'ground_collision_unavailable'
    elseif normal.z < 0.9 then reason = 'surface_too_steep'
    elseif IsAnyVehicleNearPoint(h.x, h.y, ground + 1.0, 2.0) then reason = 'vehicle_at_spawn'
    end
    return reason == nil, ground, reason or 'validated', evidence
end

-- Shared by actual recovery and read-only remote candidate validation. Never
-- move/freeze/resurrect here; the caller owns cleanup and the final decision.
local function prepareSurface(h, ped, ticket, abort)
    local expires = GetGameTimer() + cfg.collisionTimeoutMs
    local ground, ready, reason, evidence = nil, false, 'scene_busy', 'ground=none; rayStatus=none; surface_not_queried'
    if not IsNewLoadSceneActive() then
        SetFocusPosAndVel(h.x, h.y, h.z, 0.0, 0.0, 0.0)
        focusOwned = true
        sceneOwned = NewLoadSceneStartSphere(h.x, h.y, h.z, 30.0, 0)
        reason = 'scene_start_failed'
        if sceneOwned then
            repeat
                if stopped or ticket ~= generation or abort() then return false, ground, 'cancelled', evidence end
                if IsEntityPositionFrozen(ped) or IsPedInAnyVehicle(ped, false) then
                    return false, ground, 'ped_frozen_or_in_vehicle', evidence
                end
                RequestCollisionAtCoord(h.x, h.y, h.z)
                reason = 'scene_not_loaded'
                if IsNewLoadSceneLoaded() then
                    ready, ground, reason, evidence = sampleSurface(h, ped)
                end
                Wait(50)
            until stopped or ticket ~= generation or ready or GetGameTimer() >= expires
            -- The last yield may change collision/occupancy. Never resurrect
            -- using a successful sample from before that yield.
            if ready and not stopped and ticket == generation and not abort() then
                if IsNewLoadSceneLoaded() then
                    ready, ground, reason, evidence = sampleSurface(h, ped)
                else
                    ready, reason = false, 'scene_not_loaded'
                end
            end
        end
    end
    return ready, ground, reason, evidence
end

local function relocate(ticket, here)
    if stopped or ticket ~= generation or not loaded then return end
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then return end
    local pos = GetEntityCoords(ped)
    local h = here and { x=pos.x, y=pos.y, z=pos.z, heading=GetEntityHeading(ped) } or cfg.hospital
    local mode = here and 'recover_here' or 'hospital'
    print(('[tarrant_medical] Recovery start: mode=%s; ped=%.4f,%.4f,%.4f; target=%.4f,%.4f,%.4f')
        :format(mode, pos.x, pos.y, pos.z, h.x, h.y, h.z))
    if IsEntityPositionFrozen(ped) or IsPedInAnyVehicle(ped, false) then
        print(('[tarrant_medical] Recovery refused: mode=%s; ped_frozen_or_in_vehicle'):format(mode))
        message = 'Recovery refused: disable NoClip/freeze and leave the vehicle first.'
        return
    end
    moving = true
    DoScreenFadeOut(250)
    local started = GetGameTimer()
    local function externalRevive()
        generation = generation + 1
        releaseStreaming()
        DoScreenFadeIn(250)
        moving, pending = false, false
        -- Retain observed-death history until server confirmation, so a delayed
        -- status response cannot mistake this revived ped for a fresh login.
        message = 'Revived. Confirming recovery...'
    end
    local ready, ground, reason, evidence = prepareSurface(h, ped, ticket, function()
        return not IsEntityDead(ped) or PlayerPedId() ~= ped
    end)
    if stopped or ticket ~= generation then return end
    if not IsEntityDead(ped) then externalRevive() return end
    local current = GetEntityCoords(ped)
    if PlayerPedId() ~= ped or IsEntityPositionFrozen(ped) or IsPedInAnyVehicle(ped, false)
        or (here and ((current.x-h.x)^2 + (current.y-h.y)^2 + (current.z-h.z)^2 > 0.25)) then
        ready, reason = false, 'ped_moved_or_frozen'
    end
    if ready then
        NetworkResurrectLocalPlayer(h.x, h.y, ground + 1.0, h.heading, false, false)
        ped = PlayerPedId()
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedTasksImmediately(ped)
        ClearPedBloodDamage(ped)
        RestorePlayerStamina(PlayerId(), 1.0)
        SetPlayerControl(PlayerId(), true, 0)
        SetGameplayCamRelativeHeading(0.0)
        SetGameplayCamRelativePitch(0.0, 1.0)
        if here then
            print(('[tarrant_medical] Validated recovery surface: %.4f, %.4f, %.4f, %.4f; visually inspect before using as hospital pavement')
                :format(h.x, h.y, ground, h.heading))
        end
        message = 'Recovery complete. Confirming recovery...'
    else
        print(('[tarrant_medical] Recovery validation failed: mode=%s; reason=%s; target=%.4f,%.4f,%.4f; ped=%.4f,%.4f,%.4f; %s; elapsed=%dms')
            :format(mode, reason, h.x, h.y, h.z, current.x, current.y, current.z, evidence, GetGameTimer()-started))
        message = here and 'Local surface unavailable. Survey another pavement location; console retry required.'
            or 'Hospital surface unavailable. Please wait, then press E to retry.'
    end
    releaseStreaming()
    DoScreenFadeIn(500)
    moving = false
end

-- Only the server console can issue this exception to civilian hospital recovery.
RegisterNetEvent('tarrant_medical:client:recoverHere', function()
    if source ~= 65535 or stopped or not loaded or moving or pending or surveying
        or not IsEntityDead(PlayerPedId()) then
        if source == 65535 then
            print('[tarrant_medical] recover_here event refused: stopped/unloaded, busy, or ped already alive')
        end
        return
    end
    enter()
    pending = true
    local ticket = generation
    CreateThread(function()
        relocate(ticket, true)
        if ticket == generation then pending = false end
    end)
end)

CreateThread(function()
    while not stopped do
        if loaded and LocalPlayer.state.isLoggedIn then
            if IsEntityDead(PlayerPedId()) then enter() end
            local ticket = generation
            local ok, state = pcall(lib.callback.await, 'tarrant_medical:status', false)
            if ok and ticket == generation then apply(state) end
        elseif recovering then cleanup() end
        Wait(1000)
    end
end)

CreateThread(function()
    while not stopped do
        if loaded and LocalPlayer.state.isLoggedIn and IsEntityDead(PlayerPedId()) then enter() end
        if recovering then
            local seconds = math.max(0, math.ceil((deadline - GetGameTimer()) / 1000))
            local label = message or ((pending or remotePending) and 'Preparing hospital recovery...'
                or seconds > 0 and ('You have died. Hospital recovery available in %ds.'):format(seconds)
                or '[E] Recover at Arlington Memorial Hospital (items and money retained)')
            -- Frame-local native UI: no shared TextUI ownership or NUI focus.
            SetTextFont(0)
            SetTextScale(0.0, 0.4)
            SetTextCentre(true)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(label)
            EndTextCommandDisplayText(0.5, 0.82)
            if not pending and not remotePending and not surveying and seconds == 0 and IsControlJustReleased(0, 38) then
                pending, message = true, nil
                local ticket = generation
                CreateThread(function()
                    local ok, accepted = pcall(lib.callback.await, 'tarrant_medical:request', false)
                    if ticket ~= generation or stopped then return end
                    if ok and accepted then relocate(ticket) end
                    if ticket == generation then pending = false end
                end)
            end
        end
        Wait(recovering and 0 or 100)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() loaded = true end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    loaded = false
    cleanup()
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopped = true
    cleanup()
end)

-- Read-only local diagnostics. Never authorize a recovery or change player state.
-- The ray is deliberately queried even if the ground native disagrees, so a
-- rendered surface/terrain disagreement is visible without accepting either one.
RegisterCommand('medical_survey_here', function()
    if stopped or not loaded or not LocalPlayer.state.isLoggedIn or moving or surveying then
        print('[tarrant_medical] Survey unavailable: not loaded or recovery in progress')
        return
    end
    local ped = PlayerPedId()
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local found, ground = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    local probe = StartExpensiveSynchronousShapeTestLosProbe(
        pos.x, pos.y, pos.z + 1.0, pos.x, pos.y, pos.z - 2.5, 1, ped, 7)
    local result, hit, point, normal = GetShapeTestResult(probe)
    local rayFound = result == 2 and hit
    local frozen = IsEntityPositionFrozen(ped)
    local vehicle = IsPedInAnyVehicle(ped, false)
    local dead = IsEntityDead(ped)
    local collision = HasCollisionLoadedAroundEntity(ped)
    local blocked = found and IsAnyVehicleNearPoint(pos.x, pos.y, ground + 1.0, 2.0)
    local agrees = found and rayFound and math.abs(ground-pos.z) <= 2.0
        and math.abs(point.z-ground) <= 0.25 and normal.z >= 0.9
    print(('[tarrant_medical] Survey v1: ped=%.4f,%.4f,%.4f; heading=%.4f; dead=%s; frozen=%s; inVehicle=%s; collision=%s; groundFound=%s; ground=%s; rayStatus=%s; rayHit=%s; rayZ=%s; normalZ=%s; vehicleNear=%s; geometryAgrees=%s; aliveCandidate=%s (snapshot only; no recovery authorization)')
        :format(pos.x, pos.y, pos.z, heading, tostring(dead), tostring(frozen), tostring(vehicle),
            tostring(collision), tostring(found), tostring(ground), tostring(result), tostring(hit),
            rayFound and tostring(point.z) or 'none', rayFound and tostring(normal.z) or 'none',
            tostring(blocked), tostring(not not agrees),
            tostring(not dead and not frozen and not vehicle and collision and agrees and not blocked)))
end, false)

-- F8: validate the configured hospital, or an explicitly measured candidate,
-- through the exact remote streaming path. Arguments NEVER alter cfg.hospital
-- or authorize a recovery. Use from an alive observer away from the destination.
RegisterCommand('medical_survey_hospital', function(_, args)
    if stopped or not loaded or not LocalPlayer.state.isLoggedIn or moving or pending
        or recovering or surveying or IsEntityDead(PlayerPedId()) then
        print('[tarrant_medical] Hospital survey unavailable: require alive player and no recovery/survey in progress')
        return
    end
    local h = cfg.hospital
    if #args ~= 0 then
        if #args ~= 4 then
            print('[tarrant_medical] Usage: medical_survey_hospital [measuredX measuredY measuredZ heading]')
            return
        end
        local values = {}
        for i = 1, 4 do
            values[i] = tonumber(args[i])
            if not values[i] or values[i] ~= values[i] or math.abs(values[i]) == math.huge then
                print('[tarrant_medical] Hospital survey refused: coordinates must be finite numbers')
                return
            end
        end
        h = { x=values[1], y=values[2], z=values[3], heading=values[4] }
    end
    surveying = true
    local ticket, ped = generation, PlayerPedId()
    CreateThread(function()
        if stopped or ticket ~= generation then return end
        local function abort()
            return not loaded or not LocalPlayer.state.isLoggedIn or PlayerPedId() ~= ped or IsEntityDead(ped)
        end
        local ready, _, reason, evidence = prepareSurface(h, ped, ticket, abort)
        if stopped or ticket ~= generation then return end
        if abort() or IsEntityPositionFrozen(ped) or IsPedInAnyVehicle(ped, false) then
            ready, reason = false, 'observer_state_changed'
        end
        releaseStreaming()
        surveying = false
        print(('[tarrant_medical] Hospital survey: target=%.4f,%.4f,%.4f; heading=%.4f; remoteGeometryValid=%s; reason=%s; %s (read-only; requires local alive survey and visual exterior inspection; config unchanged)')
            :format(h.x, h.y, h.z, h.heading, tostring(ready), reason, evidence))
    end)
end, false)
