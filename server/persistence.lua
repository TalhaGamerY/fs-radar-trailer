Persistence = {}

local DATA_FILE = 'data/radars.json'
local radars = {} -- [id] = radarData
local nextId = 1

local function GenerateId()
    while radars[nextId] do
        nextId = nextId + 1
    end
    local id = nextId
    nextId = nextId + 1
    return id
end

function Persistence.Load()
    radars = {}
    nextId = 1

    local raw = LoadResourceFile(GetCurrentResourceName(), DATA_FILE)
    if not raw or raw == '' or raw == '[]' then
        print('[radar_trailer] No saved radars (empty or missing file)')
        return
    end

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        print('[radar_trailer] WARNING: radars.json is corrupted – starting empty')
        return
    end

    local count = 0
    for _, r in ipairs(data) do
        if type(r) == 'table' and r.id and r.coords and r.coords.x then
            local id = tonumber(r.id)
            if id and id > 0 then
                -- Re-validate so old / partial data cannot crash runtime
                local clean = Utils.ValidateRadarData(r, Config.Defaults)
                clean.id = id
                clean.coords = r.coords
                clean.heading = tonumber(r.heading) or 0.0
                radars[id] = clean
                if id >= nextId then nextId = id + 1 end
                count = count + 1
            end
        end
    end
    print(('[radar_trailer] Loaded %d radar(s) from disk'):format(count))
end

function Persistence.Save()
    local list = {}
    for _, r in pairs(radars) do
        list[#list + 1] = r
    end
    table.sort(list, function(a, b) return a.id < b.id end)

    local ok, encoded = pcall(json.encode, list)
    if not ok or not encoded then
        print('[radar_trailer] ERROR: failed to encode radars.json')
        return
    end
    SaveResourceFile(GetCurrentResourceName(), DATA_FILE, encoded, -1)
end

function Persistence.GetAll()
    return radars
end

function Persistence.Get(id)
    return radars[id]
end

function Persistence.Create(data)
    local id = GenerateId()
    data.id = id
    radars[id] = data
    Persistence.Save()
    return id
end

function Persistence.Update(id, data)
    if not radars[id] then return false end
    data.id = id
    radars[id] = data
    Persistence.Save()
    return true
end

function Persistence.Delete(id)
    if not radars[id] then return false end
    radars[id] = nil
    Persistence.Save()
    return true
end

function Persistence.Reload()
    Persistence.Load()
end
