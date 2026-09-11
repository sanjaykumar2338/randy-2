TarrantWorld = {
    branding_mode = 'fictional', -- Change to 'real' only after Randy approves names.
    -- Per-location marker fields override these defaults; scale overrides as a whole.
    -- ground=false uses logical Z + zOffset for a manually surveyed surface.
    marker = { enabled = true, type = 23, scale = { x = 0.5, y = 0.5, z = 0.1 },
        zOffset = 0.05, ground = true },
    draw_distance = 20.0,
    label_distance = 3.0,
    -- display_name is the fictional fallback; optional per-site branding_mode overrides global.
    -- category is broad; optional subcategory/identity_group classify future businesses.
    locations = {
        {
            id = 'arlington_pd', enabled = true,
            display_name = 'Arlington Police Department',
            real_name = 'Arlington Police Department',
            zone = 'Arlington Civic Core', category = 'police',
            gta_base = 'Mission Row Police Station',
            coords = { x = 434.7, y = -981.9, z = 30.7 },
            blip = { enabled = true, sprite = 60, colour = 3, scale = 0.8 },
            rp_purpose = 'Public police meeting and report reference point.',
            interior_requirement = 'Existing interior only; access and jobs unchanged.',
            stage = 'identity_only', survey_status = 'manual_required'
        },
        {
            id = 'arlington_memorial', enabled = true,
            display_name = 'Arlington Memorial Hospital',
            real_name = 'Texas Health Arlington Memorial Hospital',
            zone = 'Arlington Civic Core', category = 'hospital',
            gta_base = 'Pillbox Hill Medical Center',
            coords = { x = 298.6, y = -584.4, z = 43.3 },
            blip = { enabled = true, sprite = 61, colour = 2, scale = 0.8 },
            rp_purpose = 'Hospital arrival and ambulance crew meeting point.',
            interior_requirement = 'Existing interior only; no medical integration.',
            stage = 'identity_only', survey_status = 'manual_required'
        },
        {
            id = 'arlington_city_hall', enabled = true,
            display_name = 'Arlington City Hall', real_name = 'Arlington City Hall',
            zone = 'Arlington Civic Core', category = 'civic',
            gta_base = 'Legion Square civic plaza reference (building survey pending)',
            coords = { x = 195.0, y = -933.0, z = 30.7 },
            blip = { enabled = true, sprite = 419, colour = 5, scale = 0.8 },
            rp_purpose = 'Exterior civic meeting point; arrange public-service RP here.',
            interior_requirement = 'Exterior only; building and counter survey pending.',
            stage = 'identity_only', survey_status = 'manual_required'
        },
        {
            id = 'arlington_fire_1', enabled = true,
            display_name = 'Arlington Fire Station 1', real_name = 'Arlington Fire Station 1',
            zone = 'Arlington South Corridor', category = 'fire',
            gta_base = 'Davis Fire Station',
            coords = { x = 200.1, y = -1634.3, z = 29.8 },
            blip = { enabled = true, sprite = 436, colour = 1, scale = 0.8 },
            rp_purpose = 'Fire crew meeting and station arrival reference point.',
            interior_requirement = 'Existing station only; bays and jobs unchanged.',
            stage = 'identity_only', survey_status = 'manual_required'
        },
        {
            id = 'arlington_stadium', enabled = true,
            display_name = 'Arlington Stadium', real_name = 'AT&T Stadium',
            zone = 'Arlington Stadium District', category = 'stadium',
            gta_base = 'Maze Bank Arena / La Puerta',
            coords = { x = -250.5, y = -2030.0, z = 30.1 },
            blip = { enabled = true, sprite = 541, colour = 38, scale = 0.9 },
            rp_purpose = 'Stadium district event arrival and outdoor gathering point.',
            interior_requirement = 'Exterior only; no arena interior loaded.',
            stage = 'identity_only', survey_status = 'manual_required'
        },
        {
            id = 'whataburger', enabled = true, branding_mode = 'fictional',
            display_name = 'Texas Burger Grill', real_name = 'Whataburger',
            zone = 'Arlington South Corridor', category = 'commercial',
            subcategory = 'restaurant', identity_group = 'texas_staples',
            gta_base = 'Davis / Strawberry retail spine, south toward LSIA (Highlands analogue search area)',
            coords = { x = 12.04, y = -1605.57, z = 29.37 },
            blip = { enabled = true, sprite = 1, colour = 0, scale = 0.7 },
            rp_purpose = 'PROVISIONAL - MANUAL GAME SURVEY REQUIRED. Restaurant search reference only.',
            interior_requirement = 'Exterior-first candidate; service counter/kitchen only under a future approved room brief.',
            asset_requirement = 'None installed; future original or licensed signage and any shell/MLO require provenance and Enhanced validation.',
            stage = 'provisional_dev_test', survey_status = 'manual_required',
            notes = 'PROVISIONAL - MANUAL GAME SURVEY REQUIRED. Search-area reference only, not a selected restaurant parcel or interaction point. Fictional name is an internal placeholder; no official artwork or trade dress approved.'
        },
        {
            id = 'dairy_queen', enabled = true, branding_mode = 'fictional',
            display_name = 'Prairie Ice Cream and Grill', real_name = 'Dairy Queen',
            zone = 'Arlington South Corridor', category = 'commercial',
            subcategory = 'restaurant', identity_group = 'texas_staples',
            gta_base = 'Strawberry commercial approach from civic core (Parks Mall corridor analogue search area)',
            coords = { x = 100.0, y = -1400.0, z = 29.0 },
            blip = { enabled = true, sprite = 1, colour = 0, scale = 0.7 },
            rp_purpose = 'PROVISIONAL - MANUAL GAME SURVEY REQUIRED. Restaurant search reference only.',
            interior_requirement = 'Exterior-first candidate; compact counter/social shell only under a future approved room brief.',
            asset_requirement = 'None installed; future original or licensed signage and any shell/MLO require provenance and Enhanced validation.',
            stage = 'provisional_dev_test', survey_status = 'manual_required',
            notes = 'PROVISIONAL - MANUAL GAME SURVEY REQUIRED. Search-area reference only, not a selected restaurant parcel or interaction point. Fictional name is an internal placeholder; no official artwork or trade dress approved.'
        }
    }
}
