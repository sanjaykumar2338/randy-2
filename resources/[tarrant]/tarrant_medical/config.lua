TarrantMedical = {
    recoverySeconds = 30,
    requestTimeout = 20,
    -- Streaming reference / server arrival envelope only. Recovery uses the
    -- evidence-backed candidate list below, never this point as a fallback.
    hospital = { x = 300.8, y = -585.6, z = 43.28, heading = 70.0 },
    hospitalSearch = {
        radius = 50.0, -- covers all four destinations for server recovery needs
        verticalRange = 50.0, -- streaming / arrival classification only
        -- Actual XY/floor hints from live F8 evidence, not certified spawns.
        -- Each destination must pass local physical validation before use.
        candidates = {
            { name='south_pavement', x=296.1680, y=-609.3672, z=42.357627868652, heading=70.0 },
            { name='north_exterior', x=297.5000, y=-549.5000, z=42.2188, heading=70.0 },
            { name='west_exterior', x=262.2500, y=-582.7500, z=42.3438, heading=70.0 },
            { name='northeast_exterior', x=329.5000, y=-551.5000, z=42.7812, heading=70.0 },
        },
    },
    collisionTimeoutMs = 8000,
}
