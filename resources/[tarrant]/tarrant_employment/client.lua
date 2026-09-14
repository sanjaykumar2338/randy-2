local cfg = TarrantEmployment
local active, stop, working, routeBlip
local generation = 0
local function clearRoute()
    generation = generation + 1
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
                if lib.callback.await('tarrant_employment:select', false, id) then
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
    lib.registerContext({ id = 'tarrant_jobs', title = 'Tarrant County Employment Center', options = options })
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
    local shown
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local atCenter = #(coords - cfg.center) < 2.5
        local atStop = active and #(coords - cfg.jobs[active].stops[stop]) < 2.5
        local label = not working and (atCenter and '[E] Employment Center' or atStop and ('[E] ' .. cfg.jobs[active].action))
        if label ~= shown then
            if label then lib.showTextUI(label) elseif shown then lib.hideTextUI() end
            shown = label
        end
        if label and IsControlJustReleased(0, 38) then
            if atCenter then menu() else
                working = true
                local routeGeneration, action = generation, cfg.jobs[active].action
                if lib.callback.await('tarrant_employment:begin', false) and generation == routeGeneration then
                    local done = lib.progressCircle({ duration = (cfg.secondsPerStop + 1) * 1000, label = action,
                        canCancel = true, disable = { move = true, car = true, combat = true } })
                    if done and generation == routeGeneration then
                        local nextStop = lib.callback.await('tarrant_employment:finish', false)
                        if generation ~= routeGeneration then
                            -- Character unloaded while the callback was outstanding.
                        elseif nextStop == 0 then
                            lib.notify({ description = 'Route completed. Cash payment received. Return to the Employment Center.' })
                            clearRoute()
                        elseif nextStop then stop = nextStop waypoint()
                        else clearRoute() lib.notify({ description = 'Shift expired or validation failed. Return to the Employment Center.', type = 'error' }) end
                    end
                else clearRoute() lib.notify({ description = 'Return to the Employment Center to start a shift.', type = 'error' }) end
                working = false
            end
        end
        Wait(label and 0 or 500)
    end
end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', clearRoute)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearRoute()
    RemoveBlip(centerBlip)
    lib.hideTextUI()
end)
