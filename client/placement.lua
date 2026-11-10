local previewEntity = nil
local previewHeading = 0.0
local previewCoords = vector3(0.0, 0.0, 0.0)

function StartPlacement()
    if IsPlacing then return end
    IsPlacing = true

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    previewCoords = coords + forward * 5.0
    previewHeading = GetEntityHeading(ped)

    local model = LoadModel(Config.Model)
    previewEntity = CreateObject(model, previewCoords.x, previewCoords.y, previewCoords.z, false, false, false)
    SetEntityHeading(previewEntity, previewHeading)
    SetEntityAlpha(previewEntity, 160, false)
    SetEntityCollision(previewEntity, false, false)
    FreezeEntityPosition(previewEntity, true)
    SetEntityAsMissionEntity(previewEntity, true, true)

    CreateThread(function()
        while IsPlacing do
            Wait(0)

            -- Disable combat / weapon
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local moveSpeed = IsControlPressed(0, 21) and 0.18 or 0.06 -- Shift = faster
            local camRot = GetGameplayCamRot(2)
            local h = math.rad(camRot.z)

            if IsControlPressed(0, 32) then -- W
                previewCoords = previewCoords + vector3(-math.sin(h) * moveSpeed, math.cos(h) * moveSpeed, 0.0)
            end
            if IsControlPressed(0, 33) then -- S
                previewCoords = previewCoords + vector3(math.sin(h) * moveSpeed, -math.cos(h) * moveSpeed, 0.0)
            end
            if IsControlPressed(0, 34) then -- A
                previewCoords = previewCoords + vector3(-math.cos(h) * moveSpeed, -math.sin(h) * moveSpeed, 0.0)
            end
            if IsControlPressed(0, 35) then -- D
                previewCoords = previewCoords + vector3(math.cos(h) * moveSpeed, math.sin(h) * moveSpeed, 0.0)
            end
            if IsControlPressed(0, 44) then -- Q rotate left
                previewHeading = (previewHeading - 2.0) % 360.0
            end
            if IsControlPressed(0, 38) then -- E rotate right
                previewHeading = (previewHeading + 2.0) % 360.0
            end
            if IsControlPressed(0, 10) then -- PageUp
                previewCoords = vector3(previewCoords.x, previewCoords.y, previewCoords.z + 0.04)
            end
            if IsControlPressed(0, 11) then -- PageDown
                previewCoords = vector3(previewCoords.x, previewCoords.y, previewCoords.z - 0.04)
            end

            -- Soft ground snap
            local found, gz = GetGroundZFor_3dCoord(previewCoords.x, previewCoords.y, previewCoords.z + 3.0, false)
            if found and math.abs(previewCoords.z - gz) < 2.5 then
                previewCoords = vector3(previewCoords.x, previewCoords.y, gz)
            end

            if DoesEntityExist(previewEntity) then
                SetEntityCoordsNoOffset(previewEntity, previewCoords.x, previewCoords.y, previewCoords.z, false, false, false)
                SetEntityHeading(previewEntity, previewHeading)
            end

            -- Help
            SetTextFont(4)
            SetTextScale(0.38, 0.38)
            SetTextColour(255, 255, 255, 230)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString('~b~W/A/S/D~w~ Move   ~b~Q/E~w~ Rotate   ~b~PgUp/PgDn~w~ Height\n~g~ENTER~w~ Confirm   ~r~BACKSPACE~w~ Cancel')
            DrawText(0.32, 0.88)

            if IsControlJustPressed(0, 191) then -- ENTER
                ConfirmPlacement()
            elseif IsControlJustPressed(0, 177) then -- BACKSPACE
                CancelPlacement()
            end
        end
    end)
end

function ConfirmPlacement()
    if not IsPlacing then return end
    IsPlacing = false

    if previewEntity and DoesEntityExist(previewEntity) then
        DeleteEntity(previewEntity)
    end
    previewEntity = nil

    local data = Utils.DeepCopy(Config.Defaults)
    data.coords = { x = previewCoords.x, y = previewCoords.y, z = previewCoords.z }
    data.heading = previewHeading

    CurrentEditId = nil
    IsMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action   = 'open',
        defaults = Config.Defaults,
        radar    = data,
        id       = nil,
        isNew    = true,
    })
end

function CancelPlacement()
    IsPlacing = false
    if previewEntity and DoesEntityExist(previewEntity) then
        SetEntityAsMissionEntity(previewEntity, true, true)
        DeleteEntity(previewEntity)
    end
    previewEntity = nil
end

-- Ensure cleanup if resource stops mid-placement
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and IsPlacing then
        CancelPlacement()
    end
end)

print('[radar_trailer] Placement loaded')
