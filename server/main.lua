Drivers = {}

local slotsInUse = {}
local seenCitizenIds = {}

local function vehicleByModel(model)
    for _, entry in ipairs(Config.Vehicles.list) do
        if entry.model == model then return entry end
    end
    return nil
end

local function freeSlot()
    for index, coords in ipairs(Config.Depot.cabSpawns) do
        if not slotsInUse[index] then return index, coords end
    end
    return nil
end

local function releaseSlot(index)
    if index then slotsInUse[index] = nil end
end

function IsOnDuty(src)
    local driver = Drivers[src]
    return driver ~= nil and driver.onDuty == true
end

function DriverOf(src)
    return Drivers[src]
end

-- Called from every path that ends a shift so the registry, the slot and the
-- database row are always cleaned up together.
local function closeShift(src, reason)
    local driver = Drivers[src]
    if not driver then return end

    if driver.fare and Config.Shift.penaliseAbandon and reason ~= 'clean' then
        Stats.AddReputation(driver.citizenid, -Config.Reputation.cancelPenalty)
    end

    Stats.EndShift(driver.shiftId, driver.totals)
    releaseSlot(driver.slot)
    Drivers[src] = nil
end

lib.callback.register('XS-TaxiJob:server:getState', function(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end

    seenCitizenIds[src] = citizenid

    local summary = Stats.Summary(citizenid)
    if not summary then return nil end

    local vehicles = {}
    for _, entry in ipairs(Config.Vehicles.list) do
        vehicles[#vehicles + 1] = {
            model = entry.model,
            label = entry.label,
            tier = entry.tier,
            rate = entry.rate,
            locked = summary.tier < entry.tier,
        }
    end

    local driver = Drivers[src]

    return {
        onDuty = driver ~= nil and driver.onDuty or false,
        vehicle = driver and driver.vehicle or nil,
        totals = driver and driver.totals or { fares = 0, earned = 0, distance = 0 },
        hasFare = driver ~= nil and driver.fare ~= nil,
        deposit = Config.Vehicles.deposit,
        stats = summary,
        vehicles = vehicles,
        recent = Stats.Recent(citizenid, 10),
        leaderboard = Stats.Leaderboard(10),
        hailEnabled = Config.Hail.enabled,
    }
end)

lib.callback.register('XS-TaxiJob:server:startShift', function(src, model)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return { ok = false, error = 'No character loaded.' } end
    if Drivers[src] then return { ok = false, error = 'You are already signed on.' } end

    local entry = vehicleByModel(model)
    if not entry then return { ok = false, error = 'That cab is not on the roster.' } end

    local summary = Stats.Summary(citizenid)
    if summary.tier < entry.tier then
        return { ok = false, error = ('The %s needs tier %d. You are tier %d.'):format(entry.label, entry.tier, summary.tier) }
    end

    if Framework.GetMoney(src, Config.Meter.account) < Config.Vehicles.deposit then
        return { ok = false, error = ('You need %s for the deposit.'):format(Text.money(Config.Vehicles.deposit)) }
    end

    local slot, coords = freeSlot()
    if not slot then return { ok = false, error = 'Every cab bay is occupied. Try again shortly.' } end

    if not Framework.RemoveMoney(src, Config.Meter.account, Config.Vehicles.deposit, 'XS-TaxiJob:deposit') then
        return { ok = false, error = 'Could not take the deposit.' }
    end

    slotsInUse[slot] = src

    Drivers[src] = {
        citizenid = citizenid,
        onDuty = true,
        slot = slot,
        shiftId = Stats.StartShift(citizenid, entry.model),
        startedAt = os.time(),
        totals = { fares = 0, earned = 0, distance = 0 },
        fare = nil,
        vehicle = {
            model = entry.model,
            label = entry.label,
            rate = entry.rate,
            plate = entry.plate,
            netId = nil,
        },
    }

    return {
        ok = true,
        spawn = { x = coords.x, y = coords.y, z = coords.z, w = coords.w },
        vehicle = Drivers[src].vehicle,
        deposit = Config.Vehicles.deposit,
        stats = summary,
    }
end)

RegisterNetEvent('XS-TaxiJob:server:registerCab', function(netId)
    local src = source
    local driver = Drivers[src]
    if not driver or type(netId) ~= 'number' then return end
    driver.vehicle.netId = netId

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 then Keys.GiveServer(src, vehicle) end
end)

lib.callback.register('XS-TaxiJob:server:endShift', function(src, data)
    local driver = Drivers[src]
    if not driver then return { ok = false, error = 'You are not signed on.' } end

    local returned = type(data) == 'table' and data.returned == true
    local bodyHealth = type(data) == 'table' and tonumber(data.bodyHealth) or 1000.0
    local refund = 0
    local fee = 0

    if returned then
        local damage = math.max(0.0, math.min(1.0, (1000.0 - bodyHealth) / 1000.0))
        fee = math.floor(Config.Vehicles.deposit * damage * Config.Vehicles.damageFeeRate)
        refund = math.max(0, Config.Vehicles.deposit - fee)
        if refund > 0 then
            Framework.AddMoney(src, Config.Meter.account, refund, 'XS-TaxiJob:depositRefund')
        end
    end

    local summary = {
        fares = driver.totals.fares,
        earned = driver.totals.earned,
        distance = driver.totals.distance,
        minutes = math.floor((os.time() - driver.startedAt) / 60),
        refund = refund,
        damageFee = fee,
        abandoned = driver.fare ~= nil,
    }

    closeShift(src, driver.fare and 'abandoned' or 'clean')

    summary.stats = Stats.Summary(Framework.GetCitizenId(src))
    return { ok = true, summary = summary }
end)

lib.callback.register('XS-TaxiJob:server:leaderboard', function(src)
    return Stats.Leaderboard(15)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = Drivers[src] and Drivers[src].citizenid or seenCitizenIds[src]

    if Drivers[src] then closeShift(src, 'dropped') end

    -- Every terminal visit loads a stats row into the cache. Without this the
    -- cache only ever grows over a long uptime.
    if citizenid then Stats.Forget(citizenid) end
    seenCitizenIds[src] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, driver in pairs(Drivers) do
        Stats.EndShift(driver.shiftId, driver.totals)
        Drivers[src] = nil
    end
end)

CreateThread(function()
    local file = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not file then return end
    for statement in file:gmatch('[^;]+') do
        if statement:match('%S') then MySQL.query.await(statement) end
    end
end)
