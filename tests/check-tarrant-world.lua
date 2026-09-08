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
assert(#config.locations == 5)
local ids = {}
for _, l in ipairs(config.locations) do
    for _, key in ipairs({'id', 'display_name', 'real_name', 'zone', 'category',
        'gta_base', 'rp_purpose', 'interior_requirement', 'stage', 'survey_status'}) do
        assert(type(l[key]) == 'string' and #l[key] > 0, key)
    end
    assert(not ids[l.id], 'duplicate ID')
    ids[l.id] = true
    assert(l.enabled == true and l.stage == 'identity_only')
    for _, key in ipairs({'x', 'y', 'z'}) do
        local value = l.coords[key]
        assert(type(value) == 'number' and value == value and math.abs(value) < 10000)
    end
    assert(l.blip.enabled == true)
    assert(l.blip.sprite > 0 and l.blip.sprite % 1 == 0)
    assert(l.blip.colour >= 0 and l.blip.colour % 1 == 0)
    assert(l.blip.scale > 0 and l.blip.scale <= 2)
end
for _, id in ipairs({'arlington_pd', 'arlington_memorial', 'arlington_city_hall',
    'arlington_fire_1', 'arlington_stadium'}) do assert(ids[id]) end

-- Exercise lifecycle/branding/proximity against isolated native stubs.
local function run(mode, disableFirst)
    config.branding_mode = mode
    config.locations[1].enabled = not disableFirst
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
    assert(#created == (disableFirst and 4 or 5))
    assert(labels[#created] == (mode == 'real' and 'AT&T Stadium' or 'Arlington Stadium'))
    local ok, delay = coroutine.resume(thread)
    assert(ok and delay == 750 and markers == 0 and textFrames == 0)
    position = config.locations[2].coords
    ok, delay = coroutine.resume(thread)
    assert(ok and delay == 0 and markers == 1 and textFrames == 1)
    handlers.onClientResourceStop('another_resource')
    assert(next(removed) == nil)
    handlers.onClientResourceStop('tarrant_world')
    for i = 1, #created do assert(removed[i]) end
end
run('fictional', false)
run('real', false)
run('fictional', true)
print('tarrant_world: manifest, syntax, registry, branding, disable, proximity and cleanup PASS')
