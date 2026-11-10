Config = {}

--[[
    MODEL
    Vanilla prop for testing. When you stream the custom model, set:
        Config.Model = `radar_speed_trailer`
    and use the offsets under ModelAlternatives.radar_speed_trailer.
]]
Config.Model = `prop_consign_02a`

Config.ModelAlternatives = {
    consign_02a = {
        model   = `prop_consign_02a`,
        offsets = {
            display   = vector3(0.0,  0.08, 1.55),
            redLight  = vector3(-0.40, 0.10, 0.45),
            blueLight = vector3( 0.40, 0.10, 0.45),
            radar     = vector3(0.0,  0.15, 1.70),
        },
    },
    -- Custom mesh (after Blender/Sollumz export into stream/)
    radar_speed_trailer = {
        model   = `radar_speed_trailer`,
        offsets = {
            display   = vector3( 0.00, -0.155, 1.75),
            redLight  = vector3(-0.32,  0.67, 0.55),
            blueLight = vector3( 0.32,  0.67, 0.55),
            radar     = vector3( 0.00,  0.30, 1.30),
        },
    },
    trafficdiv_01 = {
        model   = `prop_trafficdiv_01`,
        offsets = {
            display   = vector3(0.0,  0.12, 1.35),
            redLight  = vector3(-0.55, 0.15, 0.55),
            blueLight = vector3( 0.55, 0.15, 0.55),
            radar     = vector3(0.0,  0.20, 1.55),
        },
    },
}

--[[
    Offsets for the ACTIVE Config.Model (copy from a preset above when swapping)
]]
Config.Offsets = {
    display   = vector3(0.0,  0.08, 1.55),
    redLight  = vector3(-0.40, 0.10, 0.45),
    blueLight = vector3( 0.40, 0.10, 0.45),
    radar     = vector3(0.0,  0.15, 1.70),
}

--[[
    LED BOARD (matches real portable radar trailer layout)

      ┌─────────────────┐
      │  SPEED LIMIT    │  white plate — number from speedLimit (NUI)
      │      25         │
      ├─────────────────┤
      │  YOUR SPEED     │  yellow bar — becomes SLOW DOWN when overspeed
      ├─────────────────┤
      │                 │
      │      24         │  amber LED digits (red when overspeed)
      │     MPH         │
      └─────────────────┘
]]
Config.Display = {
    scale           = 1.05,
    maxDistance     = 55.0,
    boardWidth      = 1.00,
    boardHeight     = 0.80,
    ledAmber        = { 255, 170, 40 },
    ledRed          = { 255, 45, 45 },
    ledDim          = { 180, 180, 180 },
    -- Labels (override per-radar via NUI still works for displayText / overspeedText)
    speedLimitLabel = 'SPEED LIMIT',
    showUnit        = true,
    showLimitPlate  = true,   -- white SPEED LIMIT plate above LED
    showYellowBar   = true,   -- yellow YOUR SPEED / SLOW DOWN bar
}

--[[
    DEFAULTS applied to every newly created radar
]]
Config.Defaults = {
    speedLimit      = 25,     -- default matches common zone; change in NUI
    range           = 60.0,     -- metres
    angle           = 50.0,     -- full cone width in degrees (half used for math)
    direction       = 0.0,      -- yaw offset relative to trailer heading (negative = left)
    unit            = 'MPH',    -- 'MPH' | 'KM/H'
    displayText     = 'YOUR SPEED',
    overspeedText   = 'SLOW DOWN',
    boardText       = 'TEST TEST',
    signName        = 'Route 68 North',
    signMode        = 'radar',  -- 'radar' | 'text' | 'off'
    radarEnabled    = true,
    detectPlayers   = true,
    detectNPCs      = false,
    requireApproach = true,     -- only vehicles moving toward the radar
    mapBlip         = 'police', -- 'everyone' | 'police' | 'hidden'
    emergencyLights = 'on_violation', -- 'off' | 'on_violation' | 'always'
    cameraFlash     = true,
    flashInterval   = 150,      -- ms between red/blue swap
}

--[[
    LIGHT COLOURS (0-255)
]]
Config.Lights = {
    red  = { r = 255, g = 20,  b = 20 },
    blue = { r = 20,  g = 80,  b = 255 },
    range = 5.0,
    intensity = 8.0,
}

--[[
    PERFORMANCE
    Adaptive polling. Values are milliseconds.
]]
Config.Update = {
    farCheck    = 2000,   -- no radar nearby
    nearCheck   = 400,    -- radar nearby, no active target
    activeCheck = 80,     -- actively tracking a vehicle
}

Config.NearDistance = 120.0   -- client starts processing radars inside this radius

--[[
    SPEED
]]
Config.MinSpeedToDetect = 2.0   -- m/s (~4.5 mph) – parked / crawling ignored
Config.SpeedSmoothAlpha = 0.35  -- 0 = no smooth, 1 = full instantaneous (display only)

--[[
    VALIDATION LIMITS (server clamps)
]]
Config.Limits = {
    speedLimit = { min = 1,   max = 200 },
    range      = { min = 5.0, max = 200.0 },
    angle      = { min = 5.0, max = 160.0 },
    direction  = { min = -90.0, max = 90.0 },
}

--[[
    PERMISSIONS

    PermissionMode:
      'open'  – anyone can use radar commands
      'job'   – only Config.PoliceJobs (+ admins always)
      'ace'   – only ACE (legacy)
      'any'   – police job OR ACE OR admin   ← default, no ACE required

    Admins (framework admin / common ACE) always allowed.
    No server.cfg ACE lines required for police officers.
]]
Config.PermissionMode = 'any'
Config.Permission     = 'radar.admin'   -- only used if mode is 'ace' or as extra admin ACE

-- Job names that can place/edit/delete radars (case-insensitive)
Config.PoliceJobs = {
    'police',
    'lspd',
    'bcso',
    'sasp',
    'sheriff',
    'state',
    'trooper',
    'fib',
    'leo',
}

Config.RequireOnDuty = false   -- set true if you use QB on-duty and want on-duty only

--[[
    DEBUG
]]
Config.Debug = false

--[[
    COMMANDS
]]
Config.Commands = {
    open   = 'radar',
    create = 'radarcreate',
    edit   = 'radaredit',
    delete = 'radardelete',
    list   = 'radarlist',
    reload = 'radarreload',
}
