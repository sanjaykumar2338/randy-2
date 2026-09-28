local cfg = TarrantMedical
local recovering, pending, deadline, stopped = false, false, 0, false
local generation, moving = 0, false
local message
local remotePending = false
local sawNativeDeath = false
local loaded = LocalPlayer.state.isLoggedIn == true
local sceneOwned, focusOwned = false, false

local function releaseStreaming()
    if sceneOwned then NewLoadSceneStop() sceneOwned = false end
    if focusOwned then ClearFocus() focusOwned = false end
end

local function cleanup()
    generation = generation + 1
    recovering, pending, remotePending, message = false, false, false, nil
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
        if not IsEntityDead(PlayerPedId()) then cleanup() end
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
    local expires = started + cfg.collisionTimeoutMs
    local ground, ready, reason = nil, false, 'scene_busy'
    local function externalRevive()
        generation = generation + 1
        releaseStreaming()
        DoScreenFadeIn(250)
        moving, pending = false, false
        -- Retain observed-death history until server confirmation, so a delayed
        -- status response cannot mistake this revived ped for a fresh login.
        message = 'Revived. Confirming recovery...'
    end
    -- Stream the destination independently of the dead ped. Ground queries need
    -- rendered terrain; collision around the original ped cannot validate it.
    if not IsNewLoadSceneActive() then
        SetFocusPosAndVel(h.x, h.y, h.z, 0.0, 0.0, 0.0)
        focusOwned = true
        sceneOwned = NewLoadSceneStartSphere(h.x, h.y, h.z, 30.0, 0)
        reason = 'scene_start_failed'
        if sceneOwned then
            repeat
                if not IsEntityDead(ped) then externalRevive() return end
                if IsEntityPositionFrozen(ped) or IsPedInAnyVehicle(ped, false) then
                    reason = 'ped_frozen_or_in_vehicle'
                    break
                end
                RequestCollisionAtCoord(h.x, h.y, h.z)
                reason = 'scene_not_loaded'
                if IsNewLoadSceneLoaded() then
                    local found
                    found, ground = GetGroundZFor_3dCoord(h.x, h.y, h.z + 1.0, false)
                    reason = 'ground_not_found'
                    if found then
                        reason = 'ground_z_mismatch'
                        if math.abs(ground-h.z) <= 2.0 then
                            -- Require actual destination world collision and a walkable
                            -- surface; never replace the old Z bound with a fallback Z.
                            local probe = StartExpensiveSynchronousShapeTestLosProbe(
                                h.x, h.y, h.z + 1.0, h.x, h.y, h.z - 2.5, 1, ped, 7)
                            local result, hit, point, normal = GetShapeTestResult(probe)
                            reason = 'ground_collision_unavailable'
                            if result == 2 and hit and math.abs(point.z-ground) <= 0.25 then
                                reason = 'surface_too_steep'
                                if normal.z >= 0.9 then
                                    reason = 'vehicle_at_spawn'
                                    ready = not IsAnyVehicleNearPoint(h.x, h.y, ground + 1.0, 2.0)
                                end
                            end
                        end
                    end
                end
                Wait(50)
            until stopped or ticket ~= generation or ready or GetGameTimer() >= expires
        end
    end
    if stopped or ticket ~= generation then return end
    if not IsEntityDead(ped) then externalRevive() return end
    local current = GetEntityCoords(ped)
    if IsEntityPositionFrozen(ped) or IsPedInAnyVehicle(ped, false)
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
        print(('[tarrant_medical] Recovery validation failed: mode=%s; reason=%s; target=%.4f,%.4f,%.4f; ped=%.4f,%.4f,%.4f; ground=%s; elapsed=%dms')
            :format(mode, reason, h.x, h.y, h.z, current.x, current.y, current.z, tostring(ground), GetGameTimer()-started))
        message = here and 'Local surface unavailable. Survey another pavement location; console retry required.'
            or 'Hospital surface unavailable. Please wait, then press E to retry.'
    end
    releaseStreaming()
    DoScreenFadeIn(500)
    moving = false
end

-- Only the server console can issue this exception to civilian hospital recovery.
RegisterNetEvent('tarrant_medical:client:recoverHere', function()
    if source ~= 65535 or stopped or not loaded or moving or pending
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
            if not pending and not remotePending and seconds == 0 and IsControlJustReleased(0, 38) then
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
    if stopped or not loaded or not LocalPlayer.state.isLoggedIn or moving then
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
