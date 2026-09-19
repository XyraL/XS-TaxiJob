local nextFareId = 0

local function pointVec(point)
    return vec3(point.coords.x, point.coords.y, point.coords.z)
end

local function allowedPoints(tier)
    local list = {}
    for _, point in ipairs(Config.Fares.points) do
        if (point.tier or 1) <= tier then list[#list + 1] = point end
    end
    return list
end

local function pickPickup(points, near)
    local candidates = {}
    for _, point in ipairs(points) do
        if #(pointVec(point) - near) <= Config.Fares.searchRadius then
            candidates[#candidates + 1] = point
        end
    end
    -- Nothing close enough: fall back to the whole allowed set rather than
    -- leaving a driver in the county with no work at all.
    if #candidates == 0 then candidates = points end
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

local function pickDropoff(points, pickup)
    local elsewhere, anywhere = {}, {}
    for _, point in ipairs(points) do
        if point.label ~= pickup.label then
            local away = #(pointVec(point) - pointVec(pickup))
            if away >= 400.0 then
                anywhere[#anywhere + 1] = point
                if point.area ~= pickup.area then elsewhere[#elsewhere + 1] = point end
            end
        end
    end

    local pool = #elsewhere > 0 and elsewhere or anywhere
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function isNight()
    local hour = tonumber(os.date('%H')) or 12
    local from, to = Config.Meter.nightBonus.from, Config.Meter.nightBonus.to
    if from <= to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

-- The client tracks the meter for responsiveness, but the numbers it reports
-- are only ever a ceiling. Everything is re-derived here from the two points
-- the server itself chose.
local function settle(driver, fare, reported)
    local straight = fare.straightLine or 0.0
    local duration = math.max(1, math.min(tonumber(reported.duration) or 60, 3 * 60 * 60))
    local waiting = math.max(0, math.min(tonumber(reported.waiting) or 0, duration))
    local rating = math.max(1.0, math.min(5.0, tonumber(reported.rating) or 5.0))

    -- No road vehicle averages 60 m/s, so the time taken caps the distance that
    -- can be claimed. A fixed destination caps it again by its own geometry.
    local distance = math.min(tonumber(reported.distance) or 0.0, duration * 60.0)
    if straight > 0 then
        distance = math.max(straight, math.min(distance, straight * 2.5 + 500.0))
    else
        distance = math.max(0.0, distance)
    end

    local amount = Config.Meter.flagfall
        + (distance / 1000.0) * Config.Meter.perKm
        + (waiting / 60.0) * Config.Meter.perWaitingMinute

    if fare.crossTown then amount = amount * Config.Fares.crossTownBonus end

    -- Decided once, when the fare was built, and sent to the dash with it.
    -- Asking again here would also disagree with the meter on any ride that
    -- happens to cross the boundary.
    if fare.night then amount = amount * Config.Meter.nightBonus.multiplier end
    if fare.kind == 'player' then amount = amount * Config.Hail.playerFareMultiplier end

    amount = amount * (driver.vehicle.rate or 1.0)

    local summary = Stats.Summary(driver.citizenid)
    amount = amount * (summary and summary.fareMultiplier or 1.0)
    amount = amount * ((Admin and Admin.settings.fareMultiplier) or 1.0)

    local total = math.max(Config.Meter.minimumFare, math.floor(amount + 0.5))
    local tipRate = Config.Quality.tips[math.max(1, math.min(5, math.floor(rating + 0.5)))] or 0
    local tip = math.floor(total * tipRate + 0.5)

    return { fare = total, tip = tip, rating = rating, distance = distance, duration = duration }
end

--[[ A point on the map at a random bearing and distance from another.

     Deliberately not snapped to a road here — the server has no road network
     to ask. The client puts it on the nearest one, which moves it by the width
     of a garden at most, and settle() already tolerates far more than that. ]]
local function randomAnchor(from, minAway, maxAway)
    local angle = math.random() * math.pi * 2
    local away = minAway + math.random() * math.max(0.0, maxAway - minAway)

    return vec3(from.x + math.cos(angle) * away, from.y + math.sin(angle) * away, from.z)
end

local function randomRun(near)
    local pickup = randomAnchor(near, 120.0, Config.Fares.searchRadius)
    local dropoff = randomAnchor(pickup, Config.Fares.minTripDistance, Config.Fares.maxTripDistance)

    return {
        coords = vec4(pickup.x, pickup.y, pickup.z, 0.0),
        label = 'the kerb',
        area = 'street',
    }, {
        coords = vec4(dropoff.x, dropoff.y, dropoff.z, 0.0),
        label = 'the drop-off',
        area = 'street',
    }
end

function BuildFare(driver, kind, override)
    local summary = Stats.Summary(driver.citizenid)
    local points = allowedPoints(summary and summary.tier or 1)

    -- Only the named list needs two of them to pick from. A random street
    -- pickup has nothing to choose between.
    if not Config.Fares.randomStreets and #points < 2 then return nil end

    local near = override and override.pickupCoords or vec3(0.0, 0.0, 0.0)

    local pickup, dropoff

    if override and override.pickup then
        pickup = override.pickup
        dropoff = override.dropoff
    elseif Config.Fares.randomStreets then
        pickup, dropoff = randomRun(near)
    else
        pickup = pickPickup(points, near)
        dropoff = pickup and pickDropoff(points, pickup)
    end

    if not pickup or not dropoff then return nil end

    nextFareId = nextFareId + 1

    return {
        id = nextFareId,
        kind = kind or 'npc',
        pickup = {
            x = pickup.coords.x, y = pickup.coords.y, z = pickup.coords.z, w = pickup.coords.w,
            label = pickup.label, area = pickup.area,
        },
        dropoff = {
            x = dropoff.coords.x, y = dropoff.coords.y, z = dropoff.coords.z, w = dropoff.coords.w,
            label = dropoff.label, area = dropoff.area,
        },
        crossTown = pickup.area ~= dropoff.area,
        -- The client snaps these to the road network and renames them after
        -- the street. Named points are already where somebody put them.
        random = pickup.area == 'street' or nil,
        night = isNight(),
        straightLine = #(pointVec(dropoff) - pointVec(pickup)),
        ped = Config.Fares.peds[math.random(#Config.Fares.peds)],
        offeredAt = os.time(),
        passengerSrc = override and override.passengerSrc or nil,
        passengerCitizenId = override and override.passengerCitizenId or nil,
    }
end

lib.callback.register('XS-TaxiJob:server:requestFare', function(src, data)
    if Admin and Admin.settings.paused then
        return { ok = false, error = 'Dispatch is paused. Nothing is being handed out.' }
    end

    local driver = DriverOf(src)
    if not driver or not driver.onDuty then return { ok = false, error = 'You are not signed on.' } end
    if driver.fare then return { ok = false, error = 'You already have a fare.' } end

    -- Asked of the server, not of the client. It only decides where the work
    -- is, so it was never worth much — but there is no reason to take the
    -- client's word for something this side can see.
    local ped = GetPlayerPed(src)
    local near = ped and ped ~= 0 and GetEntityCoords(ped) or vec3(0.0, 0.0, 0.0)

    local fare = BuildFare(driver, 'npc', { pickupCoords = near })
    if not fare then return { ok = false, error = 'No fares available right now.' } end

    driver.fare = fare
    return { ok = true, fare = fare }
end)

RegisterNetEvent('XS-TaxiJob:server:fareBoarded', function(fareId)
    local src = source
    local driver = DriverOf(src)
    if not driver or not driver.fare or driver.fare.id ~= fareId then return end

    driver.fare.boardedAt = os.time()

    if driver.fare.passengerSrc then
        Phone.Notify(driver.fare.passengerSrc, 'Taxi', 'Your driver has picked you up.')
    end
end)

lib.callback.register('XS-TaxiJob:server:completeFare', function(src, reported)
    local driver = DriverOf(src)
    if not driver or not driver.fare then return { ok = false, error = 'No fare running.' } end
    if type(reported) ~= 'table' or reported.fareId ~= driver.fare.id then
        return { ok = false, error = 'That fare is not the one you are running.' }
    end

    local fare = driver.fare
    if not fare.boardedAt then return { ok = false, error = 'Nobody has got in yet.' } end

    -- A trip to a fixed destination cannot take less time than the straight
    -- line allows at a speed no road vehicle reaches, which rules out
    -- teleporting to the drop-off. Hailed rides have no destination to skip to.
    local elapsed = os.time() - fare.boardedAt
    if (fare.straightLine or 0) > 0 and elapsed < (fare.straightLine / 60.0) then
        return { ok = false, error = 'That trip was too quick to be real.' }
    end

    local settled = settle(driver, fare, reported)

    -- Player fares are paid by the passenger. If they cannot cover it the
    -- driver still gets the fare - chasing the money is a roleplay problem,
    -- not a script one.
    if fare.kind == 'player' and fare.passengerSrc then
        local owed = settled.fare + settled.tip
        if Framework.GetMoney(fare.passengerSrc, Config.Meter.account) >= owed then
            Framework.RemoveMoney(fare.passengerSrc, Config.Meter.account, owed, 'XS-TaxiJob:fare')
            Phone.Notify(fare.passengerSrc, 'Taxi', ('You paid %s for your ride.'):format(Text.money(owed)))
        else
            settled.tip = 0
            Phone.Notify(fare.passengerSrc, 'Taxi', 'You could not cover the fare.')
        end
    end

    local payout = settled.fare + settled.tip
    Framework.AddMoney(src, Config.Meter.account, payout, 'XS-TaxiJob:fare')

    local gained = Stats.RecordFare(driver.citizenid, {
        passenger = fare.passengerCitizenId,
        kind = fare.kind,
        pickupLabel = fare.pickup.label,
        dropoffLabel = fare.dropoff.label,
        distance = settled.distance,
        duration = settled.duration,
        fare = settled.fare,
        tip = settled.tip,
        rating = settled.rating,
    })

    driver.totals.fares = driver.totals.fares + 1
    driver.totals.earned = driver.totals.earned + payout
    driver.totals.distance = driver.totals.distance + math.floor(settled.distance)
    driver.fare = nil

    return {
        ok = true,
        fare = settled.fare,
        tip = settled.tip,
        rating = settled.rating,
        reputation = gained,
        totals = driver.totals,
        stats = Stats.Summary(driver.citizenid),
    }
end)

lib.callback.register('XS-TaxiJob:server:cancelFare', function(src, reason)
    local driver = DriverOf(src)
    if not driver or not driver.fare then return { ok = false, error = 'No fare running.' } end

    local fare = driver.fare
    driver.fare = nil

    -- Only a driver walking away from a boarded passenger costs reputation.
    -- Timeouts and unreachable pickups are the job, not a failure.
    if reason == 'abandoned' and fare.boardedAt then
        Stats.AddReputation(driver.citizenid, -Config.Reputation.cancelPenalty)
    end

    if fare.passengerSrc then
        Phone.Notify(fare.passengerSrc, 'Taxi', 'Your driver dropped the job. Try hailing another.')
    end

    return { ok = true, stats = Stats.Summary(driver.citizenid) }
end)
