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
local active = 0
for index, l in ipairs(config.locations) do
    for _, key in ipairs({'id', 'display_name', 'real_name', 'zone', 'category',
        'gta_base', 'rp_purpose', 'interior_requirement', 'stage', 'survey_status'}) do
        assert(type(l[key]) == 'string' and #l[key] > 0, key)
    end
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
    DrawMarker = function() markers = markers + 1 end
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
