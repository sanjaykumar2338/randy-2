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
local text, context, dead, inProgress, dieInProgress = nil, nil, false, false, false
LocalPlayer = { state = { isLoggedIn = true } }
IsEntityDead = function() return dead end
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
    showContext = function(id) context = id end,
    getOpenContextMenu = function() return context end,
    hideContext = function() context = nil end,
    showTextUI = function(value) text = value end,
    hideTextUI = function() text = nil end,
    isTextUIOpen = function() return text ~= nil, text end,
    progressActive = function() return inProgress end,
    cancelProgress = function() inProgress = false end,
    notify = function() end,
    progressCircle = function()
        if dieInProgress then
            inProgress, dead, dieInProgress = true, true, false
            handlers['tarrant_medical:client:death']()
            assert(not inProgress, 'death must cancel owned progress')
            return false
        end
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
    pressed = false -- A released-control edge cannot carry into a later frame.
    return marker
end
local function selectJob(name)
    handlers['QBCore:Client:OnPlayerLoaded']()
    position = cfg.center
    pressed = true
    tick()
    for _, option in ipairs(menu.options) do
        if option.title == cfg.jobs[name].label then context = nil option.onSelect() return end
    end
    error('job missing from menu')
end
position = vec3(cfg.center.x + 24, cfg.center.y, cfg.center.z)
assert(tick() and not text, 'center approach marker without premature E prompt')
position = vec3(cfg.center.x + 26, cfg.center.y, cfg.center.z)
assert(not tick(), 'center marker outside approach radius')
position = cfg.center
assert(tick().z == cfg.center.z - 0.9 and text == '[E] Employment Center')
text = 'Other resource'
tick() assert(text == 'Other resource')
position = vec3(0,0,0) tick() assert(text == 'Other resource')
text = nil position = cfg.center tick() assert(text == '[E] Employment Center')
pressed = true tick() assert(context == 'tarrant_jobs' and not text)
menu.onExit() context = nil tick() assert(text == '[E] Employment Center')
pressed = true tick() position = vec3(0,0,0) tick() assert(not context and not text)
position = cfg.center pressed = true tick()
dead = true handlers['tarrant_medical:client:death']()
assert(not context and not text and not tick())
dead = false
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
dieInProgress = true pressed = true tick()
assert(finished == 1 and not paid and not tick(), 'death cancels unfinished action and hides marker')
dead = false
assert(tick().x == second.x, 'recovery retains completed stop progression')
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
handlers.onClientResourceStop('tarrant_employment')
assert(not tick(), 'resource stop must clear the marker')
print('PASS: employment marker visibility, cancellation, progression and cleanup')
