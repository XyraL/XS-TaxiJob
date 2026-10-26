Rates = {}

local LIMITS = {
    flagfall         = { 0, 100000 },
    perKm            = { 0, 100000 },
    perWaitingMinute = { 0, 10000 },
    minimumFare      = { 0, 100000 },
    night            = { 0.1, 10 },
    crossTown        = { 0.1, 10 },
    player           = { 0.1, 10 },
    ownCar           = { 0.1, 10 },
    deposit          = { 0, 1000000 },
    damageFee        = { 0, 1 },
}

local saved = false

local function clamp(value, limit, fallback)
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    value = math.floor(value * 10000 + 0.5) / 10000
    return math.max(limit[1], math.min(limit[2], value))
end

local function current()
    local tips, cabs, tiers = {}, {}, {}
    for stars = 1, 5 do tips[tostring(stars)] = Config.Quality.tips[stars] or 0 end
    for _, entry in ipairs(Config.Vehicles.list) do cabs[entry.model] = entry.rate or 1.0 end
    for _, tier in ipairs(Config.Reputation.tiers) do tiers[tostring(tier.tier)] = tier.fareMultiplier or 1.0 end

    return {
        flagfall = Config.Meter.flagfall,
        perKm = Config.Meter.perKm,
        perWaitingMinute = Config.Meter.perWaitingMinute,
        minimumFare = Config.Meter.minimumFare,
        night = Config.Meter.nightBonus.multiplier,
        crossTown = Config.Fares.crossTownBonus,
        player = Config.Hail.playerFareMultiplier,
        ownCar = (Config.PersonalVehicles and Config.PersonalVehicles.rate) or 1.0,
        deposit = Config.Vehicles.deposit,
        damageFee = Config.Vehicles.damageFeeRate,
        tips = tips,
        cabs = cabs,
        tiers = tiers,
    }
end

local defaults = current()

function Rates.Clean(raw)
    if type(raw) ~= 'table' then return nil, 'Nothing to save.' end

    local base = current()
    local out = { tips = {}, cabs = {}, tiers = {} }

    for key, limit in pairs(LIMITS) do
        out[key] = clamp(raw[key], limit, base[key])
    end
    out.deposit = math.floor(out.deposit)

    local tips = type(raw.tips) == 'table' and raw.tips or {}
    local cabs = type(raw.cabs) == 'table' and raw.cabs or {}
    local tiers = type(raw.tiers) == 'table' and raw.tiers or {}

    for stars = 1, 5 do
        local key = tostring(stars)
        out.tips[key] = clamp(tips[key] or tips[stars], { 0, 1 }, base.tips[key])
    end
    for model, rate in pairs(base.cabs) do
        out.cabs[model] = clamp(cabs[model], { 0.1, 10 }, rate)
    end
    for key, rate in pairs(base.tiers) do
        out.tiers[key] = clamp(tiers[key] or tiers[tonumber(key)], { 0.1, 10 }, rate)
    end

    return out
end

local function apply(v)
    Config.Meter.flagfall = v.flagfall
    Config.Meter.perKm = v.perKm
    Config.Meter.perWaitingMinute = v.perWaitingMinute
    Config.Meter.minimumFare = v.minimumFare
    Config.Meter.nightBonus.multiplier = v.night
    Config.Fares.crossTownBonus = v.crossTown
    Config.Hail.playerFareMultiplier = v.player
    Config.PersonalVehicles = Config.PersonalVehicles or {}
    Config.PersonalVehicles.rate = v.ownCar
    Config.Vehicles.deposit = v.deposit
    Config.Vehicles.damageFeeRate = v.damageFee

    for stars = 1, 5 do
        Config.Quality.tips[stars] = v.tips[tostring(stars)] or Config.Quality.tips[stars]
    end
    for _, entry in ipairs(Config.Vehicles.list) do
        entry.rate = v.cabs[entry.model] or entry.rate
    end
    for _, tier in ipairs(Config.Reputation.tiers) do
        tier.fareMultiplier = v.tiers[tostring(tier.tier)] or tier.fareMultiplier
    end

    for _, driver in pairs(Drivers) do
        local vehicle = driver.vehicle
        if vehicle then
            vehicle.rate = vehicle.personal and v.ownCar or (v.cabs[vehicle.model] or vehicle.rate)
        end
    end
end

function Rates.Public()
    local out = current()
    local cabs, tiers = {}, {}

    for _, entry in ipairs(Config.Vehicles.list) do
        cabs[#cabs + 1] = { model = entry.model, label = entry.label, tier = entry.tier, rate = entry.rate or 1.0 }
    end
    for _, tier in ipairs(Config.Reputation.tiers) do
        tiers[#tiers + 1] = { tier = tier.tier, label = tier.label, at = tier.at, rate = tier.fareMultiplier or 1.0 }
    end

    out.cabList = cabs
    out.tierList = tiers
    out.nightFrom = Config.Meter.nightBonus.from
    out.nightTo = Config.Meter.nightBonus.to
    out.saved = saved
    return out
end

function Rates.ForFare(driver)
    local summary = Stats.Summary(driver.citizenid)
    return {
        flagfall = Config.Meter.flagfall,
        perKm = Config.Meter.perKm,
        perWaitingMinute = Config.Meter.perWaitingMinute,
        minimumFare = Config.Meter.minimumFare,
        night = Config.Meter.nightBonus.multiplier,
        crossTown = Config.Fares.crossTownBonus,
        cab = driver.vehicle and driver.vehicle.rate or 1.0,
        tier = summary and summary.fareMultiplier or 1.0,
    }
end

function Rates.Save(raw)
    local clean, err = Rates.Clean(raw)
    if not clean then return nil, err end

    MySQL.query.await([[
        INSERT INTO xs_taxi_settings (name, data) VALUES ('rates', ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)
    ]], { json.encode(clean) })

    apply(clean)
    saved = true
    return Rates.Public()
end

function Rates.Reset()
    MySQL.query.await("DELETE FROM xs_taxi_settings WHERE name = 'rates'")
    apply(defaults)
    saved = false
    return Rates.Public()
end

CreateThread(function()
    while not TaxiSchemaReady do Wait(100) end

    local row = MySQL.scalar.await("SELECT data FROM xs_taxi_settings WHERE name = 'rates'")
    if not row then return end

    local ok, decoded = pcall(json.decode, row)
    local clean = ok and Rates.Clean(decoded)
    if not clean then
        print('^3[XS-TaxiJob]^0 the saved rates could not be read, so config.lua rates are in use.')
        return
    end

    apply(clean)
    saved = true
end)
