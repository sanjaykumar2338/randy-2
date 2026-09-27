-- Destination validation must never use a premature teleport as a streaming aid.
local root = 'resources/[tarrant]/tarrant_medical/'
dofile(root .. 'config.lua')
local h = TarrantMedical.hospital
local now, health, pressed, moves, resurrects, groundCalls
local focus, scene, frozen, faded, logs, threads, handlers, scenario
local position, target
local function reset(options)
    scenario = options or {}
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
    FreezeEntityPosition = function(_, value) frozen=value end
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
        return true,h.z
    end
    StartExpensiveSynchronousShapeTestLosProbe = function() return 1 end
    GetShapeTestResult = function()
        return 2, not scenario.noCollision, {x=target.x,y=target.y,z=h.z-(scenario.wrongRayHeight and 3 or 0)},
            {x=0,y=0,z=scenario.steep and 0.4 or 1}, 0
    end
    IsAnyVehicleNearPoint = function() return scenario.vehicle or false end
    NetworkResurrectLocalPlayer = function(x,y,z,heading)
        assert(heading==h.heading)
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
    assert(not focus and not scene and not frozen and not faded and #logs==1, 'failure must release streaming/freeze and explain the rejected check')
    assert(logs[1]:find(case.reason, 1, true) and logs[1]:find('target=') and logs[1]:find('ground=') and logs[1]:find('elapsed='))
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
print=originalPrint
print('PASS: remote scene/surface validation, transient wrong Z, collision/slope/obstruction rejection, origin preservation, retry and streaming cleanup')
