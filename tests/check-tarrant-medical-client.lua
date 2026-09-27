local root = 'resources/[tarrant]/tarrant_medical/'
dofile(root .. 'config.lua')
local threads, handlers = {}, {}
local now, hp, pressed, requests, resurrects, cancellations = 0, 200, false, 0, 0, 0
local frozen, faded, groundOK = false, false, true
local serverState, accepted, label = false, false, nil
LocalPlayer = { state = { isLoggedIn = true } }
source = 65535
PlayerPedId = function() return 1 end
PlayerId = function() return 1 end
SetPlayerControl = function(_, enabled) assert(enabled) end
GetGameTimer = function() return now end
IsEntityDead = function() return hp <= 100 end
SetEntityHealth = function(_, value) hp = value end
GetEntityMaxHealth = function() return 200 end
GetCurrentResourceName = function() return 'tarrant_medical' end
CreateThread = function(fn) threads[#threads+1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterNetEvent = AddEventHandler
TriggerEvent = function(name) assert(name == 'tarrant_medical:client:death') cancellations = cancellations+1 end
exports = { ox_inventory = { closeInventory = function() end } }
lib = { callback = { await = function(name)
    if name == 'tarrant_medical:status' then return serverState end
    requests = requests+1
    return accepted
end } }
FreezeEntityPosition = function(_, value) frozen = value end
DoScreenFadeOut = function() faded = true end
DoScreenFadeIn = function() faded = false end
RequestCollisionAtCoord = function() end
SetEntityCoordsNoOffset = function() error('Do not move before validation') end
GetGroundZFor_3dCoord = function() return groundOK, TarrantMedical.hospital.z end
IsNewLoadSceneActive = function() return false end
SetFocusPosAndVel = function() end
ClearFocus = function() end
NewLoadSceneStartSphere = function() return true end
NewLoadSceneStop = function() end
IsNewLoadSceneLoaded = function() return groundOK end
StartExpensiveSynchronousShapeTestLosProbe = function() return 1 end
GetShapeTestResult = function() return 2, true, {z=TarrantMedical.hospital.z}, {z=1}, 0 end
IsAnyVehicleNearPoint = function() return false end
NetworkResurrectLocalPlayer = function() resurrects = resurrects+1 hp=200 end
IsControlJustReleased = function() local value=pressed pressed=false return value end
for _, name in ipairs({'ClearPedTasksImmediately','ClearPedBloodDamage','RestorePlayerStamina','SetGameplayCamRelativeHeading','SetGameplayCamRelativePitch','SetTextFont','SetTextScale','SetTextCentre','SetTextColour','SetTextOutline','BeginTextCommandDisplayText','EndTextCommandDisplayText'}) do _G[name]=function() end end
AddTextComponentSubstringPlayerName = function(value) label=value end
local function tick(index)
    local ok, err = coroutine.resume(threads[index]) assert(ok, err)
end
local function sync(value) serverState=value handlers['tarrant_medical:client:state'](value) end
dofile(root .. 'client.lua')
tick(1) tick(2) assert(not label)
hp=0 tick(2) assert(cancellations==1 and label:find('30s'))
sync({remaining=30,pending=false})
pressed=true tick(2) assert(requests==0 and resurrects==0)
pressed=false now=30000 tick(2) assert(label:find('%[E%]') and resurrects==0)
accepted=true pressed=true tick(2) tick(3)
assert(requests==1 and frozen and faded)
pressed=true tick(2) assert(requests==1)
tick(3) assert(resurrects==1 and hp==200 and not frozen and not faded)
sync(false) label=nil tick(2) assert(not label)
-- External revive, repeated death, stale network message and reconnect enforcement.
hp=0 tick(2) assert(cancellations==2)
hp=200 sync({remaining=20,pending=false})
assert(hp==200, 'replication lag must not kill an externally revived player')
sync(false) label=nil tick(2) assert(not label)
sync({remaining=15,pending=false}) assert(hp==0)
hp=200 sync(false)
source=1 sync({remaining=30,pending=false}) assert(hp==200)
source=65535
-- Stop during collision wait always releases this resource's freeze/fade.
hp=0 sync({remaining=0,pending=false}) groundOK=false pressed=true tick(2) tick(4)
assert(frozen and faded)
handlers.onClientResourceStop('tarrant_medical')
assert(not frozen and not faded)
tick(4) assert(resurrects==1, 'stopped coroutine must not resurrect')
-- Fresh instance: natural collision timeout, external revive at the final yield,
-- and unload before a replication update must all release only owned state.
threads, handlers = {}, {}
hp=200 groundOK=false serverState=false pressed=false
dofile(root .. 'client.lua')
sync({remaining=0,pending=false}) pressed=true tick(2) tick(3)
now=now+TarrantMedical.collisionTimeoutMs+1 tick(3)
assert(hp==0 and resurrects==1 and not frozen and not faded)
groundOK=true sync({remaining=0,pending=false}) pressed=true tick(2) tick(4)
hp=200 tick(4)
assert(resurrects==1 and not frozen and not faded, 'external revive must abort transfer at its final yield')
sync({remaining=0,pending=false}) assert(hp==200, 'late state after aborted transfer cannot kill revived ped')
sync(false)
hp=0 tick(2)
handlers['QBCore:Client:OnPlayerUnload']()
label=nil tick(2) sync({remaining=30,pending=false})
assert(not label, 'unload must suppress UI even before isLoggedIn replication')
print('PASS: medical client detection, explicit key/countdown, duplicate input, recovery, external revive, reconnect and stop cleanup')
