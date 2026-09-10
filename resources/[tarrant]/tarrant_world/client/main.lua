local config = TarrantWorld
local blips, locations, markers = {}, {}, {}

local function nameFor(location)
    local mode = location.branding_mode or config.branding_mode
    return mode == 'real' and location.real_name or location.display_name
end

for _, location in ipairs(config.locations) do
    if location.enabled then
        locations[#locations + 1] = location
        local style = {}
        for key, value in pairs(config.marker) do style[key] = value end
        for key, value in pairs(location.marker or {}) do style[key] = value end
        markers[location.id] = { style = style }
        if location.blip.enabled then
            local c, style = location.coords, location.blip
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            blips[#blips + 1] = blip
            SetBlipSprite(blip, style.sprite)
            SetBlipColour(blip, style.colour)
            SetBlipScale(blip, style.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(nameFor(location))
            EndTextCommandSetBlipName(blip)
        end
    end
end

-- One proximity loop; no entities, server events, database access or shared UI ownership.
CreateThread(function()
    while #locations > 0 do
        local sleep = 750
        local pos = GetEntityCoords(PlayerPedId())
        local nearest, nearestDistance = nil, config.label_distance * config.label_distance
        for _, location in ipairs(locations) do
            local c = location.coords
            local distance = (pos.x - c.x)^2 + (pos.y - c.y)^2 + (pos.z - c.z)^2
            if distance < config.draw_distance * config.draw_distance then
                local marker = markers[location.id]
                local style = marker.style
                if style.enabled then
                    local z = c.z
                    if style.ground then
                        local now = GetGameTimer()
                        -- Bounded local query, once per second; never force collision streaming.
                        if not marker.checkedAt or now - marker.checkedAt >= 1000 or now < marker.checkedAt then
                            marker.checkedAt = now
                            local found, ground = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
                            marker.groundZ = found and type(ground) == 'number'
                                and math.abs(ground - c.z) <= 2.0 and ground or nil
                        end
                        z = marker.groundZ or c.z
                    end
                    -- Until a valid surface is available, draw at logical Z + configured offset.
                    -- The next throttled query can replace this temporary visual fallback.
                    if z then
                        sleep = 0
                        local scale = style.scale
                        DrawMarker(style.type, c.x, c.y, z + style.zOffset, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, scale.x, scale.y, scale.z, 80, 170, 230, 150,
                            false, false, 2, false, nil, nil, false)
                    end
                end
                if distance < nearestDistance then
                    nearest, nearestDistance = location, distance
                end
            end
        end
        if nearest then
            sleep = 0
            -- Frame-local label disappears automatically on stop or leaving the point.
            SetTextFont(0)
            SetTextScale(0.0, 0.32)
            SetTextColour(255, 255, 255, 230)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(nameFor(nearest) .. '~n~' .. nearest.zone)
            AddTextComponentSubstringPlayerName('~n~' .. nearest.rp_purpose)
            EndTextCommandDisplayText(0.5, 0.78)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    blips = {}
end)
