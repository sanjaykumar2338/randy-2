-- Run from repository root: lua tests/check-tarrant-world.lua
local root = 'resources/[tarrant]/tarrant_world/'
local scripts
fx_version = function(v) assert(v == 'cerulean') end
game = function(v) assert(v == 'gta5') end
name = function(v) assert(v == 'tarrant_world') end
description = function(v) assert(#v > 0) end
version = function(v) assert(v == '0.1.0') end
client_scripts = function(v) scripts = v end
assert(loadfile(root .. 'fxmanifest.lua'))()
assert(#scripts == 2)
for _, path in ipairs(scripts) do assert(loadfile(root .. path)) end
dofile(root .. scripts[1])
local config = TarrantWorld
assert(config.branding_mode == 'fictional')
assert(config.draw_distance > config.label_distance and config.label_distance > 0)
assert(#config.locations == 7)
local ids, coordinates = {}, {}
local categories = {police=true, hospital=true, civic=true, fire=true, stadium=true, commercial=true}
local function validMarker(override)
    local m = {}
    for k,v in pairs(config.marker) do m[k] = v end
    for k,v in pairs(override or {}) do m[k] = v end
    assert(type(m.enabled) == 'boolean' and type(m.ground) == 'boolean')
    assert(type(m.type) == 'number' and m.type % 1 == 0 and m.type >= 0 and m.type <= 43)
    assert(type(m.zOffset) == 'number' and m.zOffset == m.zOffset and math.abs(m.zOffset) < 10)
    for _,axis in ipairs({'x','y','z'}) do
        assert(type(m.scale[axis]) == 'number' and m.scale[axis] > 0 and m.scale[axis] <= 5)
    end
end
validMarker()
-- Five live-accepted core sites and unchanged Prairie; Burger Shot / Vespucci selected provisionally.
-- Presentation changes must preserve these logical coordinates and blips.
local baseline = {
    {434.7,-981.9,30.7,60,3,0.8}, {298.6,-584.4,43.3,61,2,0.8},
    {195,-933,30.7,419,5,0.8}, {200.1,-1634.3,29.8,436,1,0.8},
    {-250.5,-2030,30.1,541,38,0.9}, {-1174.1512,-881.3021,14.0166,1,0,0.7}, {100,-1400,29,1,0,0.7}
}
local active = 0
for index, l in ipairs(config.locations) do
    for _, key in ipairs({'id', 'display_name', 'real_name', 'zone', 'category',
        'gta_base', 'rp_purpose', 'interior_requirement', 'stage', 'survey_status'}) do
        assert(type(l[key]) == 'string' and #l[key] > 0, key)
    end
    validMarker(l.marker)
    local b = baseline[index]
    assert(l.coords.x == b[1] and l.coords.y == b[2] and l.coords.z == b[3])
    assert(l.blip.enabled and l.blip.sprite == b[4] and l.blip.colour == b[5] and l.blip.scale == b[6])
    assert(not ids[l.id], 'duplicate ID')
    ids[l.id] = true
    assert(categories[l.category], 'invalid category')
    assert(type(l.enabled) == 'boolean')
    assert(l.branding_mode == nil or l.branding_mode == 'fictional' or l.branding_mode == 'real')
    if l.enabled then active = active + 1 end
    if index <= 5 then
        assert(l.enabled == true and l.stage == 'identity_only' and l.branding_mode == nil)
    else
        assert(l.enabled == true and l.stage == 'provisional_dev_test')
        assert(l.branding_mode == 'fictional' and l.display_name ~= l.real_name)
        assert(l.category == 'commercial' and l.subcategory == 'restaurant' and l.identity_group == 'texas_staples')
        assert(l.survey_status == 'manual_required' and l.blip.enabled)
        for _, key in ipairs({'asset_requirement', 'notes'}) do
            assert(type(l[key]) == 'string' and #l[key] > 0, key)
        end
        assert(l.notes:find('PROVISIONAL - MANUAL GAME SURVEY REQUIRED', 1, true))
    end
    for _, key in ipairs({'x', 'y', 'z'}) do
        local value = l.coords[key]
        assert(type(value) == 'number' and value == value and math.abs(value) < 10000)
    end
    local coordinateKey = string.format('%g,%g,%g', l.coords.x, l.coords.y, l.coords.z)
    assert(not coordinates[coordinateKey], 'duplicate coordinates')
    coordinates[coordinateKey] = true
    assert(type(l.blip.enabled) == 'boolean')
    assert(l.blip.sprite > 0 and l.blip.sprite % 1 == 0)
    assert(l.blip.colour >= 0 and l.blip.colour % 1 == 0)
    assert(l.blip.scale > 0 and l.blip.scale <= 2)
end
assert(active == 7 and ids.whataburger and ids.dairy_queen)
for _, id in ipairs({'arlington_pd', 'arlington_memorial', 'arlington_city_hall',
    'arlington_fire_1', 'arlington_stadium'}) do assert(ids[id]) end

-- Exercise lifecycle/branding/proximity against isolated native stubs.
local function run(mode, disableFirst, restaurantMode, shipped, hideBlip)
    config.branding_mode = mode
    config.locations[1].enabled = not disableFirst
    local restaurant = config.locations[6]
    restaurant.enabled = shipped or restaurantMode ~= nil
    config.locations[7].enabled = shipped or false
    restaurant.blip.enabled = restaurant.enabled and not hideBlip
    restaurant.branding_mode = restaurantMode or 'fictional'
    local created, removed, labels, handlers = {}, {}, {}, {}
    local thread, markers, textFrames = nil, 0, 0
    local position = {x = 8000, y = 8000, z = 0}
    AddBlipForCoord = function(x, y, z)
        created[#created + 1] = {x, y, z}; return #created
    end
    for _, key in ipairs({'SetBlipSprite','SetBlipColour','SetBlipScale',
        'SetBlipAsShortRange','BeginTextCommandSetBlipName','EndTextCommandSetBlipName',
        'SetTextFont','SetTextScale','SetTextColour','SetTextCentre','SetTextOutline',
        'BeginTextCommandDisplayText'}) do _G[key] = function() end end
    AddTextComponentSubstringPlayerName = function(value) labels[#labels + 1] = value end
    CreateThread = function(fn) thread = coroutine.create(fn) end
    AddEventHandler = function(event, fn) handlers[event] = fn end
    GetCurrentResourceName = function() return 'tarrant_world' end
    RemoveBlip = function(id) assert(not removed[id]); removed[id] = true end
    PlayerPedId = function() return 1 end
    GetEntityCoords = function() return position end
    GetGameTimer = function() return 1000 end
    GetGroundZFor_3dCoord = function(x,y,z,water)
        assert(not water)
        return true, z - 1.5 -- Simulated surface one metre below logical Z.
    end
    DrawMarker = function(kind,x,y,z,dx,dy,dz,rx,ry,rz,sx,sy,sz)
        assert(kind == 23 and sx == 0.5 and sy == 0.5 and sz == 0.1)
        assert(math.abs(z - (position.z - 1 + 0.05)) < 0.00001)
        markers = markers + 1
    end
    EndTextCommandDisplayText = function() textFrames = textFrames + 1 end
    Wait = coroutine.yield
    dofile(root .. scripts[2])
    local coreCount = disableFirst and 4 or 5
    assert(#created == coreCount + ((restaurant.enabled and not hideBlip) and 1 or 0) + (shipped and 1 or 0))
    assert(labels[coreCount] == (mode == 'real' and 'AT&T Stadium' or 'Arlington Stadium'))
    if restaurantMode and not shipped and not hideBlip then
        assert(labels[#created] == (restaurantMode == 'real' and restaurant.real_name or restaurant.display_name))
    end
    local ok, delay = coroutine.resume(thread)
    assert(ok and delay == 750 and markers == 0 and textFrames == 0)
    position = config.locations[2].coords
    ok, delay = coroutine.resume(thread)
    assert(ok and delay == 0 and markers == 1 and textFrames == 1)
    for i = 6, 7 do
        position = config.locations[i].coords
        local beforeMarkers, beforeFrames = markers, textFrames
        ok, delay = coroutine.resume(thread)
        local visible = config.locations[i].enabled
        assert(ok and delay == (visible and 0 or 750))
        assert(markers == beforeMarkers + (visible and 1 or 0))
        assert(textFrames == beforeFrames + (visible and 1 or 0))
        if visible then
            local site = config.locations[i]
            local expectedName = site.branding_mode == 'real' and site.real_name or site.display_name
            assert(labels[#labels - 1] == expectedName .. '~n~' .. site.zone)
        end
    end
    handlers.onClientResourceStop('another_resource')
    assert(next(removed) == nil)
    handlers.onClientResourceStop('tarrant_world')
    handlers.onClientResourceStop('tarrant_world') -- Cleanup is idempotent.
    for i = 1, #created do assert(removed[i]) end
end
run('fictional', false, nil, true) -- Shipped seven-site configuration.
run('fictional', false, 'fictional', false, true) -- Marker independent of blip.
run('fictional', false)
run('real', false)
run('fictional', true)
run('real', false, 'fictional') -- Per-site fictional mode survives global real mode.
run('fictional', false, 'real') -- Explicit site naming override, development only.
-- Presentation overrides and ground-query failure/retry are independent of labels/blips.
local site = config.locations[2]
for _,l in ipairs(config.locations) do l.enabled = l == site end
local function presentation(override, found, surface, laterSurface)
    site.marker = override
    validMarker(override)
    local thread, draws, queries, frames, now, blips = nil, {}, 0, 0, 0, 0
    CreateThread = function(fn) thread = coroutine.create(fn) end
    GetEntityCoords = function() return site.coords end
    GetGameTimer = function() return now end
    GetGroundZFor_3dCoord = function(x,y,z,water)
        queries = queries + 1
        assert(x == site.coords.x and y == site.coords.y and z == site.coords.z + 0.5 and not water)
        if laterSurface and queries >= 2 then return true, laterSurface end
        return found, surface
    end
    DrawMarker = function(...) draws[#draws+1] = {...} end
    EndTextCommandDisplayText = function() frames = frames + 1 end
    AddBlipForCoord = function(x,y,z)
        assert(x == site.coords.x and y == site.coords.y and z == site.coords.z)
        blips = blips + 1
        return blips
    end
    dofile(root .. scripts[2])
    for _,time in ipairs({0, 16, 1000}) do
        now = time
        local ok,delay = coroutine.resume(thread)
        assert(ok and delay == 0) -- Label draws independently of ground success.
    end
    assert(frames == 3 and blips == 1)
    return draws,queries
end
local draws,queries = presentation({enabled=false}, true, site.coords.z-1)
assert(#draws == 0 and queries == 0)
draws,queries = presentation({type=1,scale={x=0.4,y=0.6,z=0.2},zOffset=0.1,ground=false}, false, 0)
assert(#draws == 3 and queries == 0)
assert(draws[1][1] == 1 and draws[1][4] == site.coords.z+0.1)
assert(draws[1][11] == 0.4 and draws[1][12] == 0.6 and draws[1][13] == 0.2)
for _,surface in ipairs({site.coords.z-10, math.huge, 0/0}) do
    draws,queries = presentation({}, true, surface)
    assert(#draws == 3 and queries == 2)
    assert(draws[1][4] == site.coords.z + config.marker.zOffset)
end
draws,queries = presentation({}, false, 0)
assert(#draws == 3 and queries == 2)
assert(draws[1][4] == site.coords.z + config.marker.zOffset)
draws,queries = presentation({}, true, site.coords.z-1)
assert(#draws == 3 and queries == 2)
site.marker = nil
-- APD/Hospital: initial failure remains visible and later success replaces fallback.
for _,index in ipairs({1,2,3}) do
    site = config.locations[index]
    for _,l in ipairs(config.locations) do l.enabled = l == site end
    draws,queries = presentation({}, false, 0, site.coords.z-1)
    assert(#draws == 3 and queries == 2)
    assert(draws[1][4] == site.coords.z + config.marker.zOffset)
    assert(draws[2][4] == draws[1][4]) -- No per-frame lookup.
    assert(draws[3][4] == site.coords.z-1 + config.marker.zOffset)
    -- City Hall known-good success retains type, scale, alignment and label behavior.
    draws,queries = presentation({}, true, site.coords.z-1)
    assert(#draws == 3 and queries == 2)
    for _,draw in ipairs(draws) do
        assert(draw[1] == 23 and draw[4] == site.coords.z-1 + 0.05)
        assert(draw[11] == 0.5 and draw[12] == 0.5 and draw[13] == 0.1)
    end
    site.marker = nil
end
-- An entirely disabled registry does not retain an idle proximity loop.
for _, site in ipairs(config.locations) do site.enabled = false end
CreateThread = function(fn)
    local thread = coroutine.create(fn)
    assert(coroutine.resume(thread))
    assert(coroutine.status(thread) == 'dead')
end
AddBlipForCoord = function() error('disabled registry created a blip') end
dofile(root .. scripts[2])
print('tarrant_world: manifest, syntax, registry, branding, disable, proximity and cleanup PASS')
