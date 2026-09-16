-- Run with Lua 5.4 from the repository root; no FXServer or player data required.
local root = 'resources/[tarrant]/tarrant_employment/'
local vector = {}
vector.__sub = function(a, b) return setmetatable({ x = a.x-b.x, y = a.y-b.y, z = a.z-b.z }, vector) end
vector.__len = function(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end
function vec3(x, y, z) return setmetatable({ x=x, y=y, z=z }, vector) end
dofile(root .. 'config.lua')
local cfg = TarrantEmployment
local position, pressed, menu, loop, marker, routeBlip = cfg.center, false, nil, nil, nil, 0
local handlers, finished, cancelled, paid = {}, 0, false, false
lib = {
    callback = { await = function(name)
        if name == 'tarrant_employment:finish' then
            finished = finished + 1
            if finished == 1 then return 2 end
            paid = true
            return 0
        end
        return true
    end },
    registerContext = function(context) menu = context end,
    showContext = function() end,
    showTextUI = function() end,
    hideTextUI = function() end,
    notify = function() end,
    progressCircle = function()
        if cancelled then cancelled = false return false end
        return true
    end
}
AddBlipForCoord = function() routeBlip = routeBlip + 1 return routeBlip end
RemoveBlip = function() end
SetBlipSprite = function() end
SetBlipRoute = function() end
SetNewWaypoint = function() end
SetBlipColour = function() end
SetBlipAsShortRange = function() end
BeginTextCommandSetBlipName = function() end
AddTextComponentString = function() end
EndTextCommandSetBlipName = function() end
DrawMarker = function(_, x, y, z)
    assert(not marker, 'duplicate marker in one frame')
    marker = vec3(x, y, z)
end
PlayerPedId = function() return 1 end
GetEntityCoords = function() return position end
IsControlJustReleased = function() local value = pressed pressed = false return value end
Wait = function() coroutine.yield() end
CreateThread = function(fn) loop = coroutine.create(fn) end
RegisterNetEvent = function(name, fn) handlers[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
GetCurrentResourceName = function() return 'tarrant_employment' end
dofile(root .. 'client.lua')
local function tick()
    marker = nil
    local ok, err = coroutine.resume(loop)
    assert(ok, err)
    return marker
end
local function selectJob(name)
    position = cfg.center
    pressed = true
    tick()
    for _, option in ipairs(menu.options) do
        if option.title == cfg.jobs[name].label then option.onSelect() return end
    end
    error('job missing from menu')
end
selectJob('garbage')
local first, second = cfg.jobs.garbage.stops[1], cfg.jobs.garbage.stops[2]
position = vec3(first.x + 20, first.y, first.z)
local visible = tick()
assert(visible and visible.x == first.x and visible.y == first.y and visible.z < first.z)
position = vec3(first.x + 3, first.y, first.z)
assert(tick() and finished == 0, 'approach must not advance the task')
pressed = true
tick()
assert(finished == 0, 'E outside 2.5 meters must not advance')
position = first
cancelled = true
pressed = true
tick()
assert(finished == 0 and tick().x == first.x, 'cancel must retain the current task')
pressed = true
tick()
assert(finished == 1 and not paid and not tick(), 'first completion must advance without paying')
pressed = true
tick()
assert(finished == 1, 'E at old stop must not advance the next task')
position = second
assert(tick().x == second.x, 'marker must move to the next task')
pressed = true
tick()
assert(finished == 2 and paid and not tick(), 'final completion must clear the marker')
selectJob('garbage')
position = first
assert(tick())
handlers['QBCore:Client:OnPlayerUnload']()
assert(not tick(), 'unload must clear the marker')
selectJob('garbage')
position = first
assert(tick())
position = cfg.center
pressed = true
tick()
for _, option in ipairs(menu.options) do
    if option.title == 'End shift / go off duty' then option.onSelect() break end
end
position = first
assert(not tick(), 'shift end must clear the marker')
selectJob('garbage')
position = first
assert(tick())
handlers['QBCore:Client:SetDuty'](false)
assert(not tick(), 'off duty must clear the marker')
selectJob('garbage')
position = first
assert(tick())
handlers.onResourceStop('tarrant_employment')
assert(not tick(), 'resource stop must clear the marker')
print('PASS: employment marker visibility, cancellation, progression and cleanup')
