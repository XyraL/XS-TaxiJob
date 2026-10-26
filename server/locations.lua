Locations = { list = {}, byId = {}, ready = false }

local MAX_BAYS = 16
local NAME_MAX = 48

local function num(value, low, high, fallback)
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    if low and value < low then value = low end
    if high and value > high then value = high end
    return value
end

local function point(raw)
    if type(raw) ~= 'table' then return nil end
    local x, y, z = tonumber(raw.x), tonumber(raw.y), tonumber(raw.z)
    if not x or not y or not z then return nil end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or z < -200 or z > 2500 then return nil end
    return {
        x = math.floor(x * 100 + 0.5) / 100,
        y = math.floor(y * 100 + 0.5) / 100,
        z = math.floor(z * 100 + 0.5) / 100,
        w = math.floor((num(raw.w, -360, 720, 0.0) % 360) * 100 + 0.5) / 100,
    }
end

local function text(raw, max, pattern)
    if type(raw) ~= 'string' and type(raw) ~= 'number' then return '' end
    local value = tostring(raw):gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
    value = value:sub(1, max)
    if pattern and value ~= '' and not value:match(pattern) then return '' end
    return value
end

local function knownCab(model)
    for _, entry in ipairs(Config.Vehicles.list) do
        if entry.model == model then return true end
    end
    return false
end

function Locations.Clean(raw)
    if type(raw) ~= 'table' then return nil, 'Nothing to save.' end

    local name = text(raw.name, NAME_MAX)
    if name == '' then return nil, 'Give the depot a name.' end

    local desk = point(raw.desk)
    if not desk then return nil, 'Set where the dispatcher stands.' end

    local blip = type(raw.blip) == 'table' and raw.blip or {}
    local dispatcher = type(raw.dispatcher) == 'table' and raw.dispatcher or {}

    local bays = {}
    for _, bay in ipairs(type(raw.bays) == 'table' and raw.bays or {}) do
        local clean = point(bay)
        if clean and #bays < MAX_BAYS then bays[#bays + 1] = clean end
    end

    local personal = raw.personal == true
    if #bays == 0 and not personal then
        return nil, 'Add at least one cab bay, or let drivers use their own cars.'
    end

    local cabs
    if type(raw.cabs) == 'table' then
        cabs = {}
        for _, model in ipairs(raw.cabs) do
            if type(model) == 'string' and knownCab(model) then cabs[#cabs + 1] = model end
        end
        if #cabs == 0 and not personal then return nil, 'Let this depot rent at least one cab.' end
    end

    return {
        name = name,
        desk = desk,
        blip = {
            show = blip.show ~= false,
            sprite = math.floor(num(blip.sprite, 1, 900, 198)),
            color = math.floor(num(blip.color, 0, 85, 5)),
            scale = math.floor(num(blip.scale, 0.4, 1.5, 0.75) * 100 + 0.5) / 100,
        },
        dispatcher = {
            ped = dispatcher.ped ~= false,
            model = text(dispatcher.model, 40, '^[%w_]+$') ~= '' and text(dispatcher.model, 40) or Config.Depot.dispatcher.model,
            scenario = text(dispatcher.scenario, 64, '^[%w_]+$') ~= '' and text(dispatcher.scenario, 64) or Config.Depot.dispatcher.scenario,
        },
        bays = bays,
        personal = personal,
        job = text(raw.job, 32, '^[%w_%-]+$'),
        cabs = cabs,
    }
end

local function public(entry)
    local data = entry.data
    return {
        id = entry.id,
        name = entry.name,
        desk = data.desk,
        blip = data.blip,
        dispatcher = data.dispatcher,
        bays = data.bays,
        personal = data.personal == true,
        job = data.job or '',
        cabs = data.cabs,
    }
end

function Locations.Public()
    local out = {}
    for _, entry in ipairs(Locations.list) do out[#out + 1] = public(entry) end
    return out
end

function Locations.Get(id)
    return Locations.byId[tonumber(id) or -1]
end

function Locations.Desk(entry)
    local d = entry.data.desk
    return vec3(d.x, d.y, d.z)
end

function Locations.Near(coords, range)
    local best, bestAway
    for _, entry in ipairs(Locations.list) do
        local away = #(coords - Locations.Desk(entry))
        if away <= (range or Config.Depot.useRange) and (not bestAway or away < bestAway) then
            best, bestAway = entry, away
        end
    end
    return best
end

function Locations.Nearest(coords)
    local best, bestAway
    for _, entry in ipairs(Locations.list) do
        local away = #(coords - Locations.Desk(entry))
        if not bestAway or away < bestAway then best, bestAway = entry, away end
    end
    return best, bestAway
end

function Locations.AllowsCab(entry, model)
    local cabs = entry.data.cabs
    if not cabs then return true end
    for _, allowed in ipairs(cabs) do
        if allowed == model then return true end
    end
    return false
end

function Locations.Job(entry)
    local job = entry.data.job
    if job and job ~= '' then return job end
    return Config.Depot.requiredJob or false
end

local function index()
    Locations.byId = {}
    for _, entry in ipairs(Locations.list) do Locations.byId[entry.id] = entry end
end

local function sync()
    TriggerClientEvent('XS-TaxiJob:client:locations', -1, Locations.Public())
end

local function fromConfig()
    local depot = Config.Depot
    local first = depot.first
    local bays = {}
    local desk, blip, name

    if first then
        name = first.name
        desk = first.desk
        blip = first.blip or {}
        for _, bay in ipairs(first.bays or {}) do
            bays[#bays + 1] = { x = bay.x, y = bay.y, z = bay.z, w = bay.w }
        end
    else
        name = 'Downtown Cab Co.'
        desk = (depot.dispatcher and depot.dispatcher.coords) or (depot.terminal and depot.terminal.coords)
        blip = depot.blip or {}
        for _, spawn in ipairs(depot.cabSpawns or {}) do
            bays[#bays + 1] = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }
        end
    end

    if not desk then return nil end

    return Locations.Clean({
        name = name or 'Taxi Depot',
        desk = { x = desk.x, y = desk.y, z = desk.z, w = desk.w },
        blip = { show = true, sprite = blip.sprite, color = blip.color, scale = blip.scale },
        dispatcher = {
            ped = not (depot.dispatcher and depot.dispatcher.enabled == false),
            model = depot.dispatcher and depot.dispatcher.model,
            scenario = depot.dispatcher and depot.dispatcher.scenario,
        },
        bays = bays,
        personal = false,
        job = '',
    })
end

function Locations.Load()
    local rows = MySQL.query.await('SELECT id, name, data FROM xs_taxi_locations ORDER BY id ASC') or {}

    if #rows == 0 then
        local seed = fromConfig()
        if seed then
            local id = MySQL.insert.await('INSERT INTO xs_taxi_locations (name, data) VALUES (?, ?)',
                { seed.name, json.encode(seed) })
            rows = { { id = id, name = seed.name, data = json.encode(seed) } }
            print('[XS-TaxiJob] Created the first depot from config.lua. Edit it in game from the tablet.')
        end
    end

    Locations.list = {}
    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.data or '')
        local clean = ok and type(data) == 'table' and Locations.Clean(data)
        if clean and row.id then
            Locations.list[#Locations.list + 1] = { id = row.id, name = clean.name, data = clean }
        else
            print(('^3[XS-TaxiJob]^0 depot %s has unreadable data and was skipped.'):format(tostring(row.id)))
        end
    end

    index()
    Locations.ready = true
    sync()
end

function Locations.Save(id, raw)
    local clean, err = Locations.Clean(raw)
    if not clean then return nil, err end

    id = tonumber(id)
    if id and Locations.byId[id] then
        MySQL.update.await('UPDATE xs_taxi_locations SET name = ?, data = ? WHERE id = ?',
            { clean.name, json.encode(clean), id })
        local entry = Locations.byId[id]
        entry.name = clean.name
        entry.data = clean
    else
        id = MySQL.insert.await('INSERT INTO xs_taxi_locations (name, data) VALUES (?, ?)',
            { clean.name, json.encode(clean) })
        if not id then return nil, 'The database did not take it.' end
        Locations.list[#Locations.list + 1] = { id = id, name = clean.name, data = clean }
    end

    index()
    sync()
    return id
end

function Locations.Delete(id)
    id = tonumber(id)
    if not id or not Locations.byId[id] then return false, 'That depot is gone already.' end
    if #Locations.list <= 1 then return false, 'Keep at least one depot.' end

    MySQL.update.await('DELETE FROM xs_taxi_locations WHERE id = ?', { id })

    for i, entry in ipairs(Locations.list) do
        if entry.id == id then
            table.remove(Locations.list, i)
            break
        end
    end

    index()
    sync()
    return true
end

lib.callback.register('XS-TaxiJob:server:locations', function()
    return Locations.Public()
end)

exports('GetLocations', function()
    return Locations.Public()
end)

CreateThread(function()
    while not TaxiSchemaReady do Wait(100) end
    Locations.Load()
end)
