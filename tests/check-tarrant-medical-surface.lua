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
local position, target, commands, rayCalls, requests, focusTarget, collisionEnabled, lastRay, capsulePoint
local function reset(options)
    commands = {}
    RegisterCommand = function(name, fn) commands[name] = fn end
    scenario = options or {}
    IsEntityPositionFrozen = function() return scenario.frozen or false end
    IsPedInAnyVehicle = function() return scenario.inVehicle or false end
    GetEntityCollisionDisabled = function() return scenario.collisionDisabled or false end
    now, health, pressed, moves, resurrects, groundCalls = 0, 0, false, 0, 0, 0
    rayCalls, requests, focusTarget = 0, 0, nil
    collisionEnabled, lastRay = false, nil
    capsulePoint = nil
    if scenario.alive then health = 200 end
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
    lib = { callback={await=function() requests=requests+1 return true end} }
    FreezeEntityPosition = function(_, value)
        assert(resurrects==1 and not value, 'only a validated resurrection may explicitly unfreeze its ped')
        frozen=value
    end
    SetEntityCollision = function(_, value)
        assert(resurrects==1 and value, 'only a validated resurrection may enable collision')
        collisionEnabled=value
    end
    DoScreenFadeOut = function() faded=true end
    DoScreenFadeIn = function() faded=false end
    RequestCollisionAtCoord = function() end
    SetEntityCoordsNoOffset = function(_, x,y,z) moves=moves+1 position={x=x,y=y,z=z} end
    HasCollisionLoadedAroundEntity = function() return true end -- Origin collision proves nothing about destination.
    IsNewLoadSceneActive = function() return scenario.busy or scene end
    SetFocusPosAndVel = function(x,y,z) focus=true focusTarget={x=x,y=y,z=z} end
    ClearFocus = function() focus=false end
    NewLoadSceneStartSphere = function() scene=not scenario.startFailed return scene end
    NewLoadSceneStop = function() assert(scene, 'must stop only the scene acquired by medical') scene=false end
    IsNewLoadSceneLoaded = function() return now >= (scenario.sceneAfter or 0) end
    GetGroundZFor_3dCoord = function(x)
        groundCalls=groundCalls+1
        if scenario.noGround or (scenario.firstInvalid and x==h.x) then return false, 0 end
        if scenario.wrongGround or (scenario.transientGround and groundCalls<=2) then return true,h.z-10 end
        return true,scenario.groundZ or h.z
    end
    GetSafeCoordForPed = function(x,y,_,pavement,flags)
        assert(pavement and flags==15, 'require connected pavement, no interiors or water')
        return not scenario.noPavement, {x=x+(scenario.snapX or 0),y=y,z=scenario.navZ or scenario.groundZ or h.z}
    end
    StartShapeTestCapsule = function(x,y,z,_,_,_,radius,mask,_,options)
        assert(radius==0.45 and mask==511 and options==4)
        capsulePoint={x=x,y=y,z=z}
        return 2
    end
    StartExpensiveSynchronousShapeTestLosProbe = function(x,y,z,_,_,bottom)
        lastRay={x=x,y=y,z=z,bottom=bottom}
        rayCalls=rayCalls+1 return 1
    end
    GetShapeTestResult = function(handle)
        if handle==2 then
            return scenario.capsuleStatus or 2, scenario.obstruction or (scenario.firstObstructed and capsulePoint.x==h.x) or false
        end
        local ledge = scenario.ledge and lastRay.z-lastRay.bottom<2
        return scenario.rayStatus or 2, not scenario.noCollision and not ledge, {x=lastRay.x,y=lastRay.y,z=(scenario.rayZ or scenario.groundZ or h.z)-(scenario.wrongRayHeight and 3 or 0)},
            {x=0,y=0,z=scenario.steep and 0.4 or 1}, 0
    end
    IsAnyVehicleNearPoint = function(x) return scenario.vehicle or (scenario.firstVehicle and x==h.x) or false end
    NetworkResurrectLocalPlayer = function(x,y,z,heading)
        assert(heading==h.heading or heading==70)
        resurrects=resurrects+1 health=200 position={x=x,y=y,z=z}
        frozen=true -- model a resurrected ped requiring explicit movement restoration
    end
    IsControlJustReleased = function() local value=pressed pressed=false return value end
    for _,name in ipairs({'SetPlayerControl','ClearPedTasksImmediately','ClearPedBloodDamage','RestorePlayerStamina','SetGameplayCamRelativeHeading','SetGameplayCamRelativePitch','SetTextFont','SetTextScale','SetTextCentre','SetTextColour','SetTextOutline','BeginTextCommandDisplayText','EndTextCommandDisplayText','AddTextComponentSubstringPlayerName'}) do _G[name]=function() end end
    print = function(line) logs[#logs+1]=line end
    dofile(root .. 'client.lua')
    if not scenario.alive then handlers['tarrant_medical:client:state']({remaining=0,pending=false}) end
end
local function tick(index)
    local ok, err=coroutine.resume(threads[index]) assert(ok,err)
end
local function begin() pressed=true tick(2) tick(3) end
local function finish(index)
    local steps = 0
    while coroutine.status(threads[index])~='dead' do
        now=now+50 tick(index) steps=steps+1
        assert(steps<=170, 'all candidates must share one bounded eight-second attempt')
    end
end
local function unchanged()
    assert(moves==0 and resurrects==0 and health==0 and position.x==1000,
        'unvalidated destination must never move or resurrect the dead player')
end
local originalPrint = print
reset({sceneAfter=200, transientGround=true}) begin() unchanged()
now=200 tick(3) unchanged()
assert(coroutine.status(threads[3])~='dead', 'wrong early ground must not end the loading window')
now=250 tick(3) now=300 tick(3)
assert(resurrects==1 and moves==0 and position.x==target.x+12 and position.y==target.y
    and position.z==h.z+1.0 and health==200 and collisionEnabled and not focus and not scene and not frozen and not faded)

for _,case in ipairs({
    {noGround=true, reason='ground_not_found'},
    {wrongGround=true, reason='ground_collision_unavailable'},
    {noCollision=true, reason='ground_collision_unavailable'},
    {rayStatus=1, reason='ground_collision_unavailable'},
    {wrongRayHeight=true, reason='ground_collision_unavailable'},
    {steep=true, reason='surface_too_steep'},
    {vehicle=true, reason='vehicle_at_spawn'},
    {sceneAfter=9000, reason='scene_not_loaded'},
}) do
    reset(case) begin() unchanged()
    now=8001 tick(3) unchanged()
    assert(not focus and not scene and not frozen and not faded, 'failure must release streaming/freeze and explain the rejected check')
    assert(logs[1]:find('mode=hospital') and logs[#logs]:find(case.reason, 1, true) and logs[#logs]:find('target=') and logs[#logs]:find('ground=') and logs[#logs]:find('elapsed='))
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

-- The live hospital mismatch must expose an independent ray without accepting
-- either the configured height or the underground ground result as a fallback.
reset({groundZ=16.756881713867, rayZ=h.z}) begin() now=8001 tick(3) unchanged()
assert(rayCalls>0 and logs[#logs]:find('ground_collision_unavailable') and logs[#logs]:find('rayZ=43.28'))

-- Revalidate after the final yield: a formerly valid surface cannot authorize
-- placement after a vehicle arrives, collision disappears or the scene unloads.
for _,change in ipairs({{vehicle=true}, {noGround=true}, {noCollision=true}, {sceneAfter=9000}}) do
    reset() begin() unchanged()
    scenario=change now=50 tick(3) now=8001 tick(3) unchanged()
    assert(not focus and not scene and not faded)
end
reset() begin() PlayerPedId=function() return 2 end now=50 tick(3) unchanged()
assert(not focus and not scene and not faded and logs[#logs]:find('ped_moved_or_frozen'))

local function observerUnchanged()
    assert(health==200 and position.x==1000 and position.y==1000 and position.z==50)
    assert(moves==0 and resurrects==0 and requests==0 and not frozen and not faded)
    assert(TarrantMedical.hospital==h and h.x==300.8 and h.z==43.28, 'survey cannot install a destination')
end
reset({alive=true}) commands.medical_survey_hospital(0, {}) tick(3)
observerUnchanged() assert(scene and focus)
handlers['tarrant_medical:client:state'](false) -- periodic status must not cancel an alive survey
commands.medical_survey_hospital(0, {}) assert(#threads==3, 'duplicate survey must not acquire another scene')
handlers['tarrant_medical:client:recoverHere']() assert(#threads==3)
now=50 tick(3) observerUnchanged()
assert(not scene and not focus and logs[#logs]:find('remoteGeometryValid=true'))
assert(focusTarget.x==h.x and focusTarget.y==h.y and focusTarget.z==h.z)

-- Explicit test coordinates are only a diagnostic target, never recovery config.
reset({alive=true, groundZ=50})
commands.medical_survey_hospital(0, {'100','200','50','90'}) tick(3) now=50 tick(3)
observerUnchanged() assert(focusTarget.x==100 and focusTarget.y==200 and focusTarget.z==50)
assert(logs[1]:find('target=100.0000,200.0000,50.0000') and logs[1]:find('remoteGeometryValid=true'))
for _,args in ipairs({{'1'}, {'1','2','bad','4'}, {'1','2','1e999','4'}}) do
    reset({alive=true}) commands.medical_survey_hospital(0,args)
    observerUnchanged() assert(#threads==2 and not scene and not focus)
end
for _,case in ipairs({
    {wrongGround=true}, {noGround=true}, {noCollision=true}, {steep=true},
    {vehicle=true}, {busy=true}, {startFailed=true}, {frozen=true}, {inVehicle=true},
}) do
    case.alive=true reset(case) commands.medical_survey_hospital(0,{}) tick(3)
    if coroutine.status(threads[3])~='dead' then now=8001 tick(3) end
    observerUnchanged() assert(not scene and not focus and logs[#logs]:find('remoteGeometryValid=false'))
end
for _,event in ipairs({'onClientResourceStop','QBCore:Client:OnPlayerUnload'}) do
    reset({alive=true, noGround=true}) commands.medical_survey_hospital(0,{}) tick(3)
    handlers[event]('tarrant_medical') now=50 tick(3)
    observerUnchanged() assert(not scene and not focus)
end
reset({alive=true}) commands.medical_survey_hospital(0,{}) tick(3)
health=0 now=50 tick(3) unchanged()
assert(not scene and not focus and logs[#logs]:find('remoteGeometryValid=false'))
reset() commands.medical_survey_hospital(0,{}) unchanged()
assert(#threads==2, 'dead players cannot start an observer survey')

-- Hospital discovery: center is a volume anchor, never a hardcoded spawn Z.
-- This synthetic ground height deliberately differs by far more than 2 m.
reset({groundZ=31.25}) begin() unchanged() finish(3)
assert(resurrects==1 and position.x==h.x and position.y==h.y and position.z==32.25)
assert(collisionEnabled and not frozen and not faded and not focus and not scene)
assert(logs[#logs]:find('accepted: index=1'))
for _,case in ipairs({{firstInvalid=true}, {firstObstructed=true}}) do
    reset(case) begin() unchanged() finish(3)
    assert(resurrects==1 and position.x==h.x+12 and position.y==h.y and position.z==h.z+1)
    assert(logs[#logs]:find('accepted: index=2') and collisionEnabled)
end
-- A candidate becoming blocked at the last yield falls through to the next.
reset() begin() scenario.firstVehicle=true finish(3)
assert(resurrects==1 and position.x==h.x+12 and logs[#logs]:find('accepted: index=2'))
reset() begin() now=300 tick(3) unchanged()
finish(3)
assert(resurrects==1 and position.x==h.x+12, 'a capsule result received after its deadline cannot authorize candidate one')

for _,case in ipairs({
    {noGround=true, reason='ground_not_found'},
    {noCollision=true, reason='ground_collision_unavailable'},
    {steep=true, reason='surface_too_steep'},
    {obstruction=true, reason='body_clearance_unavailable'},
    {capsuleStatus=1, reason='body_clearance_unavailable'},
    {capsuleStatus=0, reason='body_clearance_unavailable'},
    {ledge=true, reason='unsafe_footprint'},
    {noPavement=true, reason='pavement_unavailable'}, -- roofs/interiors/water/isolated polygons excluded by flags
    {snapX=100, reason='pavement_outside_search'},
    {navZ=h.z+5, reason='navmesh_ground_mismatch'},
    {groundZ=h.z-60, reason='outside_probe_volume'},
    {groundZ=h.z+60, reason='outside_probe_volume'},
    {groundZ=17, rayZ=43, reason='ground_collision_unavailable'}, -- covered/underground surface
}) do
    reset(case) begin() unchanged() finish(3) unchanged()
    assert(not collisionEnabled and not focus and not scene and not frozen and not faded)
    assert(logs[#logs]:find(case.reason,1,true), case.reason)
    local visited = {}
    for _,line in ipairs(logs) do
        local index = line:match('candidate rejected: index=(%d+)')
        if index then visited[tonumber(index)]=true end
    end
    for i=1,#TarrantMedical.hospitalSearch.offsets do assert(visited[i], 'must try all bounded seeds') end
    -- After the server lease permits E again, a new search can succeed.
    scenario={} handlers['tarrant_medical:client:state']({remaining=0,pending=false})
    pressed=true tick(2) tick(4) finish(4)
    assert(resurrects==1 and collisionEnabled and position.x==h.x)
end
reset({collisionDisabled=true}) begin() unchanged()
assert(not focus and not scene and not faded and not collisionEnabled, 'do not take over NoClip collision state')
reset() begin() scenario.collisionDisabled=true finish(3) unchanged()
assert(not focus and not scene and not faded and not collisionEnabled)

-- Death history survives server confirmation so arbitrarily late death packets
-- cannot re-kill or restart a finished external revive. Unload still resets it.
reset({noGround=true}) begin() health=200 finish(3)
handlers['tarrant_medical:client:state'](false)
handlers['tarrant_medical:client:state']({remaining=15,pending=false})
assert(health==200 and resurrects==0 and position.x==1000)
handlers['QBCore:Client:OnPlayerUnload']()
handlers['QBCore:Client:OnPlayerLoaded']()
handlers['tarrant_medical:client:state']({remaining=15,pending=false})
assert(health==0, 'a fresh character load must still enforce persisted death')
print=originalPrint
print('PASS: hospital first/fallback candidates, measured Z, pavement/ground/ray/slope/footprint/body rejection, bounded exhaustion/retry, lifecycle, collision and stale external-revive packets')
