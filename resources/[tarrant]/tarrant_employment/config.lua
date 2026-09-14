TarrantEmployment = {
    center = vec3(195.0, -933.0, 30.7),
    secondsPerStop = 12,
    routeLifetime = 1800,
    -- Small on-foot assignments; no vehicle spawning or deposits in this baseline.
    jobs = {
        garbage = { label = 'Sanitation - litter collection', action = 'Collect litter', pay = 90,
            stops = { vec3(163.5, -1005.7, 29.4), vec3(113.6, -1038.5, 29.3) } },
        trucker = { label = 'Delivery - local parcels', action = 'Deliver parcel', pay = 90,
            stops = { vec3(120.8, -926.0, 29.8), vec3(24.5, -1346.3, 29.5) } },
        bus = { label = 'Transit - stop inspection', action = 'Inspect bus stop', pay = 90,
            stops = { vec3(115.3, -784.1, 31.4), vec3(141.8, -1028.4, 29.4) } }
    }
}
