TarrantMedical = {
    recoverySeconds = 30,
    requestTimeout = 20,
    -- Search center only, NOT a spawn or trusted ground height. No ped is moved
    -- here unless runtime pavement, ground, collision and clearance checks pass.
    hospital = { x = 300.8, y = -585.6, z = 43.28, heading = 70.0 },
    hospitalSearch = {
        radius = 32.0,
        verticalRange = 50.0, -- streaming coverage only; never validates a surface Z
        roadRadius = 64.0, -- road references may lie beyond the pavement search area
        maxRoadDistance = 32.0,
        -- Relative search seeds, NOT claimed-safe coordinates. Actual XY/Z is
        -- discovered on connected exterior pavement, then collision validated.
        offsets = {
            {0,0}, {12,0}, {-12,0}, {0,12}, {0,-12},
            {12,12}, {-12,12}, {12,-12}, {-12,-12},
            {24,0}, {-24,0}, {0,24}, {0,-24},
        },
    },
    collisionTimeoutMs = 8000,
}
