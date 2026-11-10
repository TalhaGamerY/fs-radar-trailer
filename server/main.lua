local activeStates = {} -- [id] = last clean state

local function CountRadars(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Persistence.Load()
    print(('[radar_trailer] Server ready – %d radar(s)'):format(CountRadars(Persistence.GetAll())))
    SetTimeout(1500, function()
        TriggerClientEvent('radar_trailer:client:syncAll', -1, Persistence.GetAll())
    end)
end)

-- Late joiners
RegisterNetEvent('radar_trailer:server:requestSync', function()
    local src = source
    TriggerClientEvent('radar_trailer:client:syncAll', src, Persistence.GetAll())
    -- Also push current live states
    for id, state in pairs(activeStates) do
        TriggerClientEvent('radar_trailer:client:state', src, id, state)
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(2500, function()
        -- GetPlayerName returns nil if the player already left
        if GetPlayerName(src) then
            TriggerClientEvent('radar_trailer:client:syncAll', src, Persistence.GetAll())
            for id, state in pairs(activeStates) do
                TriggerClientEvent('radar_trailer:client:state', src, id, state)
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- CREATE
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:server:create', function(data)
    local src = source
    if not Permissions.HasPermission(src) then
        Permissions.Deny(src, 'create radar')
        return
    end
    if type(data) ~= 'table' or type(data.coords) ~= 'table' or not data.coords.x then
        Permissions.Notify(src, 'Invalid placement data', 'error')
        return
    end

    local radar = Utils.ValidateRadarData(data, Config.Defaults)
    radar.coords = {
        x = tonumber(data.coords.x) or 0.0,
        y = tonumber(data.coords.y) or 0.0,
        z = tonumber(data.coords.z) or 0.0,
    }
    radar.heading = tonumber(data.heading) or 0.0

    local id = Persistence.Create(radar)
    TriggerClientEvent('radar_trailer:client:spawn', -1, id, radar)
    Permissions.Notify(src, ('Radar #%d created'):format(id), 'success')
end)

---------------------------------------------------------------------------
-- UPDATE
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:server:update', function(id, data)
    local src = source
    if not Permissions.HasPermission(src) then
        Permissions.Deny(src, 'update radar')
        return
    end
    id = tonumber(id)
    local existing = id and Persistence.Get(id)
    if not existing then
        Permissions.Notify(src, 'Radar not found', 'error')
        return
    end
    if type(data) ~= 'table' then return end

    local radar = Utils.ValidateRadarData(data, existing)
    -- Preserve position unless explicitly moved
    radar.coords = existing.coords
    radar.heading = existing.heading
    if type(data.coords) == 'table' and data.coords.x then
        radar.coords = {
            x = tonumber(data.coords.x) or existing.coords.x,
            y = tonumber(data.coords.y) or existing.coords.y,
            z = tonumber(data.coords.z) or existing.coords.z,
        }
    end
    if data.heading then
        radar.heading = tonumber(data.heading) or existing.heading
    end

    Persistence.Update(id, radar)
    TriggerClientEvent('radar_trailer:client:update', -1, id, radar)
    Permissions.Notify(src, ('Radar #%d updated'):format(id), 'success')
end)

---------------------------------------------------------------------------
-- DELETE
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:server:delete', function(id)
    local src = source
    if not Permissions.HasPermission(src) then
        Permissions.Deny(src, 'delete radar')
        return
    end
    id = tonumber(id)
    if not id or not Persistence.Delete(id) then
        Permissions.Notify(src, 'Radar not found', 'error')
        return
    end
    activeStates[id] = nil
    TriggerClientEvent('radar_trailer:client:delete', -1, id)
    Permissions.Notify(src, ('Radar #%d deleted'):format(id), 'success')
end)

---------------------------------------------------------------------------
-- LIVE STATE (from detecting client)
-- Only accept meaningful changes and rebroadcast.
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:server:state', function(id, state)
    id = tonumber(id)
    if not id or not Persistence.Get(id) then return end
    if type(state) ~= 'table' then return end

    local clean = {
        speed        = math.floor(Utils.Clamp(tonumber(state.speed) or 0, 0, 400)),
        overspeed    = state.overspeed == true,
        text         = tostring(state.text or ''):sub(1, 32),
        lights       = state.lights == true,
        vehicleNetId = tonumber(state.vehicleNetId) or 0,
        machine      = tostring(state.machine or 'IDLE'):sub(1, 16),
    }

    local prev = activeStates[id]
    if prev
        and prev.speed == clean.speed
        and prev.overspeed == clean.overspeed
        and prev.lights == clean.lights
        and prev.machine == clean.machine
    then
        return -- no change, drop
    end

    activeStates[id] = clean
    TriggerClientEvent('radar_trailer:client:state', -1, id, clean)
end)

---------------------------------------------------------------------------
-- LIST / RELOAD
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:server:requestList', function()
    local src = source
    if not Permissions.HasPermission(src) then
        Permissions.Deny(src, 'list radars')
        return
    end
    TriggerClientEvent('radar_trailer:client:receiveList', src, Persistence.GetAll())
end)

RegisterNetEvent('radar_trailer:server:reload', function()
    local src = source
    if not Permissions.HasPermission(src) then
        Permissions.Deny(src, 'reload radars')
        return
    end
    Persistence.Reload()
    activeStates = {}
    TriggerClientEvent('radar_trailer:client:syncAll', -1, Persistence.GetAll())
    Permissions.Notify(src, 'Radars reloaded from disk', 'success')
end)

---------------------------------------------------------------------------
-- VIOLATION LOG (cosmetic, no persistence)
---------------------------------------------------------------------------
RegisterNetEvent('radar_trailer:server:logViolation', function(id, payload)
    id = tonumber(id)
    if not id or not Persistence.Get(id) then return end
    if type(payload) ~= 'table' then return end
    TriggerClientEvent('radar_trailer:client:violation', -1, id, {
        time   = tostring(payload.time or ''):sub(1, 16),
        plate  = tostring(payload.plate or ''):sub(1, 12),
        model  = tostring(payload.model or ''):sub(1, 24),
        speed  = math.floor(tonumber(payload.speed) or 0),
        unit   = (payload.unit == 'KM/H') and 'KM/H' or 'MPH',
        over   = math.floor(tonumber(payload.over) or 0),
        driver = tostring(payload.driver or ''):sub(1, 32),
    })
end)

print('[radar_trailer] Server main loaded')
