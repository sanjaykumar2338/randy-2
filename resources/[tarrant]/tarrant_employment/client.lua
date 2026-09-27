local cfg = TarrantEmployment
local active, stop, working, routeBlip
local generation = 0
local routeRevision = 0
local ownedText, ownedProgress, stopped = nil, false, false
local loaded = LocalPlayer.state.isLoggedIn == true
local function unavailable()
    return not loaded or IsEntityDead(PlayerPedId()) or LocalPlayer.state.medicalRecovery == true
end
local function hideText()
    local open, text = lib.isTextUIOpen()
    if ownedText and open and text == ownedText then lib.hideTextUI() end
    ownedText = nil
end
local function closeMenu()
    if lib.getOpenContextMenu() == 'tarrant_jobs' then lib.hideContext(false) end
end
local function cancelInteraction()
    generation = generation + 1
    hideText()
    closeMenu()
    if ownedProgress and lib.progressActive() then lib.cancelProgress() end
end
local function clearRoute()
    generation = generation + 1
    routeRevision = routeRevision + 1
    active, stop = nil, nil
    if routeBlip then RemoveBlip(routeBlip) routeBlip = nil end
end
local function waypoint()
    if routeBlip then RemoveBlip(routeBlip) end
    local coords = cfg.jobs[active].stops[stop]
    routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(routeBlip, 1)
    SetBlipRoute(routeBlip, true)
    SetNewWaypoint(coords.x, coords.y)
end
local function menu()
    local options = {}
    for id, job in pairs(cfg.jobs) do
        options[#options + 1] = { title = job.label, description = ('$%d cash payment after %d stops. Start/restart shift.'):format(job.pay, #job.stops),
            onSelect = function()
                if unavailable() then return end
                local ticket = generation
                if lib.callback.await('tarrant_employment:select', false, id) then
                    if ticket ~= generation or unavailable() then return end
                    clearRoute()
                    active, stop = id, 1
                    waypoint()
                    lib.notify({ description = 'On duty. Follow the route and complete each marked task.' })
                else lib.notify({ description = 'Unable to select job. Appointed jobs cannot be replaced here.', type = 'error' }) end
            end }
    end
    options[#options + 1] = { title = 'End shift / go off duty', onSelect = function()
        if lib.callback.await('tarrant_employment:stop', false) then clearRoute() end
    end }
    options[#options + 1] = { title = 'Directions: legal gun shop',
        description = 'Ammunation uses cash. Pistol requires the existing paid weapon license.',
        onSelect = function() SetNewWaypoint(22.56, -1109.89) end }
    options[#options + 1] = { title = 'Directions: weapon license',
        description = 'Existing OX license desk: $5,000 cash. Press E at the location.',
        onSelect = function() SetNewWaypoint(12.42198, -1105.82) end }
    hideText()
    lib.registerContext({ id = 'tarrant_jobs', title = 'Tarrant County Employment Center', options = options,
        onExit = hideText })
    lib.showContext('tarrant_jobs')
end
local centerBlip = AddBlipForCoord(cfg.center.x, cfg.center.y, cfg.center.z)
SetBlipSprite(centerBlip, 408)
SetBlipColour(centerBlip, 3)
SetBlipAsShortRange(centerBlip, true)
BeginTextCommandSetBlipName('STRING')
AddTextComponentString('Tarrant County Employment Center')
EndTextCommandSetBlipName(centerBlip)
CreateThread(function()
    local wasUnavailable = false
    while not stopped do
        local coords = GetEntityCoords(PlayerPedId())
        local blocked = unavailable()
        if blocked and not wasUnavailable then cancelInteraction() end
        wasUnavailable = blocked
        local centerDistance = #(coords - cfg.center)
        local nearCenter = not blocked and centerDistance < 25.0
        local atCenter = not blocked and centerDistance < 2.5
        if nearCenter then
            -- Foot-coordinate convention matches the already accepted task markers.
            DrawMarker(1, cfg.center.x, cfg.center.y, cfg.center.z - 0.9,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.4, 1.4, 0.3, 240, 180, 45, 165,
                false, false, 2, false, nil, nil, false)
        end
        if not atCenter then closeMenu() end
        local taskCoords = active and cfg.jobs[active].stops[stop]
        local taskDistance = taskCoords and #(coords - taskCoords)
        local nearTask = not blocked and taskDistance and taskDistance < 35.0
        if nearTask then
            -- Stops are player-foot coordinates; lower the cylinder so it sits on the ground.
            DrawMarker(1, taskCoords.x, taskCoords.y, taskCoords.z - 0.9,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.2, 1.2, 0.6, 168, 80, 220, 145,
                false, true, 2, false, nil, nil, false)
        end
        local atStop = not blocked and taskDistance and taskDistance < 2.5
        local label = not working and lib.getOpenContextMenu() ~= 'tarrant_jobs'
            and (atCenter and '[E] Employment Center' or atStop and ('[E] ' .. cfg.jobs[active].action))
        local open, text = lib.isTextUIOpen()
        if not label then hideText()
        elseif not open or (ownedText and text == ownedText) then
            if not open or text ~= label then lib.showTextUI(label) end
            ownedText = label
        else
            ownedText = nil
        end
        if label and ownedText == label and IsControlJustReleased(0, 38) then
            if atCenter then menu() else
                working = true
                local routeGeneration, revision, action = generation, routeRevision, cfg.jobs[active].action
                local began = lib.callback.await('tarrant_employment:begin', false)
                if began and generation == routeGeneration and not unavailable() then
                    hideText()
                    ownedProgress = true
                    local done = lib.progressCircle({ duration = (cfg.secondsPerStop + 1) * 1000, label = action,
                        canCancel = true, disable = { move = true, car = true, combat = true } })
                    ownedProgress = false
                    if done and generation == routeGeneration and not unavailable() then
                        local nextStop = lib.callback.await('tarrant_employment:finish', false)
                        if routeRevision ~= revision then
                            -- Route/character changed while the callback was outstanding.
                        elseif nextStop == 0 then
                            lib.notify({ description = 'Route completed. Cash payment received. Return to the Employment Center.' })
                            clearRoute()
                        elseif nextStop then stop = nextStop waypoint()
                        elseif not unavailable() then
                            clearRoute() lib.notify({ description = 'Shift expired or validation failed. Return to the Employment Center.', type = 'error' })
                        end
                    end
                elseif generation == routeGeneration and not unavailable() then
                    clearRoute() lib.notify({ description = 'Return to the Employment Center to start a shift.', type = 'error' })
                end
                working = false
            end
        end
        Wait((label or nearTask or nearCenter) and 0 or 500)
    end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() loaded = true end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    loaded = false
    cancelInteraction()
    clearRoute()
end)
AddEventHandler('tarrant_medical:client:death', cancelInteraction)
RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    if not onDuty then clearRoute() end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopped = true
    cancelInteraction()
    clearRoute()
    RemoveBlip(centerBlip)
end)
