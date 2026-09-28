local commands = {}
RegisterCommand = function(name, fn) commands[name] = fn end
local root = 'resources/[tarrant]/tarrant_medical/'
dofile(root .. 'config.lua')
assert(loadfile(root .. 'fxmanifest.lua'))
assert(TarrantMedical.recoverySeconds == 30)
local callbacks, handlers, threads, events = {}, {}, {}, {}
local now, hp, bucket, logged, cid = 100, 200, 0, true, 'civilian'
local state = { isLoggedIn = true, hunger = 0, thirst = 50, canUseWeapons = false }
function state:set(key, value) self[key] = value end
local metadata = { isdead = false, inlaststand = false }
local data = { metadata = metadata, citizenid = cid, money = { cash = 90, bank = 1000 }, items = { 'phone' } }
local saved, pos = 0, { x=1, y=1, z=1 }
os.time = function() return now end
Player = function() state.isLoggedIn = logged return { state=state } end
GetPlayerPed = function() return 1 end
GetEntityHealth = function() return hp end
GetEntityCoords = function() return pos end
GetPlayerRoutingBucket = function() return bucket end
GetPlayers = function() return {'1'} end
TriggerClientEvent = function(name, src, value) events[#events+1] = {name, src, value} end
local deaths = 0
TriggerEvent = function(name, src) assert(name == 'tarrant_medical:server:death' and src == 1) deaths = deaths + 1 end
RegisterNetEvent = function() error('no client-authorized revive events allowed') end
AddEventHandler = function(name, fn) handlers[name] = fn end
CreateThread = function(fn) threads[#threads+1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
exports = { qbx_core = {
    GetPlayer = function() return { PlayerData=data } end,
    SetMetadata = function(_, _, key, value) metadata[key] = value end,
    Save = function() saved = saved + 1 end,
    SetPlayerBucket = function(_, _, value) bucket = value return true end,
} }
local function start() callbacks, handlers, threads = {}, {}, {} dofile(root .. 'server.lua') end
local function call(name) return callbacks['tarrant_medical:' .. name](1) end
start()
assert(not call('status') and not call('request'))
hp = 100
assert(call('status').remaining == 30 and deaths == 1)
assert(metadata.isdead and state.dead and state.isDead and not state.canUseWeapons)
assert(not call('request'))
now = 129 assert(not call('request'))
now = 130
assert(call('status').remaining == 0 and hp == 100, 'no automatic respawn')
bucket = 3
assert(call('request') and bucket == 0)
for _=1,10 do assert(not call('request')) end
assert(call('status').pending)
-- Dead at hospital is not a successful recovery.
pos = TarrantMedical.hospital
assert(call('status') and metadata.isdead)
hp = 200
assert(not call('status'))
assert(not metadata.isdead and not metadata.inlaststand and not metadata.tarrantRecovery)
assert(not state.dead and not state.isDead and not state.medicalRecovery)
assert(state.canUseWeapons == false, 'do not unlock unrelated weapon restriction')
assert(metadata.hunger == 25 and metadata.thirst == 50)
assert(saved == 1 and data.money.cash == 90 and data.money.bank == 1000 and data.items[1] == 'phone')
-- External resurrection clears UI/state without waiting for countdown.
hp = 0 now = 200 assert(call('status').remaining == 30)
hp = 200 assert(not call('status') and not metadata.isdead)
hp = 0 now = 240 assert(call('status')) now = 270 assert(call('request'))
pos = {x=0,y=0,z=0} hp = 200
assert(not call('status'), 'external revive during a pending transfer must clear stale state')
-- Restart preserves deadline, and a new alive login ped cannot bypass it.
hp = 0 now = 300 assert(call('status').remaining == 30)
source = 1 handlers.playerDropped()
hp = 200 now = 310
assert(call('status').remaining == 20 and metadata.isdead)
assert(not call('request'), 'persisted state alone cannot authorize an alive ped')
hp = 0
start()
assert(call('status').remaining == 20)
now = 330 assert(call('request'))
-- Failed relocation times out and allows retry, never pays or clears death.
now = 351 assert(not call('status').pending and metadata.isdead)
assert(call('request'))
start()
assert(not call('status').pending and call('request'), 'restart safely retries unfinished recovery')
hp = 200 pos = TarrantMedical.hospital assert(not call('status'))
logged = false hp = 0 assert(not call('status') and not call('request'))
logged = true assert(call('status'))
handlers['qbx_core:server:playerLoggedOut'](1)
assert(not state.dead and not state.isDead and not state.medicalRecovery)
data.citizenid = 'another' data.metadata = {} metadata = data.metadata hp = 200
assert(not call('status'), 'no cross-character recovery')
assert(data.money.cash == 90 and data.money.bank == 1000 and #data.items == 1)
print('PASS: medical server death, countdown, authority, replay, external revive, restart/reconnect, character isolation and money/items preservation')

hp=0 now=500 assert(call('status'))
local before=#events
commands.medical_recover_here(1, {'1'})
assert(#events==before, 'client cannot authorize rescue')
commands.medical_recover_here(0, {'1'})
assert(events[#events][1]=='tarrant_medical:client:recoverHere')
assert(call('status').pending and metadata.isdead and hp==0)
commands.medical_recover_here(0, {'1'})
now=521 assert(not call('status').pending and metadata.isdead)
commands.medical_recover_here(0, {'1'})
hp=200 pos={x=1000,y=1000,z=50}
assert(not call('status') and not metadata.tarrantRecovery and metadata.hunger==25)
print('PASS: console-only rescue, duplicate/expiry, persistence on rejection and completion away from hospital')
