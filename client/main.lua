Radars = {}          -- [id] = { data = {}, entity = handle, blip = handle }
LocalStates = {}     -- [id] = last known display/light state
IsMenuOpen = false
IsPlacing = false
CurrentEditId = nil
PendingPermissionCb = nil  -- function() called if server grants ACE

function LoadModel(model)
    local hash
    if type(model) == 'number' then
        hash = model
    else
        -- joaat is preferred; GetHashKey kept as fallback for older artifacts
        hash = (joaat and joaat(model)) or GetHashKey(model)
    end
    if not IsModelInCdimage(hash) and not IsModelValid(hash) then
        print(('[radar_trailer] Model %s not found – using prop_consign_02a'):format(tostring(model)))
        hash = Config.Model or `prop_consign_02a`
    end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do
            Wait(20)
        end
    end
    if not HasModelLoaded(hash) then
        print('[radar_trailer] Model load timed out – using prop_consign_02a')
        hash = `prop_consign_02a`
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(20) end
    end
    return hash
end

function SpawnRadar(id, data)
    if Radars[id] then
        DeleteRadarLocal(id)
    end

    if type(data.coords) ~= 'table' or not data.coords.x then
        print(('[radar_trailer] Invalid coords for radar #%s – skipped'):format(tostring(id)))
        return
    end

    local model = LoadModel(Config.Model)
    local c = data.coords
    local entity = CreateObject(model, c.x, c.y, c.z, false, false, false)
    if not entity or entity == 0 then
        print(('[radar_trailer] Failed to create object for radar #%s'):format(tostring(id)))
        return
    end

    SetEntityHeading(entity, data.heading or 0.0)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, true, true)
    SetEntityAsMissionEntity(entity, true, true)
    -- Do NOT call PlaceObjectOnGroundProperly here – it can fight stored Z

    local blip = nil
    if data.mapBlip and data.mapBlip ~= 'hidden' then
        blip = AddBlipForEntity(entity)
        SetBlipSprite(blip, 56)
        SetBlipColour(blip, 3)
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(data.signName and data.signName ~= '' and data.signName or ('Radar #%d'):format(id))
        EndTextCommandSetBlipName(blip)
    end

    Radars[id] = {
        data   = data,
        entity = entity,
        blip   = blip,
    }
    LocalStates[id] = {
        speed = 0,
        overspeed = false,
        text = data.displayText or 'YOUR SPEED',
        lights = false,
        machine = 'IDLE',
    }
end

function DeleteRadarLocal(id)
    local r = Radars[id]
    if not r then return end
    if r.entity and DoesEntityExist(r.entity) then
        SetEntityAsMissionEntity(r.entity, true, true)
        DeleteEntity(r.entity)
    end
    if r.blip and DoesBlipExist(r.blip) then
        RemoveBlip(r.blip)
    end
    Radars[id] = nil
    LocalStates[id] = nil
    -- Drop any local tracking entry for this id (defined in detection.lua)
    if type(GetRadarTrack) == 'function' then
        local t = GetRadarTrack(id)
        if t then t.vehicle = nil; t.machine = 'IDLE' end
    end
end

---------------------------------------------------------------------------
-- Network events
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:client:syncAll', function(all)
    for id in pairs(Radars) do
        DeleteRadarLocal(id)
    end
    if type(all) ~= 'table' then return end
    for id, data in pairs(all) do
        SpawnRadar(tonumber(id) or id, data)
    end
end)

RegisterNetEvent('radar_trailer:client:spawn', function(id, data)
    SpawnRadar(tonumber(id) or id, data)
end)

RegisterNetEvent('radar_trailer:client:update', function(id, data)
    id = tonumber(id) or id
    if Radars[id] then
        Radars[id].data = data
        if DoesEntityExist(Radars[id].entity) and data.coords then
            SetEntityCoords(Radars[id].entity, data.coords.x, data.coords.y, data.coords.z, false, false, false, false)
            SetEntityHeading(Radars[id].entity, data.heading or 0.0)
        end
        -- Update blip name
        if Radars[id].blip and DoesBlipExist(Radars[id].blip) and data.signName then
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(data.signName)
            EndTextCommandSetBlipName(Radars[id].blip)
        end
    else
        SpawnRadar(id, data)
    end
end)

RegisterNetEvent('radar_trailer:client:delete', function(id)
    DeleteRadarLocal(tonumber(id) or id)
end)

RegisterNetEvent('radar_trailer:client:state', function(id, state)
    id = tonumber(id) or id
    LocalStates[id] = state
end)

RegisterNetEvent('radar_trailer:client:notify', function(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(msg))
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('radar_trailer:client:receiveList', function(all)
    SendNUIMessage({ action = 'list', radars = all })
end)

RegisterNetEvent('radar_trailer:client:violation', function(id, payload)
    if IsMenuOpen and (not CurrentEditId or CurrentEditId == id) then
        SendNUIMessage({ action = 'violation', data = payload })
    end
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
local function FindNearestRadar(maxDist)
    maxDist = maxDist or 15.0
    local pcoords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDist = nil, maxDist
    for id, r in pairs(Radars) do
        if r.entity and DoesEntityExist(r.entity) then
            local d = #(pcoords - GetEntityCoords(r.entity))
            if d < nearestDist then
                nearest = id
                nearestDist = d
            end
        end
    end
    return nearest
end

RegisterCommand(Config.Commands.open, function()
    if IsMenuOpen then
        CloseRadarMenu()
    else
        OpenRadarMenu()
    end
end, false)

RegisterCommand(Config.Commands.create, function()
    if IsPlacing then return end
    RequestRadarPermission(function()
        StartPlacement()
    end)
end, false)

RegisterCommand(Config.Commands.edit, function()
    local nearest = FindNearestRadar(15.0)
    if not nearest then
        TriggerEvent('radar_trailer:client:notify', 'No radar nearby')
        return
    end
    RequestRadarPermission(function()
        OpenRadarMenu(nearest)
    end)
end, false)

RegisterCommand(Config.Commands.delete, function()
    local nearest = FindNearestRadar(15.0)
    if nearest then
        TriggerServerEvent('radar_trailer:server:delete', nearest)
    else
        TriggerEvent('radar_trailer:client:notify', 'No radar nearby')
    end
end, false)

RegisterCommand(Config.Commands.list, function()
    TriggerServerEvent('radar_trailer:server:requestList')
end, false)

RegisterCommand(Config.Commands.reload, function()
    TriggerServerEvent('radar_trailer:server:reload')
end, false)

---------------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    CloseRadarMenu()
    cb('ok')
end)

RegisterNUICallback('save', function(data, cb)
    if type(data) == 'table' and data.id then
        TriggerServerEvent('radar_trailer:server:update', data.id, data)
    end
    CloseRadarMenu()
    cb('ok')
end)

RegisterNUICallback('place', function(data, cb)
    if type(data) == 'table' and data.coords then
        TriggerServerEvent('radar_trailer:server:create', data)
    end
    CloseRadarMenu()
    cb('ok')
end)

RegisterNUICallback('delete', function(data, cb)
    if type(data) == 'table' and data.id then
        TriggerServerEvent('radar_trailer:server:delete', data.id)
    end
    CloseRadarMenu()
    cb('ok')
end)

RegisterNUICallback('create', function(_, cb)
    CloseRadarMenu()
    RequestRadarPermission(function()
        StartPlacement()
    end)
    cb('ok')
end)

---------------------------------------------------------------------------
-- Permission gate (server ACE)
---------------------------------------------------------------------------
function RequestRadarPermission(onAllowed)
    PendingPermissionCb = onAllowed
    TriggerServerEvent('radar_trailer:server:checkPermission')
end

RegisterNetEvent('radar_trailer:client:permissionResult', function(allowed)
    local cb = PendingPermissionCb
    PendingPermissionCb = nil
    if allowed and type(cb) == 'function' then
        cb()
    end
    -- deny message already sent by server
end)

---------------------------------------------------------------------------
-- Menu helpers
---------------------------------------------------------------------------
function OpenRadarMenu(editId)
    CurrentEditId = editId
    IsMenuOpen = true
    SetNuiFocus(true, true)

    local payload = {
        action   = 'open',
        defaults = Config.Defaults,
        radar    = nil,
        id       = editId,
        isNew    = false,
    }
    if editId and Radars[editId] then
        payload.radar = Utils.DeepCopy(Radars[editId].data)
        payload.radar.id = editId
    end
    SendNUIMessage(payload)
end

function CloseRadarMenu()
    IsMenuOpen = false
    CurrentEditId = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---------------------------------------------------------------------------
-- Startup + cleanup
---------------------------------------------------------------------------
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('radar_trailer:server:requestSync')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Cancel placement if active
    if IsPlacing and CancelPlacement then
        CancelPlacement()
    end
    for id in pairs(Radars) do
        DeleteRadarLocal(id)
    end
    SetNuiFocus(false, false)
end)

print('[radar_trailer] Client main loaded')
