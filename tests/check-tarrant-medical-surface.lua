-- Test actual production client code with physical native fixtures. Configured
-- points/floor hints are not accepted by the harness without production checks.
local root='resources/[tarrant]/tarrant_medical/'
dofile(root..'config.lua')
local candidates=TarrantMedical.hospitalSearch.candidates
assert(#candidates==4)
local originalPrint=print
local scenario, threads, handlers, commands, logs, now, health, position, pressed
local scene, focus, faded, frozen, resurrects, collisionWrites, unfreezes, requests
local probes, collisionRequests, upwardQueries, legacyCalls
local function at(x,y)
    for i,c in ipairs(candidates) do
        if (x-c.x)^2+(y-c.y)^2<1 then return (scenario.points or {})[i] or scenario, c.z, i end
    end
    return scenario, 50, 0
end
local function floor(x,y)
    local s,z=at(x,y)
    return s.ground or z+(s.delta or 0)
end
local function reset(options)
    scenario=options or {}
    threads,handlers,commands,logs,probes,collisionRequests={},{},{},{},{},{}
    now,health,position,pressed=0,scenario.alive and 200 or 0,{x=1000,y=1000,z=50},false
    scene,focus,faded,frozen=false,false,false,false
    resurrects,collisionWrites,unfreezes,requests,upwardQueries,legacyCalls=0,0,0,0,0,0
    LocalPlayer={state={isLoggedIn=true}} source=65535
    PlayerPedId=function() return 1 end
    PlayerId=function() return 1 end
    GetGameTimer=function() return now end
    IsEntityDead=function() return health<=100 end
    GetEntityCoords=function() return position end
    GetEntityHeading=function() return 70 end
    IsEntityPositionFrozen=function() return scenario.frozen or frozen end
    IsPedInAnyVehicle=function() return scenario.inVehicle or false end
    GetEntityCollisionDisabled=function() return scenario.noPedCollision or false end
    GetEntityMaxHealth=function() return 200 end
    SetEntityHealth=function(_,hp) health=hp end
    GetCurrentResourceName=function() return 'tarrant_medical' end
    CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
    Wait=function() coroutine.yield() end
    RegisterNetEvent=function(name,fn) handlers[name]=fn end
    AddEventHandler=RegisterNetEvent
    RegisterCommand=function(name,fn) commands[name]=fn end
    TriggerEvent=function() end
    exports={ox_inventory={closeInventory=function() end}}
    lib={callback={await=function() requests=requests+1 return true end}}
    DoScreenFadeOut=function() faded=true end
    DoScreenFadeIn=function() faded=false end
    IsNewLoadSceneActive=function() return scenario.busy or scene end
    SetFocusPosAndVel=function() focus=true end
    ClearFocus=function() focus=false end
    NewLoadSceneStartSphere=function() scene=not scenario.startFailed return scene end
    NewLoadSceneStop=function() assert(scene) scene=false end
    IsNewLoadSceneLoaded=function() return now>=(scenario.sceneAfter or 0) end
    RequestCollisionAtCoord=function(x,y,z) collisionRequests[#collisionRequests+1]={x=x,y=y,z=z} end
    HasCollisionLoadedAroundEntity=function() return true end -- Origin collision proves nothing about the target.
    SetEntityCoordsNoOffset=function() error('never teleport to test a destination') end
    GetGroundZFor_3dCoord=function(x,y,z)
        local s=at(x,y)
        if s.noGround or now<(s.groundAfter or 0) then return false,0 end
        local g=floor(x,y)
        if s.ceiling and z>=g+s.ceiling then return true,g+s.ceiling end
        return true,g
    end
    -- Exact live road outputs are deliberately hostile to the old rules. The
    -- production path must never consult these unrelated points/classifications.
    GetClosestVehicleNode=function()
        legacyCalls=legacyCalls+1
        local r=scenario.legacyRoad or {x=299.25,y=-647,z=28.3125,flags=0}
        return true,r
    end
    GetVehicleNodeProperties=function()
        legacyCalls=legacyCalls+1 return true,1,(scenario.legacyRoad or {}).flags or 64
    end
    GetSafeCoordForPed=function() error('authored candidates must not depend on navmesh lookup') end
    StartExpensiveSynchronousShapeTestLosProbe=function(x,y,top,_,_,bottom)
        probes[#probes+1]={kind='ray',x=x,y=y,top=top,bottom=bottom}
        if top<bottom then upwardQueries=upwardQueries+1 end
        return #probes
    end
    StartShapeTestCapsule=function(x,y,z,_,_,_,radius,mask,_,options)
        assert(radius==0.45 and mask==511 and options==4)
        probes[#probes+1]={kind='body',x=x,y=y,z=z}
        return #probes
    end
    GetShapeTestResult=function(handle)
        local p=assert(probes[handle]) local s=at(p.x,p.y) local g=floor(p.x,p.y)
        if p.kind=='body' then
            return s.capsuleStatus or 2, s.obstruction or (s.ceiling and s.ceiling<=2.05) or false
        end
        if p.top<p.bottom then return 2,true,{z=g+(s.ceiling or 6)},{z=-1} end
        local edge=p.top-p.bottom<2
        local z=g+(s.rayDelta or 0)
        if s.ceiling and p.top>=g+s.ceiling and p.bottom<g+s.ceiling then z=g+s.ceiling end
        return s.rayStatus or 2, not s.noCollision and not (edge and s.ledge),
            {x=p.x,y=p.y,z=z},{z=s.steep and 0.4 or 1},0
    end
    IsAnyVehicleNearPoint=function(x,y) return at(x,y).vehicle or false end
    NetworkResurrectLocalPlayer=function(x,y,z,heading)
        assert(heading==70 and health==0)
        resurrects=resurrects+1 health=200 position={x=x,y=y,z=z} frozen=true
    end
    SetEntityCollision=function(_,value)
        assert(resurrects==1 and value, 'collision write only after validated placement') collisionWrites=collisionWrites+1
    end
    FreezeEntityPosition=function(_,value)
        assert(resurrects==1 and not value, 'never release foreign freeze on failure') frozen=false unfreezes=unfreezes+1
    end
    IsControlJustReleased=function() local value=pressed pressed=false return value end
    for _,name in ipairs({'SetEntityVelocity','SetPlayerControl','ClearPedTasksImmediately','ClearPedBloodDamage',
        'RestorePlayerStamina','SetGameplayCamRelativeHeading','SetGameplayCamRelativePitch','SetTextFont',
        'SetTextScale','SetTextCentre','SetTextColour','SetTextOutline','BeginTextCommandDisplayText',
        'EndTextCommandDisplayText','AddTextComponentSubstringPlayerName'}) do _G[name]=function() end end
    print=function(line) logs[#logs+1]=line end
    dofile(root..'client.lua')
    if not scenario.alive then handlers['tarrant_medical:client:state']({remaining=0,pending=false}) end
end
local function tick(index) local ok,err=coroutine.resume(threads[index]) assert(ok,err) end
local function begin() pressed=true tick(2) tick(3) end
local function finish(index)
    local steps=0
    while coroutine.status(threads[index])~='dead' do
        now=now+50 tick(index) steps=steps+1 assert(steps<=170,'one shared eight-second deadline')
    end
end
local function unmoved(alive)
    assert(resurrects==0 and health==(alive and 200 or 0) and position.x==1000 and position.y==1000 and position.z==50)
    assert(collisionWrites==0 and unfreezes==0)
end
local function clean() assert(not scene and not focus and not faded and not frozen) end
local function landed(index,delta)
    local c=candidates[index]
    assert(resurrects==1 and health==200 and position.x==c.x and position.y==c.y and position.z==c.z+(delta or 0)+1)
    assert(collisionWrites==1 and unfreezes==1 and legacyCalls==0 and upwardQueries==0) clean()
end

reset({delta=0.25}) begin() unmoved() assert(#collisionRequests>=#candidates)
pressed=true tick(2) assert(requests==1) finish(3) landed(1,0.25)
for i=1,#candidates do
    local points={}
    for j=1,i-1 do points[j]={noGround=true} end
    reset({points=points}) begin() unmoved() finish(3) landed(i)
end

-- Exact latest evidence: road flags/distances can no longer veto a physically
-- valid explicit point. The southern 28.3125 road is not adopted as a spawn.
for _,road in ipairs({
    {x=329.5,y=-551.5,z=42.7812,flags=64},
    {x=262.25,y=-582.75,z=42.3438,flags=0},
    {x=297.5,y=-549.5,z=42.2188,flags=0},
    {x=299.25,y=-647,z=28.3125,flags=0},
}) do
    reset({legacyRoad=road,ceiling=6}) begin() finish(3) landed(1)
end
-- A canopy well above the body is safe; low ceilings are physical obstructions.
reset({ceiling=2.3}) begin() finish(3) landed(1)
reset({points={[1]={ceiling=1.8}}}) begin() finish(3) landed(2)

for _,case in ipairs({
    {noGround=true,reason='ground_not_found'},
    {noCollision=true,reason='ground_collision_unavailable'},
    {rayStatus=1,reason='ground_collision_unavailable'},
    {rayDelta=0.26,reason='ground_collision_unavailable'},
    {ground=48.753879547119,reason='floor_height_mismatch'},
    {ground=89.620208740234,reason='floor_height_mismatch'},
    {ground=16.9847,reason='floor_height_mismatch'},
    {steep=true,reason='surface_too_steep'},
    {ledge=true,reason='unsafe_footprint'},
    {vehicle=true,reason='vehicle_at_spawn'},
    {obstruction=true,reason='body_clearance_unavailable'},
    {ceiling=1.8,reason='body_clearance_unavailable'},
    {capsuleStatus=1,reason='body_clearance_unavailable'},
    {capsuleStatus=0,reason='body_clearance_unavailable'},
}) do
    reset(case) begin() unmoved() finish(3) unmoved() clean()
    assert(logs[#logs]:find(case.reason,1,true),case.reason)
    local visited={}
    for _,line in ipairs(logs) do local index=line:match('candidate rejected: index=(%d+)') if index then visited[tonumber(index)]=true end end
    for i=1,#candidates do assert(visited[i],'all explicit candidates must be tried') end
    scenario={} handlers['tarrant_medical:client:state']({remaining=0,pending=false})
    pressed=true tick(2) tick(4) finish(4) landed(1)
end
reset({rayDelta=0.24}) begin() finish(3) landed(1)
reset({sceneAfter=9000}) begin() finish(3) unmoved() clean()
for _,case in ipairs({{busy=true},{startFailed=true},{frozen=true},{inVehicle=true},{noPedCollision=true}}) do
    reset(case) begin() unmoved() clean()
end

-- Delayed loading and unresolved early capsules cannot starve the last fallback.
reset({sceneAfter=7750,points={[1]={capsuleStatus=1},[2]={capsuleStatus=1},[3]={capsuleStatus=1}}})
begin() unmoved() now=7750 tick(3) unmoved() now=7800 tick(3) landed(4)
for _,change in ipairs({{vehicle=true},{noCollision=true},{noGround=true},{obstruction=true},{sceneAfter=9000}}) do
    reset() begin() unmoved() scenario=change finish(3) unmoved() clean()
end
reset() begin() scenario={points={[1]={vehicle=true}}} finish(3) landed(2)
reset() begin() scenario.delta=0.1 now=50 tick(3) unmoved() finish(3) landed(1,0.1)
reset() begin() now=300 tick(3) unmoved() finish(3) landed(1)

for _,event in ipairs({'onClientResourceStop','QBCore:Client:OnPlayerUnload'}) do
    reset({noGround=true}) begin() handlers[event]('tarrant_medical') finish(3) unmoved() clean()
end
reset() begin() PlayerPedId=function() return 2 end finish(3) unmoved() clean()
reset() begin() scenario.frozen=true finish(3) unmoved() clean()
reset() begin() scenario.noPedCollision=true finish(3) unmoved() clean()
reset() begin() health=200 finish(3) unmoved(true) clean()
handlers['tarrant_medical:client:state'](false)
handlers['tarrant_medical:client:state']({remaining=15,pending=false})
unmoved(true)
handlers['QBCore:Client:OnPlayerUnload']() handlers['QBCore:Client:OnPlayerLoaded']()
handlers['tarrant_medical:client:state']({remaining=15,pending=false}) assert(health==0)

-- Console recovery retains its own strict local validator and shared revival.
reset() source=1 handlers['tarrant_medical:client:recoverHere']() assert(#threads==2)
source=65535 handlers['tarrant_medical:client:recoverHere']() tick(3) finish(3)
assert(resurrects==1 and position.x==1000 and position.z==51 and collisionWrites==1 and unfreezes==1) clean()
reset({ground=16.756881713867}) handlers['tarrant_medical:client:recoverHere']() tick(3) finish(3) unmoved() clean()
assert(logs[#logs]:find('ground_z_mismatch'))
reset() handlers['tarrant_medical:client:recoverHere']() tick(3)
position={x=1005,y=1000,z=50} finish(3) assert(resurrects==0 and logs[#logs]:find('ped_moved_or_frozen')) clean()

-- Both survey forms stay read-only, including candidate config when ground
-- differs from its hint. They never authorize recovery or change the list.
local originalZ=candidates[1].z
reset({alive=true,delta=0.25}) commands.medical_survey_hospital(0,{}) tick(3)
handlers['tarrant_medical:client:state'](false)
commands.medical_survey_hospital(0,{}) assert(#threads==3)
finish(3) unmoved(true) clean() assert(requests==0 and candidates[1].z==originalZ)
assert(logs[#logs]:find('remoteGeometryValid=true'))
reset({alive=true}) commands.medical_survey_hospital(0,{'100','200','50','70'}) tick(3) finish(3)
unmoved(true) clean() assert(logs[#logs]:find('remoteGeometryValid=true'))
for _,args in ipairs({{'1'},{'1','2','bad','4'},{'1','2','1e999','4'}}) do
    reset({alive=true}) commands.medical_survey_hospital(0,args) assert(#threads==2) unmoved(true) clean()
end
reset() commands.medical_survey_hospital(0,{}) assert(#threads==2) unmoved()
reset() commands.medical_survey_here() unmoved() clean() assert(logs[1]:find('aliveCandidate=false'))
health=200 commands.medical_survey_here() unmoved(true) assert(logs[2]:find('aliveCandidate=true'))
reset({alive=true,noGround=true}) commands.medical_survey_hospital(0,{}) tick(3)
handlers['QBCore:Client:OnPlayerUnload']() finish(3) unmoved(true) clean()
print=originalPrint
print('PASS: explicit hospital points, exact live road/canopy regressions, measured placement, roof/underground rejection, body/footprint/vehicle checks, fair timeout/retry, lifecycle and read-only diagnostics')
