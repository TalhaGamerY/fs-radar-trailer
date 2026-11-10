Utils = {}

-- GTA heading: 0 = North, increases clockwise.
-- math.atan2(dy, dx): 0 = East, counter-clockwise.
-- Convert GTA heading → math radians for vector work.
function Utils.HeadingToMathRad(heading)
    return math.rad((450.0 - heading) % 360.0)
end

function Utils.DegToRad(deg)
    return deg * math.pi / 180.0
end

function Utils.RadToDeg(rad)
    return rad * 180.0 / math.pi
end

function Utils.Clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function Utils.NormalizeAngleDiff(diff)
    while diff > 180.0 do diff = diff - 360.0 end
    while diff < -180.0 do diff = diff + 360.0 end
    return diff
end

--[[
    Speed helpers
    Raw speed always returned in m/s.
    Display conversion is separate so internal logic stays precise.
]]
function Utils.GetSpeedMs(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return 0.0
    end
    return GetEntitySpeed(vehicle)
end

function Utils.MsToDisplay(speedMs, unit)
    if unit == 'KM/H' then
        return math.floor(speedMs * 3.6 + 0.5)
    end
    return math.floor(speedMs * 2.236936 + 0.5)
end

--[[
    Cone test
    origin   : vector3
    heading  : GTA degrees (0 = North)
    targetPos: vector3
    range    : metres
    halfAngle: degrees (half of full cone width)
    Returns: inCone (bool), distance (number)
]]
function Utils.IsInCone(origin, heading, targetPos, range, halfAngle)
    local dx = targetPos.x - origin.x
    local dy = targetPos.y - origin.y
    local distSq = dx * dx + dy * dy
    local rangeSq = range * range
    if distSq > rangeSq or distSq < 0.25 then
        return false, math.sqrt(distSq)
    end
    local dist = math.sqrt(distSq)

    -- Direction the radar is facing (unit vector)
    local hRad = Utils.HeadingToMathRad(heading)
    local fx = math.cos(hRad)
    local fy = math.sin(hRad)

    -- Unit vector toward target
    local tx = dx / dist
    local ty = dy / dist

    -- Dot product → angle between facing and target
    local dot = fx * tx + fy * ty
    local halfRad = Utils.DegToRad(halfAngle)
    local minDot = math.cos(halfRad)

    return dot >= minDot, dist
end

--[[
    Is the vehicle approaching the radar?
    Uses velocity vector dotted with vector from vehicle → radar.
    Positive = moving toward radar.
]]
function Utils.IsApproaching(vehicle, radarPos)
    local vel = GetEntityVelocity(vehicle)
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
    if speed < 0.5 then return false end

    local vpos = GetEntityCoords(vehicle)
    local toRadarX = radarPos.x - vpos.x
    local toRadarY = radarPos.y - vpos.y
    local toLen = math.sqrt(toRadarX * toRadarX + toRadarY * toRadarY)
    if toLen < 0.1 then return true end

    local dot = (vel.x / speed) * (toRadarX / toLen) + (vel.y / speed) * (toRadarY / toLen)
    return dot > 0.15  -- slight tolerance
end

function Utils.DeepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

function Utils.ValidateRadarData(data, existing)
    existing = existing or Config.Defaults
    local lim = Config.Limits

    local function num(v, fallback, min, max)
        local n = tonumber(v)
        if not n then n = fallback end
        return Utils.Clamp(n, min, max)
    end

    local unit = (data.unit == 'KM/H') and 'KM/H' or 'MPH'
    local lights = data.emergencyLights
    if lights ~= 'off' and lights ~= 'on_violation' and lights ~= 'always' then
        lights = existing.emergencyLights or 'on_violation'
    end
    local signMode = data.signMode
    if signMode ~= 'radar' and signMode ~= 'text' and signMode ~= 'off' then
        signMode = existing.signMode or 'radar'
    end
    local mapBlip = data.mapBlip
    if mapBlip ~= 'everyone' and mapBlip ~= 'police' and mapBlip ~= 'hidden' then
        mapBlip = existing.mapBlip or 'police'
    end

    local coords = data.coords
    if type(coords) ~= 'table' or not coords.x then
        coords = existing.coords
    end

    return {
        coords          = coords,
        heading         = num(data.heading, existing.heading or 0.0, -360.0, 360.0),
        speedLimit      = num(data.speedLimit, existing.speedLimit, lim.speedLimit.min, lim.speedLimit.max),
        range           = num(data.range, existing.range, lim.range.min, lim.range.max),
        angle           = num(data.angle, existing.angle, lim.angle.min, lim.angle.max),
        direction       = num(data.direction, existing.direction, lim.direction.min, lim.direction.max),
        unit            = unit,
        displayText     = tostring(data.displayText or existing.displayText or 'YOUR SPEED'):sub(1, 32),
        overspeedText   = tostring(data.overspeedText or existing.overspeedText or 'SLOW DOWN'):sub(1, 32),
        boardText       = tostring(data.boardText or existing.boardText or ''):sub(1, 24),
        signName        = tostring(data.signName or existing.signName or ''):sub(1, 48),
        signMode        = signMode,
        radarEnabled    = data.radarEnabled ~= false,
        detectPlayers   = data.detectPlayers ~= false,
        detectNPCs      = data.detectNPCs == true,
        requireApproach = data.requireApproach ~= false,
        mapBlip         = mapBlip,
        emergencyLights = lights,
        cameraFlash     = data.cameraFlash ~= false,
        flashInterval   = num(data.flashInterval, existing.flashInterval or 150, 50, 1000),
    }
end
