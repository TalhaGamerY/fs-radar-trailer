--[[
    Detection + state machine + lights + 3D display

    State machine per radar:
      IDLE → TARGET_DETECTED → TRACKING → OVERSPEED → PASSED → IDLE
]]

local tracked = {} -- [id] = track table

local function GetDetectionHeading(entity, data)
    return (GetEntityHeading(entity) + (data.direction or 0.0)) % 360.0
end

local function GetDisplayOrigin(entity)
    local off = Config.Offsets.display
    return GetOffsetFromEntityInWorldCoords(entity, off.x, off.y, off.z)
end

local function GetLightOrigin(entity, which)
    local off = (which == 'red') and Config.Offsets.redLight or Config.Offsets.blueLight
    return GetOffsetFromEntityInWorldCoords(entity, off.x, off.y, off.z)
end

---------------------------------------------------------------------------
-- Target selection
---------------------------------------------------------------------------
local function FindBestVehicle(radar)
    local entity = radar.entity
    local data = radar.data
    if not data.radarEnabled then return nil end

    local origin = GetEntityCoords(entity)
    local heading = GetDetectionHeading(entity, data)
    local range = data.range or 50.0
    local halfAngle = (data.angle or 50.0) * 0.5
    local minSpeed = Config.MinSpeedToDetect or 2.0
    local requireApproach = data.requireApproach ~= false

    local bestVeh, bestScore = nil, -1.0

    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local veh = vehicles[i]
        if DoesEntityExist(veh) then
            local speedMs = Utils.GetSpeedMs(veh)
            if speedMs >= minSpeed then
                local driver = GetPedInVehicleSeat(veh, -1)
                local isPlayer = driver and driver ~= 0 and IsPedAPlayer(driver)

                local allowed = (isPlayer and data.detectPlayers)
                    or (not isPlayer and data.detectNPCs)

                if allowed then
                    local pos = GetEntityCoords(veh)
                    local inCone, dist = Utils.IsInCone(origin, heading, pos, range, halfAngle)
                    if inCone then
                        if not requireApproach or Utils.IsApproaching(veh, origin) then
                            -- Prefer closer vehicles (stable ranking)
                            local score = 1.0 / (dist + 0.5)
                            if score > bestScore then
                                bestScore = score
                                bestVeh = veh
                            end
                        end
                    end
                end
            end
        end
    end
    return bestVeh
end

---------------------------------------------------------------------------
-- State machine update
---------------------------------------------------------------------------
local function UpdateRadarState(id, radar)
    local data = radar.data
    local track = tracked[id]

    -- Ensure track table exists
    if not track then
        track = {
            vehicle      = nil,
            rawSpeedMs   = 0.0,
            smoothMs     = 0.0,
            displaySpeed = 0,
            overspeed    = false,
            lights       = false,
            machine      = 'IDLE',
            logged       = false,
            lastNetSend  = 0,
        }
        tracked[id] = track
    end

    if not data.radarEnabled then
        track.vehicle = nil
        track.machine = 'IDLE'
        track.overspeed = false
        track.lights = false
        track.displaySpeed = 0
        track.rawSpeedMs = 0.0
        track.smoothMs = 0.0
        track.logged = false
        goto publish
    end

    -- Re-validate current target
    local veh = track.vehicle
    if veh and DoesEntityExist(veh) then
        local origin = GetEntityCoords(radar.entity)
        local heading = GetDetectionHeading(radar.entity, data)
        local halfAngle = (data.angle or 50.0) * 0.5
        local pos = GetEntityCoords(veh)
        local inCone = Utils.IsInCone(origin, heading, pos, data.range or 50.0, halfAngle)
        local stillMoving = Utils.GetSpeedMs(veh) >= (Config.MinSpeedToDetect or 2.0)

        if not inCone or not stillMoving then
            -- Vehicle left detection / pass zone
            track.machine = 'PASSED'
            track.vehicle = nil
            track.overspeed = false
            track.lights = false
            track.logged = false
            track.displaySpeed = 0
            track.rawSpeedMs = 0.0
            track.smoothMs = 0.0
            veh = nil
        end
    else
        veh = nil
        track.vehicle = nil
        if track.machine ~= 'IDLE' and track.machine ~= 'PASSED' then
            track.machine = 'IDLE'
            track.overspeed = false
            track.lights = false
            track.logged = false
            track.displaySpeed = 0
        end
    end

    -- Acquire new target only when idle / after pass
    if not veh then
        if track.machine == 'PASSED' then
            -- one tick of PASSED then return to IDLE
            track.machine = 'IDLE'
        end
        veh = FindBestVehicle(radar)
        if veh then
            track.vehicle = veh
            track.machine = 'TARGET_DETECTED'
            track.logged = false
            track.smoothMs = Utils.GetSpeedMs(veh)
        end
    end

    -- Tracking / overspeed
    if veh and DoesEntityExist(veh) then
        local raw = Utils.GetSpeedMs(veh)
        track.rawSpeedMs = raw

        -- Light exponential smoothing for display only
        local alpha = Config.SpeedSmoothAlpha or 0.35
        track.smoothMs = track.smoothMs + (raw - track.smoothMs) * alpha
        track.displaySpeed = Utils.MsToDisplay(track.smoothMs, data.unit or 'MPH')

        local limit = data.speedLimit or 40
        local over = track.displaySpeed > limit

        if over then
            track.machine = 'OVERSPEED'
            track.overspeed = true
        else
            track.machine = 'TRACKING'
            track.overspeed = false
        end

        -- Lights
        if data.emergencyLights == 'always' then
            track.lights = true
        elseif data.emergencyLights == 'on_violation' then
            track.lights = over
        else
            track.lights = false
        end

        -- One-shot violation log
        if over and not track.logged then
            track.logged = true
            local plate = GetVehicleNumberPlateText(veh) or 'UNKNOWN'
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or 'UNKNOWN'
            local driverName = 'Unknown'
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver and IsPedAPlayer(driver) then
                local idx = NetworkGetPlayerIndexFromPed(driver)
                if idx and idx >= 0 then
                    driverName = GetPlayerName(idx) or 'Player'
                end
            end
            TriggerServerEvent('radar_trailer:server:logViolation', id, {
                time   = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
                plate  = plate,
                model  = model,
                speed  = track.displaySpeed,
                unit   = data.unit or 'MPH',
                over   = track.displaySpeed - limit,
                driver = driverName,
            })
        elseif not over then
            track.logged = false
        end
    end

    ::publish::

    local text = track.overspeed
        and (data.overspeedText or 'SLOW DOWN')
        or (data.displayText or 'YOUR SPEED')

    local netId = 0
    if track.vehicle and DoesEntityExist(track.vehicle) then
        netId = NetworkGetNetworkIdFromEntity(track.vehicle)
    end

    local state = {
        speed        = track.displaySpeed,
        overspeed    = track.overspeed,
        text         = text,
        lights       = track.lights,
        vehicleNetId = netId,
        machine      = track.machine,
    }

    -- Rate-limit network: only when something meaningful changed
    local prev = LocalStates[id]
    local changed = not prev
        or prev.speed ~= state.speed
        or prev.overspeed ~= state.overspeed
        or prev.lights ~= state.lights
        or prev.machine ~= state.machine

    if changed then
        LocalStates[id] = state
        -- Only the client that is closest to this radar should own detection
        -- (simple ownership: if we are within NearDistance we already process it)
        TriggerServerEvent('radar_trailer:server:state', id, state)
    end
end

---------------------------------------------------------------------------
-- Main detection loop (adaptive)
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = Config.Update.farCheck
        local pcoords = GetEntityCoords(PlayerPedId())
        local anyNear, anyActive = false, false

        for id, radar in pairs(Radars) do
            if radar.entity and DoesEntityExist(radar.entity) then
                local dist = #(pcoords - GetEntityCoords(radar.entity))
                if dist < Config.NearDistance then
                    anyNear = true
                    UpdateRadarState(id, radar)
                    local t = tracked[id]
                    if t and t.vehicle then
                        anyActive = true
                    end
                else
                    -- Far away – clear local tracking so we don't hold ghosts
                    if tracked[id] then
                        tracked[id].vehicle = nil
                        tracked[id].machine = 'IDLE'
                    end
                end
            end
        end

        if anyActive then
            sleep = Config.Update.activeCheck
        elseif anyNear then
            sleep = Config.Update.nearCheck
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- Emergency lights (client visual)
---------------------------------------------------------------------------
CreateThread(function()
    local toggle = false
    while true do
        local hasLights = false
        local interval = Config.Defaults.flashInterval or 150

        for id, state in pairs(LocalStates) do
            if state.lights then
                hasLights = true
                local radar = Radars[id]
                if radar and radar.entity and DoesEntityExist(radar.entity) then
                    local color = toggle and Config.Lights.red or Config.Lights.blue
                    local posR = GetLightOrigin(radar.entity, 'red')
                    local posB = GetLightOrigin(radar.entity, 'blue')
                    local range = Config.Lights.range or 5.0
                    local intens = Config.Lights.intensity or 8.0

                    if toggle then
                        DrawLightWithRange(posR.x, posR.y, posR.z, color.r, color.g, color.b, range, intens)
                    else
                        DrawLightWithRange(posB.x, posB.y, posB.z, color.r, color.g, color.b, range, intens)
                    end
                end
                local d = radar and radar.data
                if d and d.flashInterval then
                    interval = d.flashInterval
                end
            end
        end

        if hasLights then
            toggle = not toggle
            Wait(interval)
        else
            Wait(400)
        end
    end
end)

---------------------------------------------------------------------------
-- LED matrix speed board (styled after real portable VMS / radar trailers)
-- Black plate + amber LED digits; red when overspeed
---------------------------------------------------------------------------
-- Layout matches real portable radar trailers:
--   [ SPEED LIMIT ]   white plate + limit from NUI
--   [ YOUR SPEED  ]   yellow bar (SLOW DOWN when overspeed)
--   [   24        ]   large amber LED digits (red when overspeed)
local function DrawLedBoard(origin, label, speedStr, unit, overspeed, heading, speedLimit)
    local scale = Config.Display.scale or 1.0
    local amber = Config.Display.ledAmber or { 255, 170, 40 }
    local red   = Config.Display.ledRed   or { 255, 45, 45 }
    local color = overspeed and red or amber
    local bw = Config.Display.boardWidth  or 0.95
    local bh = Config.Display.boardHeight or 0.72
    local limitStr = tostring(speedLimit or 0)

    -- Black LED cabinet
    DrawMarker(1, origin.x, origin.y, origin.z, 0.0, 0.0, 0.0, 90.0, 0.0, heading or 0.0,
        bw, 0.06, bh, 8, 10, 14, 235, false, false, 2, false, nil, nil, false)
    DrawMarker(1, origin.x, origin.y, origin.z, 0.0, 0.0, 0.0, 90.0, 0.0, heading or 0.0,
        bw + 0.06, 0.04, bh + 0.06, 18, 20, 24, 200, false, false, 2, false, nil, nil, false)

    -- White SPEED LIMIT plate (limit value from NUI / radar data)
    if Config.Display.showLimitPlate ~= false then
        local plateZ = origin.z + bh * 0.55 + 0.28
        DrawMarker(1, origin.x, origin.y, plateZ, 0.0, 0.0, 0.0, 90.0, 0.0, heading or 0.0,
            0.55, 0.04, 0.42, 245, 245, 245, 240, false, false, 2, false, nil, nil, false)

        SetTextFont(4)
        SetTextScale(0.22 * scale, 0.22 * scale)
        SetTextColour(20, 20, 20, 255)
        SetTextCentre(true)
        SetTextEntry('STRING')
        AddTextComponentString(Config.Display.speedLimitLabel or 'SPEED LIMIT')
        SetDrawOrigin(origin.x, origin.y, plateZ + 0.12, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()

        SetTextFont(7)
        SetTextScale(0.72 * scale, 0.72 * scale)
        SetTextColour(15, 15, 15, 255)
        SetTextCentre(true)
        SetTextEntry('STRING')
        AddTextComponentString(limitStr)
        SetDrawOrigin(origin.x, origin.y, plateZ - 0.06, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end

    -- Yellow YOUR SPEED / SLOW DOWN bar
    if Config.Display.showYellowBar ~= false then
        local barZ = origin.z + bh * 0.42
        DrawMarker(1, origin.x, origin.y, barZ, 0.0, 0.0, 0.0, 90.0, 0.0, heading or 0.0,
            bw * 0.98, 0.035, 0.14, 250, 200, 20, 240, false, false, 2, false, nil, nil, false)

        SetTextFont(4)
        SetTextScale(0.28 * scale, 0.28 * scale)
        SetTextColour(10, 10, 10, 255)
        SetTextCentre(true)
        SetTextEntry('STRING')
        AddTextComponentString(label or 'YOUR SPEED')
        SetDrawOrigin(origin.x, origin.y, barZ, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end

    -- Large LED speed digits (player vehicle speed)
    SetTextFont(7)
    SetTextScale(1.15 * scale, 1.15 * scale)
    SetTextColour(color[1], color[2], color[3], 255)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(speedStr or '0')
    SetDrawOrigin(origin.x, origin.y, origin.z - 0.05, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()

    -- Unit under digits
    if Config.Display.showUnit ~= false then
        SetTextFont(4)
        SetTextScale(0.26 * scale, 0.26 * scale)
        SetTextColour(color[1], color[2], color[3], 200)
        SetTextCentre(true)
        SetTextOutline()
        SetTextEntry('STRING')
        AddTextComponentString(unit or 'MPH')
        SetDrawOrigin(origin.x, origin.y, origin.z - 0.32, 0)
        DrawText(0.0, 0.0)
        ClearDrawOrigin()
    end
end

CreateThread(function()
    while true do
        local sleep = 400
        local pcoords = GetEntityCoords(PlayerPedId())
        local maxDist = Config.Display.maxDistance or 55.0

        for id, radar in pairs(Radars) do
            if radar.entity and DoesEntityExist(radar.entity) then
                local data = radar.data
                if data.signMode == 'radar' or data.signMode == 'text' then
                    local origin = GetDisplayOrigin(radar.entity)
                    local dist = #(pcoords - origin)
                    if dist < maxDist then
                        sleep = 0
                        local state = LocalStates[id] or {}
                        local label = state.text or data.displayText or 'YOUR SPEED'
                        local speedStr = tostring(state.speed or 0)
                        local unit = data.unit or 'MPH'
                        local heading = GetEntityHeading(radar.entity)
                        local limit = data.speedLimit or Config.Defaults.speedLimit or 40
                        DrawLedBoard(origin, label, speedStr, unit, state.overspeed, heading, limit)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Expose track table for debug
function GetRadarTrack(id)
    return tracked[id]
end

print('[radar_trailer] Detection + state machine loaded')
