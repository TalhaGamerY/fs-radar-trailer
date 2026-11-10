Permissions = {}

--[[
    Permission modes (Config.PermissionMode):

      'open'  – anyone can create/edit/delete radars
      'job'   – police jobs (and admins) only
      'ace'   – ACE only (legacy)
      'any'   – job OR ace OR framework admin  (recommended)

    Default: 'any' so police job works without fighting ACE.
]]

local function lower(s)
    return type(s) == 'string' and s:lower() or ''
end

local function jobAllowed(jobName)
    if not jobName or jobName == '' then return false end
    local j = lower(jobName)
    for _, allowed in ipairs(Config.PoliceJobs or {}) do
        if j == lower(allowed) then
            return true
        end
    end
    return false
end

--- Optional framework job + admin detection (no hard dependency)
function Permissions.GetFrameworkInfo(src)
    local info = { job = nil, grade = 0, isAdmin = false, framework = nil }

    -- QBCore / Qbox
    local ok, QBCore = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData then
            info.framework = 'qb'
            local job = Player.PlayerData.job
            if job then
                info.job = job.name
                info.grade = job.grade and (job.grade.level or job.grade) or 0
            end
            -- QB admin groups
            local perms = QBCore.Functions.GetPermission and QBCore.Functions.GetPermission(src)
            if type(perms) == 'string' and (perms == 'admin' or perms == 'god') then
                info.isAdmin = true
            elseif type(perms) == 'table' then
                if perms.admin or perms.god then info.isAdmin = true end
            end
            if Player.PlayerData.metadata and Player.PlayerData.metadata.isadmin then
                info.isAdmin = true
            end
        end
        return info
    end

    -- Qbox alternate export
    ok, QBCore = pcall(function()
        return exports['qbx_core']:GetCoreObject()
    end)
    if ok and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData then
            info.framework = 'qbx'
            local job = Player.PlayerData.job
            if job then
                info.job = job.name
                info.grade = job.grade and (job.grade.level or job.grade) or 0
            end
        end
        return info
    end

    -- ESX
    ok, ESX = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if not ok or not ESX then
        ok, ESX = pcall(function()
            return exports.es_extended:getSharedObject()
        end)
    end
    if ok and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            info.framework = 'esx'
            local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
            if job then
                info.job = job.name
                info.grade = job.grade or 0
            end
            local group = xPlayer.getGroup and xPlayer.getGroup() or nil
            if group and (group == 'admin' or group == 'superadmin' or group == 'god') then
                info.isAdmin = true
            end
        end
        return info
    end

    return info
end

function Permissions.IsAceAllowed(src)
    local ace = Config.Permission or 'radar.admin'
    return IsPlayerAceAllowed(src, ace) == true
end

function Permissions.IsPoliceJob(src)
    local info = Permissions.GetFrameworkInfo(src)
    if info.job and jobAllowed(info.job) then
        -- Optional: require on-duty if framework exposes it
        if Config.RequireOnDuty then
            -- QB stores job.onduty
            local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok and QBCore then
                local Player = QBCore.Functions.GetPlayer(src)
                if Player and Player.PlayerData and Player.PlayerData.job then
                    if Player.PlayerData.job.onduty == false then
                        return false
                    end
                end
            end
        end
        return true
    end
    return false
end

function Permissions.IsAdmin(src)
    -- Framework admin
    local info = Permissions.GetFrameworkInfo(src)
    if info.isAdmin then return true end

    -- Common FiveM admin ACE objects (always free for real admins)
    if IsPlayerAceAllowed(src, 'command') == true then return true end
    if IsPlayerAceAllowed(src, 'admin') == true then return true end
    if IsPlayerAceAllowed(src, 'group.admin') == true then return true end
    if Config.Permission and IsPlayerAceAllowed(src, Config.Permission) == true then return true end

    return false
end

function Permissions.HasPermission(src)
    if src == 0 then return true end -- console
    if type(src) ~= 'number' or src < 1 then return false end

    local mode = lower(Config.PermissionMode or 'any')

    if mode == 'open' then
        return true
    end

    -- Admins always allowed in every mode except pure 'ace' if you want —
    -- user asked: let admin use however they want → always allow admins
    if Permissions.IsAdmin(src) then
        return true
    end

    if mode == 'job' then
        return Permissions.IsPoliceJob(src)
    end

    if mode == 'ace' then
        return Permissions.IsAceAllowed(src)
    end

    -- 'any' (default): police job OR ACE
    if Permissions.IsPoliceJob(src) then return true end
    if Permissions.IsAceAllowed(src) then return true end
    return false
end

function Permissions.GetPlayerDebugInfo(src)
    local name = GetPlayerName(src) or 'unknown'
    local identifiers = GetPlayerIdentifiers(src) or {}
    return name, identifiers
end

function Permissions.Deny(src, action)
    action = action or 'this action'
    local name, ids = Permissions.GetPlayerDebugInfo(src)
    local info = Permissions.GetFrameworkInfo(src)
    local mode = Config.PermissionMode or 'any'

    Permissions.Notify(src, ('No permission for %s'):format(action), 'error')

    print(('[radar_trailer] PERMISSION DENIED  action=%s  player=%s (src %s)'):format(action, name, tostring(src)))
    print(('[radar_trailer]   mode=%s  job=%s  framework=%s  isAdmin=%s'):format(
        tostring(mode), tostring(info.job), tostring(info.framework), tostring(info.isAdmin)))
    print(('[radar_trailer]   PoliceJobs: %s'):format(table.concat(Config.PoliceJobs or {}, ', ')))
    for _, id in ipairs(ids) do
        print(('[radar_trailer]   %s'):format(id))
    end
end

function Permissions.Notify(src, msg, typ)
    if src and src > 0 then
        TriggerClientEvent('radar_trailer:client:notify', src, msg, typ or 'info')
    end
end

RegisterNetEvent('radar_trailer:server:checkPermission', function()
    local src = source
    local allowed = Permissions.HasPermission(src)
    TriggerClientEvent('radar_trailer:client:permissionResult', src, allowed)
    if not allowed then
        Permissions.Deny(src, 'radar commands')
    end
end)

-- Debug: /radarpermcheck [id]
RegisterCommand('radarpermcheck', function(src, args)
    if src ~= 0 and not Permissions.HasPermission(src) and not Permissions.IsAdmin(src) then
        return
    end
    local target = tonumber(args[1]) or src
    if target == 0 then
        print('[radar_trailer] Usage: radarpermcheck <serverId>')
        return
    end
    local name = GetPlayerName(target) or '?'
    local info = Permissions.GetFrameworkInfo(target)
    local allowed = Permissions.HasPermission(target)
    local msg = ('[radar_trailer] %s (src %s) allowed=%s job=%s admin=%s mode=%s fw=%s'):format(
        name, target, tostring(allowed), tostring(info.job), tostring(info.isAdmin),
        tostring(Config.PermissionMode), tostring(info.framework))
    print(msg)
    if src > 0 then Permissions.Notify(src, msg, 'info') end
end, false)
