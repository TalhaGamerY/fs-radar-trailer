CreateThread(function()
    while true do
        if not Config.Debug then
            Wait(1500)
        else
            Wait(0)
            for id, radar in pairs(Radars) do
                if radar.entity and DoesEntityExist(radar.entity) then
                    local coords = GetEntityCoords(radar.entity)
                    local data = radar.data
                    local heading = (GetEntityHeading(radar.entity) + (data.direction or 0.0)) % 360.0
                    local range = data.range or 50.0
                    local halfAngle = (data.angle or 50.0) * 0.5

                    -- Facing arrow
                    local rad = Utils.HeadingToMathRad(heading)
                    local endX = coords.x + math.cos(rad) * range
                    local endY = coords.y + math.sin(rad) * range
                    DrawLine(coords.x, coords.y, coords.z + 0.6, endX, endY, coords.z + 0.6, 0, 220, 255, 220)

                    -- Cone edges
                    local leftH = (heading - halfAngle) % 360.0
                    local rightH = (heading + halfAngle) % 360.0
                    local lr = Utils.HeadingToMathRad(leftH)
                    local rr = Utils.HeadingToMathRad(rightH)
                    DrawLine(coords.x, coords.y, coords.z + 0.4,
                        coords.x + math.cos(lr) * range, coords.y + math.sin(lr) * range, coords.z + 0.4,
                        255, 140, 0, 180)
                    DrawLine(coords.x, coords.y, coords.z + 0.4,
                        coords.x + math.cos(rr) * range, coords.y + math.sin(rr) * range, coords.z + 0.4,
                        255, 140, 0, 180)

                    -- Arc samples
                    for i = -halfAngle, halfAngle, 8 do
                        local a = Utils.HeadingToMathRad((heading + i) % 360.0)
                        local px = coords.x + math.cos(a) * range
                        local py = coords.y + math.sin(a) * range
                        DrawLine(coords.x, coords.y, coords.z + 0.15, px, py, coords.z + 0.15, 80, 80, 80, 60)
                    end

                    -- Label
                    local state = LocalStates[id] or {}
                    local track = GetRadarTrack and GetRadarTrack(id)
                    local machine = state.machine or (track and track.machine) or 'IDLE'
                    local line1 = ('Radar #%d  [%s]'):format(id, machine)
                    local line2 = ('Spd %d %s  Limit %d  Range %.0fm  Cone %.0f°'):format(
                        state.speed or 0,
                        data.unit or 'MPH',
                        data.speedLimit or 0,
                        range,
                        data.angle or 0
                    )

                    SetTextFont(0)
                    SetTextScale(0.28, 0.28)
                    SetTextColour(255, 255, 80, 255)
                    SetTextCentre(true)
                    SetTextEntry('STRING')
                    AddTextComponentString(line1)
                    SetDrawOrigin(coords.x, coords.y, coords.z + 2.4, 0)
                    DrawText(0.0, 0.0)
                    ClearDrawOrigin()

                    SetTextFont(0)
                    SetTextScale(0.25, 0.25)
                    SetTextColour(200, 200, 200, 220)
                    SetTextCentre(true)
                    SetTextEntry('STRING')
                    AddTextComponentString(line2)
                    SetDrawOrigin(coords.x, coords.y, coords.z + 2.15, 0)
                    DrawText(0.0, 0.0)
                    ClearDrawOrigin()
                end
            end
        end
    end
end)

print('[radar_trailer] Debug loaded')
