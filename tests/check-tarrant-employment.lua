local root = 'resources/[tarrant]/tarrant_employment/'
local vector = {}
vector.__sub = function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}, vector) end
vector.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vec3(x,y,z) return setmetatable({x=x,y=y,z=z}, vector) end
dofile(root .. 'config.lua')
assert(loadfile(root .. 'client.lua'))
assert(loadfile(root .. 'fxmanifest.lua'))
local cfg = TarrantEmployment
local callbacks, handlers = {}, {}
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
AddEventHandler = function(name, fn) handlers[name] = fn end
local now, bucket, alive, paid, saves, failPay = 100, 0, true, 0, 0, false
os.time = function() return now end
local coords = cfg.center
GetPlayerPed = function() return 1 end
GetPlayerRoutingBucket = function() return bucket end
GetEntityHealth = function() return alive and 200 or 0 end
GetEntityCoords = function() return coords end
local p = { PlayerData = { citizenid = 'test', metadata = {}, job = {name='unemployed'} } }
exports = { qbx_core = {
    GetPlayer = function() return p end,
    SetJob = function(_, src, name, grade)
        assert(grade == 0 and cfg.jobs[name])
        p.PlayerData.job = {name=name}
        return true
    end,
    SetJobDuty = function(_, src, duty) p.PlayerData.job.onduty = duty end,
    Save = function() saves = saves + 1 end,
    AddMoney = function(_, src, account, amount)
        assert(account == 'cash')
        if failPay then return false end
        paid = paid + amount
        return true
    end
} }
dofile(root .. 'server.lua')
local function call(name, ...) return callbacks['tarrant_employment:' .. name](1, ...) end
assert(not call('select', 'police'))
assert(not call('select', {}))
bucket = 1 assert(not call('select', 'garbage')) bucket = 0
alive = false assert(not call('select', 'garbage')) alive = true
p.PlayerData.job.name = 'police' assert(not call('select', 'garbage'))
p.PlayerData.job.name = 'unemployed'
coords = vec3(0,0,0) assert(not call('select', 'garbage')) coords = cfg.center
assert(call('select', 'garbage') and saves == 1 and p.PlayerData.job.onduty)
assert(not call('finish') and not call('begin'))
coords = cfg.jobs.garbage.stops[1]
assert(call('begin')) assert(not call('finish'))
now = now + cfg.secondsPerStop
assert(call('finish') == 2) assert(not call('finish'))
coords = cfg.jobs.garbage.stops[2]
assert(call('begin'))
handlers['tarrant_medical:server:death'](1)
now = now + cfg.secondsPerStop
assert(not call('finish') and paid == 0, 'death invalidates unfinished action')
p.PlayerData.metadata.isdead = true
assert(not call('begin'))
p.PlayerData.metadata.isdead = false
assert(not call('finish'), 'revive cannot complete an invalidated action')
assert(call('begin'))
local normalHealth = GetEntityHealth
GetEntityHealth = function() return 100 end
now = now + cfg.secondsPerStop
assert(not call('finish') and paid == 0, 'native death must block payment before metadata replication')
GetEntityHealth = normalHealth
assert(call('begin')) now = now + cfg.secondsPerStop
assert(call('finish') == 0 and paid == cfg.jobs.garbage.pay and saves == 2)
assert(not call('finish') and paid == cfg.jobs.garbage.pay)
for name, job in pairs(cfg.jobs) do
    coords = cfg.center assert(call('select', name))
    for i, location in ipairs(job.stops) do
        coords = location assert(call('begin')) now = now + cfg.secondsPerStop
        assert(call('finish') == (i == #job.stops and 0 or i+1))
    end
end
coords = cfg.center assert(call('select', 'garbage'))
p.PlayerData.citizenid = 'different' coords = cfg.jobs.garbage.stops[1]
assert(not call('begin'))
coords = cfg.center assert(call('select', 'garbage'))
p.PlayerData.job.onduty = false coords = cfg.jobs.garbage.stops[1] assert(not call('begin'))
coords = cfg.center assert(call('select', 'garbage'))
now = now + cfg.routeLifetime + 1 coords = cfg.jobs.garbage.stops[1] assert(not call('begin'))
coords = cfg.center assert(call('select', 'garbage'))
source = 1 handlers.playerDropped() coords = cfg.jobs.garbage.stops[1] assert(not call('begin'))
coords = cfg.center assert(call('select', 'garbage')) assert(call('stop'))
assert(not p.PlayerData.job.onduty)
coords = cfg.jobs.garbage.stops[1] assert(not call('begin'))
local before = paid
coords = cfg.center assert(call('select', 'garbage')) failPay = true
for _, location in ipairs(cfg.jobs.garbage.stops) do
    coords = location assert(call('begin')) now = now + cfg.secondsPerStop
    call('finish')
end
assert(paid == before and not call('finish'))
print('PASS: employment routes, authority checks, replay protection, lifecycle and payment failure')
