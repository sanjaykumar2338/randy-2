SetEntityVelocity = function() end
IsEntityPositionFrozen = function() return false end
IsPedInAnyVehicle = function() return false end
GetEntityHeading = function() return 70 end
GetEntityCoords = function() return {x=1000,y=1000,z=50} end
-- Destination validation must never use a premature teleport as a streaming aid.
local root = 'resources/[tarrant]/tarrant_medical/'
dofile(root .. 'config.lua')
local h = TarrantMedical.hospital
local now, health, pressed, moves, resurrects, groundCalls
local focus, scene, frozen, faded, logs, threads, handlers, scenario
local position, target, commands
local function reset(options)
    commands = {}
    RegisterCommand = function(name, fn) commands[name] = fn end
    scenario = options or {}
    IsEntityPositionFrozen = function() return scenario.frozen or false end
    IsPedInAnyVehicle = function() return scenario.inVehicle or false end
    now, health, pressed, moves, resurrects, groundCalls = 0, 0, false, 0, 0, 0
    focus, scene, frozen, faded = false, false, false, false
    logs, threads, handlers = {}, {}, {}
    position = { x=1000, y=1000, z=50 }
    target = { x=h.x, y=h.y, z=h.z }
    LocalPlayer = { state = { isLoggedIn=true } }
    source = 65535
    PlayerPedId = function() return 1 end
    PlayerId = function() return 1 end
    GetGameTimer = function() return now end
    IsEntityDead = function() return health <= 100 end
    GetEntityCoords = function() return position end
    SetEntityHealth = function(_, value) health=value end
    GetEntityMaxHealth = function() return 200 end
    GetCurrentResourceName = function() return 'tarrant_medical' end
    CreateThread = function(fn) threads[#threads+1]=coroutine.create(fn) end
    Wait = function() coroutine.yield() end
    RegisterNetEvent = function(name, fn) handlers[name]=fn end
    AddEventHandler = RegisterNetEvent
    TriggerEvent = function() end
    exports = { ox_inventory = { closeInventory=function() end } }
    lib = { callback={await=function() return true end} }
    FreezeEntityPosition = function() error('medical must not change foreign freeze state') end
    DoScreenFadeOut = function() faded=true end
    DoScreenFadeIn = function() faded=false end
    RequestCollisionAtCoord = function() end
    SetEntityCoordsNoOffset = function(_, x,y,z) moves=moves+1 position={x=x,y=y,z=z} end
    HasCollisionLoadedAroundEntity = function() return true end -- Origin collision proves nothing about destination.
    IsNewLoadSceneActive = function() return scenario.busy or scene end
    SetFocusPosAndVel = function() focus=true end
    ClearFocus = function() focus=false end
    NewLoadSceneStartSphere = function() scene=not scenario.startFailed return scene end
    NewLoadSceneStop = function() assert(scene, 'must stop only the scene acquired by medical') scene=false end
    IsNewLoadSceneLoaded = function() return now >= (scenario.sceneAfter or 0) end
    GetGroundZFor_3dCoord = function()
        groundCalls=groundCalls+1
        if scenario.noGround then return false, 0 end
        if scenario.wrongGround or (scenario.transientGround and groundCalls==1) then return true,h.z-10 end
        return true,scenario.groundZ or h.z
    end
    StartExpensiveSynchronousShapeTestLosProbe = function() return 1 end
    GetShapeTestResult = function()
        return 2, not scenario.noCollision, {x=target.x,y=target.y,z=(scenario.rayZ or scenario.groundZ or h.z)-(scenario.wrongRayHeight and 3 or 0)},
            {x=0,y=0,z=scenario.steep and 0.4 or 1}, 0
    end
    IsAnyVehicleNearPoint = function() return scenario.vehicle or false end
    NetworkResurrectLocalPlayer = function(x,y,z,heading)
        assert(heading==h.heading or heading==70)
        resurrects=resurrects+1 health=200 position={x=x,y=y,z=z}
    end
    IsControlJustReleased = function() local value=pressed pressed=false return value end
    for _,name in ipairs({'SetPlayerControl','ClearPedTasksImmediately','ClearPedBloodDamage','RestorePlayerStamina','SetGameplayCamRelativeHeading','SetGameplayCamRelativePitch','SetTextFont','SetTextScale','SetTextCentre','SetTextColour','SetTextOutline','BeginTextCommandDisplayText','EndTextCommandDisplayText','AddTextComponentSubstringPlayerName'}) do _G[name]=function() end end
    print = function(line) logs[#logs+1]=line end
    dofile(root .. 'client.lua')
    handlers['tarrant_medical:client:state']({remaining=0,pending=false})
end
local function tick(index)
    local ok, err=coroutine.resume(threads[index]) assert(ok,err)
end
local function begin() pressed=true tick(2) tick(3) end
local function unchanged()
    assert(moves==0 and resurrects==0 and health==0 and position.x==1000,
        'unvalidated destination must never move or resurrect the dead player')
end
local originalPrint = print
reset({sceneAfter=200, transientGround=true}) begin() unchanged()
now=200 tick(3) unchanged()
assert(coroutine.status(threads[3])~='dead', 'wrong early ground must not end the loading window')
now=250 tick(3) now=300 tick(3)
assert(resurrects==1 and moves==0 and position.x==target.x and not focus and not scene and not frozen and not faded)

for _,case in ipairs({
    {noGround=true, reason='ground_not_found'},
    {wrongGround=true, reason='ground_z_mismatch'},
    {noCollision=true, reason='ground_collision_unavailable'},
    {wrongRayHeight=true, reason='ground_collision_unavailable'},
    {steep=true, reason='surface_too_steep'},
    {vehicle=true, reason='vehicle_at_spawn'},
    {sceneAfter=9000, reason='scene_not_loaded'},
}) do
    reset(case) begin() unchanged()
    now=8001 tick(3) unchanged()
    assert(not focus and not scene and not frozen and not faded and #logs==2, 'failure must release streaming/freeze and explain the rejected check')
    assert(logs[1]:find('mode=hospital') and logs[2]:find(case.reason, 1, true) and logs[2]:find('target=') and logs[2]:find('ground=') and logs[2]:find('elapsed='))
    -- Once the server lease permits a retry, the next attempt must be independent.
    scenario={} handlers['tarrant_medical:client:state']({remaining=0,pending=false})
    pressed=true tick(2) tick(4) now=8051 tick(4)
    assert(resurrects==1 and moves==0 and not scene and not focus)
end
reset({busy=true}) begin() unchanged() assert(not focus and not frozen and not faded)
reset({startFailed=true}) begin() unchanged() assert(not focus and not scene and not frozen and not faded)
for _,event in ipairs({'onClientResourceStop','QBCore:Client:OnPlayerUnload'}) do
    reset({noGround=true}) begin() unchanged()
    handlers[event]('tarrant_medical') now=50 tick(3) unchanged()
    assert(not focus and not scene and not frozen and not faded)
end
reset({noGround=true}) begin() health=200 now=50 tick(3)
assert(moves==0 and resurrects==0 and position.x==1000 and not focus and not scene and not frozen and not faded)
-- NoClip/foreign freeze must never be released, even on stop or external revive.
reset({frozen=true}) begin() unchanged()
assert(not faded and not scene)
reset({noGround=true}) begin() scenario.frozen=true now=50 tick(3) unchanged()
assert(not faded and not scene)
reset({inVehicle=true}) begin() unchanged()
reset({groundZ=50})
handlers['tarrant_medical:client:recoverHere']()
handlers['QBCore:Client:OnPlayerUnload']() tick(3) unchanged()
assert(not scene and not faded)
-- Console rescue validates the current location, refuses airborne/moving peds,
-- and cannot be triggered as a local/client-origin event.
reset({groundZ=50})
source=1 handlers['tarrant_medical:client:recoverHere']() assert(#threads==2)
source=65535 handlers['tarrant_medical:client:recoverHere']() tick(3) now=50 tick(3)
assert(resurrects==1 and position.x==1000 and position.z==51 and #logs==2)
reset({groundZ=40})
handlers['tarrant_medical:client:recoverHere']() tick(3) now=8001 tick(3) unchanged()
reset({groundZ=50})
handlers['tarrant_medical:client:recoverHere']() tick(3)
position={x=1005,y=1000,z=50} now=50 tick(3)
assert(resurrects==0 and logs[2]:find('ped_moved_or_frozen'))
-- Recover-here must report and use the ped origin, never the hospital config.
reset({groundZ=16.756881713867})
handlers['tarrant_medical:client:recoverHere']() tick(3) now=8001 tick(3) unchanged()
assert(logs[1]:find('mode=recover_here') and logs[1]:find('target=1000.0000,1000.0000,50.0000'))
assert(logs[2]:find('ground_z_mismatch') and logs[2]:find('16.756'))
-- Survey independently records ray evidence even when ground disagrees; no mutation.
scenario.rayZ=50
commands.medical_survey_here()
assert(logs[3]:find('geometryAgrees=false') and logs[3]:find('rayZ=50'))
unchanged() assert(not scene and not focus and not faded)
reset({groundZ=50}) commands.medical_survey_here() unchanged()
assert(logs[1]:find('geometryAgrees=true') and logs[1]:find('aliveCandidate=false'))
health=200 commands.medical_survey_here()
assert(logs[2]:find('aliveCandidate=true') and health==200 and resurrects==0 and moves==0)
for _,case in ipairs({{frozen=true}, {inVehicle=true}, {noGround=true}, {noCollision=true}, {steep=true}, {vehicle=true}, {wrongRayHeight=true}}) do
    case.groundZ=50 reset(case) health=200 commands.medical_survey_here()
    assert(logs[1]:find('aliveCandidate=false') and health==200 and moves==0 and resurrects==0)
    assert(not scene and not focus and not faded)
end
reset({groundZ=50}) handlers['QBCore:Client:OnPlayerUnload']() commands.medical_survey_here()
assert(logs[1]:find('Survey unavailable'))
print=originalPrint
print('PASS: remote scene/surface validation, transient wrong Z, collision/slope/obstruction rejection, origin preservation, retry and streaming cleanup')
