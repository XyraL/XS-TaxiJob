-- Live switches an admin can flip without touching config.lua or restarting.
-- These are deliberately not persisted: they are for handling a situation now,
-- and a restart should put the server back to what config.lua says.
Admin = {
    settings = {
        hailEnabled = true,
        fareMultiplier = 1.0,
        paused = false,
    },
}

CreateThread(function()
    Wait(0)
    Admin.settings.hailEnabled = Config.Hail.enabled
end)

local function serverTotals()
    local row = MySQL.single.await([[
        SELECT COUNT(*) AS fares, COALESCE(SUM(fare),0) AS earned
        FROM xs_taxi_fares
    ]])

    if not row then return nil end
    return { fares = row.fares or 0, earned = math.floor(row.earned or 0) }
end

local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, Config.AdminAce)
end

local function guard(name, handler)
    lib.callback.register(name, function(src, ...)
        if not isAdmin(src) then
            return { ok = false, error = 'You are not allowed to do that.' }
        end
        return handler(src, ...)
    end)
end

-- The panel needs to know whether to draw the tab. Authority still lives in
-- guard() above, which re-checks every admin callback, so this is only ever a
-- hint about what to show.
Admin.IsAdmin = isAdmin

lib.callback.register('XS-TaxiJob:server:isAdmin', function(src)
    return isAdmin(src)
end)

local function driverRow(src, driver)
    local summary = Stats.Summary(driver.citizenid)
    local fare = driver.fare

    return {
        src = src,
        citizenid = driver.citizenid,
        name = Framework.GetName(src) or driver.citizenid,
        onDuty = driver.onDuty == true,
        vehicle = driver.vehicle and driver.vehicle.label or nil,
        plate = driver.vehicle and (driver.vehicle.assignedPlate or driver.vehicle.plate) or nil,
        personal = driver.vehicle and driver.vehicle.personal == true or false,
        location = driver.location and Locations.Get(driver.location) and Locations.Get(driver.location).name or nil,
        since = driver.startedAt and (os.time() - driver.startedAt) or 0,
        earned = driver.totals and driver.totals.earned or 0,
        fares = driver.totals and driver.totals.fares or 0,
        distance = driver.totals and driver.totals.distance or 0,
        reputation = summary and summary.reputation or 0,
        tier = summary and summary.tierLabel or 'Driver',
        rating = summary and summary.rating or 0,
        fare = fare and {
            id = fare.id,
            kind = fare.kind,
            pickup = fare.pickup and fare.pickup.label,
            dropoff = fare.dropoff and fare.dropoff.label,
            boarded = fare.boardedAt ~= nil,
        } or nil,
    }
end

guard('XS-TaxiJob:server:adminState', function()
    local drivers = {}
    local onDuty, totalEarned, totalFares = 0, 0, 0

    for src, driver in pairs(Drivers) do
        local row = driverRow(src, driver)
        drivers[#drivers + 1] = row

        if row.onDuty then
            onDuty = onDuty + 1
            totalEarned = totalEarned + row.earned
            totalFares = totalFares + row.fares
        end
    end

    table.sort(drivers, function(a, b) return a.earned > b.earned end)

    return {
        ok = true,
        drivers = drivers,
        totals = {
            onDuty = onDuty,
            earnedThisShift = totalEarned,
            faresThisShift = totalFares,
            allTime = serverTotals(),
        },
        settings = Admin.settings,
    }
end)

guard('XS-TaxiJob:server:adminSetReputation', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local target = tonumber(payload.src)
    local amount = tonumber(payload.amount)

    if not target or not amount then return { ok = false, error = 'Pick a driver and an amount.' } end

    local driver = Drivers[target]
    if not driver then return { ok = false, error = 'That driver is not connected.' } end

    Stats.AddReputation(driver.citizenid, amount)
    Framework.Notify(target, ('An admin adjusted your standing by %d.'):format(amount),
        amount >= 0 and 'success' or 'error')

    return { ok = true }
end)

guard('XS-TaxiJob:server:adminEndShift', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local target = tonumber(payload.src)

    local driver = target and Drivers[target]
    if not driver or not driver.onDuty then return { ok = false, error = 'They are not on shift.' } end

    TriggerClientEvent('XS-TaxiJob:client:forceEndShift', target)
    Framework.Notify(target, 'An admin ended your shift.', 'error')

    return { ok = true }
end)

guard('XS-TaxiJob:server:adminClearFare', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local target = tonumber(payload.src)

    local driver = target and Drivers[target]
    if not driver or not driver.fare then return { ok = false, error = 'They have no fare running.' } end

    driver.fare = nil
    TriggerClientEvent('XS-TaxiJob:client:fareCancelled', target)
    Framework.Notify(target, 'An admin cleared your fare.', 'inform')

    return { ok = true }
end)

guard('XS-TaxiJob:server:adminSetting', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local key = payload.key
    if key ~= 'hailEnabled' and key ~= 'fareMultiplier' and key ~= 'paused' then
        return { ok = false, error = 'Unknown setting.' }
    end

    Admin.settings[key] = payload.value
    return { ok = true }
end)

guard('XS-TaxiJob:server:adminWipe', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local citizenid = payload.citizenid

    if not citizenid or citizenid == '' then return { ok = false, error = 'No driver given.' } end

    MySQL.prepare.await('DELETE FROM xs_taxi_drivers WHERE citizenid = ?', { citizenid })
    MySQL.prepare.await('DELETE FROM xs_taxi_fares WHERE citizenid = ?', { citizenid })
    Stats.Forget(citizenid)

    return { ok = true }
end)

guard('XS-TaxiJob:server:adminLocations', function()
    local cabs = {}
    for _, entry in ipairs(Config.Vehicles.list) do
        cabs[#cabs + 1] = { model = entry.model, label = entry.label, tier = entry.tier }
    end
    return { ok = true, locations = Locations.Public(), cabs = cabs }
end)

guard('XS-TaxiJob:server:adminSaveLocation', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local id, err = Locations.Save(payload.id, payload.data)
    if not id then return { ok = false, error = err } end
    return { ok = true, id = id, locations = Locations.Public() }
end)

guard('XS-TaxiJob:server:adminRates', function()
    return { ok = true, rates = Rates.Public() }
end)

guard('XS-TaxiJob:server:adminSaveRates', function(src, payload)
    local rates, err = Rates.Save(type(payload) == 'table' and payload.rates or nil)
    if not rates then return { ok = false, error = err } end
    return { ok = true, rates = rates }
end)

guard('XS-TaxiJob:server:adminResetRates', function()
    return { ok = true, rates = Rates.Reset() }
end)

guard('XS-TaxiJob:server:adminDeleteLocation', function(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local ok, err = Locations.Delete(payload.id)
    if not ok then return { ok = false, error = err } end
    return { ok = true, locations = Locations.Public() }
end)
