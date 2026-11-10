-- Optional 3D interaction prompt when near a radar (admin only)
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)

        for id, radar in pairs(Radars) do
            if DoesEntityExist(radar.entity) then
                local dist = #(pcoords - GetEntityCoords(radar.entity))
                if dist < 3.5 then
                    sleep = 0
                    -- Simple help text
                    SetTextFont(4)
                    SetTextScale(0.35, 0.35)
                    SetTextColour(200, 220, 255, 220)
                    SetTextCentre(true)
                    SetTextEntry('STRING')
                    AddTextComponentString(('Radar #%d  ~b~/radaredit~w~ to configure'):format(id))
                    SetDrawOrigin(GetEntityCoords(radar.entity).x, GetEntityCoords(radar.entity).y, GetEntityCoords(radar.entity).z + 1.2, 0)
                    DrawText(0.0, 0.0)
                    ClearDrawOrigin()
                end
            end
        end
        Wait(sleep)
    end
end)

print('[radar_trailer] Interaction loaded')
