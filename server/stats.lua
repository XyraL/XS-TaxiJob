Stats = {}

local cache = {}

local function blank(citizenid)
    return {
        citizenid = citizenid,
        reputation = 0,
        total_fares = 0,
        total_earned = 0,
        total_distance = 0,
        rating_sum = 0,
        rating_count = 0,
    }
end

function Stats.Load(citizenid)
    if not citizenid then return nil end
    if cache[citizenid] then return cache[citizenid] end

    local row = MySQL.single.await(
        'SELECT citizenid, reputation, total_fares, total_earned, total_distance, rating_sum, rating_count FROM xs_taxi_drivers WHERE citizenid = ?',
        { citizenid })

    if not row then
        MySQL.insert.await('INSERT IGNORE INTO xs_taxi_drivers (citizenid) VALUES (?)', { citizenid })
        row = blank(citizenid)
    end

    row.rating_sum = tonumber(row.rating_sum) or 0
    cache[citizenid] = row
    return row
end

function Stats.Forget(citizenid)
    cache[citizenid] = nil
end

function Stats.Rating(row)
    if not row or (row.rating_count or 0) < 1 then return 5.0 end
    return Text.round(row.rating_sum / row.rating_count, 2)
end

-- The shape the UI and the client state both read.
function Stats.Summary(citizenid)
    local row = Stats.Load(citizenid)
    if not row then return nil end

    local tier, next, progress = Text.tierFor(row.reputation)

    return {
        reputation = row.reputation,
        tier = tier.tier,
        tierLabel = tier.label,
        fareMultiplier = tier.fareMultiplier,
        nextTier = next and { tier = next.tier, label = next.label, at = next.at } or nil,
        progress = Text.round(progress, 3),
        totalFares = row.total_fares,
        totalEarned = row.total_earned,
        totalDistance = row.total_distance,
        rating = Stats.Rating(row),
    }
end

function Stats.AddReputation(citizenid, delta)
    local row = Stats.Load(citizenid)
    if not row then return end

    row.reputation = math.max(0, row.reputation + math.floor(delta))
    MySQL.update.await('UPDATE xs_taxi_drivers SET reputation = ? WHERE citizenid = ?', { row.reputation, citizenid })
end

function Stats.RecordFare(citizenid, fare)
    local row = Stats.Load(citizenid)
    if not row then return end

    local total = math.floor((fare.fare or 0) + (fare.tip or 0))
    local rating = math.max(1.0, math.min(5.0, tonumber(fare.rating) or 5.0))

    row.total_fares = row.total_fares + 1
    row.total_earned = row.total_earned + total
    row.total_distance = row.total_distance + math.floor(fare.distance or 0)
    row.rating_sum = row.rating_sum + rating
    row.rating_count = row.rating_count + 1

    local gained = Config.Reputation.perFare
    if Config.Reputation.ratingScale then
        gained = math.max(1, math.floor(gained * (rating / 5.0) + 0.5))
    end
    row.reputation = row.reputation + gained

    MySQL.update.await([[
        UPDATE xs_taxi_drivers
        SET reputation = ?, total_fares = ?, total_earned = ?, total_distance = ?,
            rating_sum = ?, rating_count = ?
        WHERE citizenid = ?
    ]], { row.reputation, row.total_fares, row.total_earned, row.total_distance,
          row.rating_sum, row.rating_count, citizenid })

    MySQL.insert.await([[
        INSERT INTO xs_taxi_fares
            (citizenid, passenger, kind, pickup_label, dropoff_label, distance, duration, fare, tip, rating)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid, fare.passenger, fare.kind or 'npc',
        fare.pickupLabel or '?', fare.dropoffLabel or '?',
        math.floor(fare.distance or 0), math.floor(fare.duration or 0),
        math.floor(fare.fare or 0), math.floor(fare.tip or 0), rating,
    })

    return gained
end

function Stats.StartShift(citizenid, vehicle)
    return MySQL.insert.await(
        'INSERT INTO xs_taxi_shifts (citizenid, vehicle) VALUES (?, ?)',
        { citizenid, vehicle })
end

function Stats.EndShift(shiftId, totals)
    if not shiftId then return end
    MySQL.update.await([[
        UPDATE xs_taxi_shifts
        SET fares = ?, earned = ?, distance = ?, ended_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { math.floor(totals.fares or 0), math.floor(totals.earned or 0), math.floor(totals.distance or 0), shiftId })
end

function Stats.Recent(citizenid, limit)
    return MySQL.query.await([[
        SELECT pickup_label, dropoff_label, distance, duration, fare, tip, rating, kind, created_at
        FROM xs_taxi_fares WHERE citizenid = ?
        ORDER BY id DESC LIMIT ?
    ]], { citizenid, math.min(25, math.max(1, limit or 10)) }) or {}
end

function Stats.Leaderboard(limit)
    local rows = MySQL.query.await([[
        SELECT citizenid, reputation, total_fares, total_earned, rating_sum, rating_count
        FROM xs_taxi_drivers
        WHERE total_fares > 0
        ORDER BY reputation DESC, total_earned DESC
        LIMIT ?
    ]], { math.min(25, math.max(1, limit or 10)) }) or {}

    for index, row in ipairs(rows) do
        local tier = Text.tierFor(row.reputation)
        rows[index] = {
            rank = index,
            name = Framework.GetNameByCitizenId(row.citizenid),
            reputation = row.reputation,
            tierLabel = tier.label,
            fares = row.total_fares,
            earned = row.total_earned,
            rating = Stats.Rating(row),
        }
    end

    return rows
end
