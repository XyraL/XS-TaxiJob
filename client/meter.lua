Meter = {
    running = false,
    distance = 0.0,
    waiting = 0.0,
    startedAt = 0,
    rating = 5.0,
    penalties = {},
}

local loopRunning = false
local lastCoords = nil
local lastBodyHealth = nil
local speedingSince = nil

local function penalise(kind, amount)
    Meter.rating = math.max(1.0, Meter.rating - amount)
    Meter.penalties[kind] = (Meter.penalties[kind] or 0) + 1
end

function ResetMeter()
    Meter.running = false
    Meter.distance = 0.0
    Meter.waiting = 0.0
    Meter.startedAt = 0
    Meter.rating = 5.0
    Meter.penalties = {}
    -- Cleared with everything else, or the next passenger is measured against
    -- the last one's health and the penalty never fires again.
    Meter.passengerHealth = nil
    lastCoords = nil
    lastBodyHealth = nil
    speedingSince = nil
end

function StartMeter()
    ResetMeter()
    Meter.running = true
    Meter.startedAt = GetGameTimer()
    lastCoords = GetEntityCoords(PlayerPedId())
    lastBodyHealth = CabExists() and GetVehicleBodyHealth(Taxi.cab) or nil
end

function StopMeter()
    Meter.running = false
end

function MeterElapsed()
    if Meter.startedAt == 0 then return 0 end
    return math.floor((GetGameTimer() - Meter.startedAt) / 1000)
end

-- Mirrors the server's pricing so the number on the dash is the number that
-- lands in the driver's pocket.
function MeterAmount()
    if not Meter.running and Meter.distance == 0 then return 0 end

    local amount = Config.Meter.flagfall
        + (Meter.distance / 1000.0) * Config.Meter.perKm
        + (Meter.waiting / 60.0) * Config.Meter.perWaitingMinute

    if Taxi.fare and Taxi.fare.crossTown then amount = amount * Config.Fares.crossTownBonus end

    -- The server decides this when it builds the fare and sends it down.
    -- Working it out here off the in-game clock, while the server read the
    -- host machine's, is why the dash and the payout disagreed.
    if Taxi.fare and Taxi.fare.night then
        amount = amount * Config.Meter.nightBonus.multiplier
    end

    amount = amount * ((Taxi.vehicle and Taxi.vehicle.rate) or 1.0)
    amount = amount * ((Taxi.stats and Taxi.stats.fareMultiplier) or 1.0)

    return math.max(Config.Meter.minimumFare, math.floor(amount + 0.5))
end

local function trackQuality(speed)
    if not CabExists() then return end

    if lastBodyHealth then
        local health = GetVehicleBodyHealth(Taxi.cab)
        if health < (lastBodyHealth - 12.0) then
            penalise('collision', Config.Quality.penalties.collision)
        end
        lastBodyHealth = health
    else
        lastBodyHealth = GetVehicleBodyHealth(Taxi.cab)
    end

    if speed > Config.Quality.speedLimit then
        speedingSince = speedingSince or GetGameTimer()
        if (GetGameTimer() - speedingSince) > (Config.Quality.speedGracePeriod * 1000) then
            speedingSince = GetGameTimer()
            penalise('speeding', Config.Quality.penalties.speeding)
        end
    else
        speedingSince = nil
    end

    if not IsVehicleOnAllWheels(Taxi.cab) and speed < 1.0 then
        if not Meter.penalties.cabFlipped then
            penalise('cabFlipped', Config.Quality.penalties.cabFlipped)
        end
    end

    --[[ Measured against the state they got in, not against a number.

         A spawned passenger is always on 200, so a flat threshold of 150 has
         always worked for them. It stops working the moment the passenger is
         somebody who was already walking around: the world leaves ambient
         pedestrians on whatever health they happen to have, and one who got in
         on 120 would cost the driver the heaviest penalty in the list before
         the cab had moved. ]]
    if Taxi.fare and Taxi.fare.passengerPed and DoesEntityExist(Taxi.fare.passengerPed) then
        local health = GetEntityHealth(Taxi.fare.passengerPed)

        Meter.passengerHealth = Meter.passengerHealth or health

        if health < (Meter.passengerHealth - 40) and not Meter.penalties.passengerHurt then
            penalise('passengerHurt', Config.Quality.penalties.passengerHurt)
        end
    end
end

function StartMeterLoop()
    if loopRunning then return end
    loopRunning = true

    CreateThread(function()
        while loopRunning and Taxi.onDuty do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local speed = CabExists() and GetEntitySpeed(Taxi.cab) or 0.0

            if Meter.running then
                if lastCoords then
                    local moved = #(coords - lastCoords)
                    -- Ignore teleport-sized jumps so a respawn cannot inflate the fare.
                    if moved < 120.0 then Meter.distance = Meter.distance + moved end
                end

                if speed < Config.Meter.waitingSpeedThreshold then
                    Meter.waiting = Meter.waiting + 0.5
                end

                trackQuality(speed)
            end

            lastCoords = coords

            SendNUIMessage({
                action = 'meter',
                data = {
                    onDuty = Taxi.onDuty,
                    running = Meter.running,
                    hasFare = Taxi.fare ~= nil,
                    stage = Taxi.fare and Taxi.fare.stage or nil,
                    amount = Meter.running and MeterAmount() or 0,
                    distance = Meter.distance,
                    elapsed = MeterElapsed(),
                    rating = Text.round(Meter.rating, 1),
                    pickup = Taxi.fare and Taxi.fare.pickup and Taxi.fare.pickup.label or nil,
                    dropoff = Taxi.fare and Taxi.fare.dropoff and Taxi.fare.dropoff.label or nil,
                    openEnded = Taxi.fare and Taxi.fare.openEnded or false,

                    -- What the unit needs to say something different in each
                    -- state. All of it already existed somewhere; none of it
                    -- was ever sent.
                    kind = Taxi.fare and Taxi.fare.kind or nil,
                    night = Taxi.fare and Taxi.fare.night or false,
                    crossTown = Taxi.fare and Taxi.fare.crossTown or false,
                    flagfall = Config.Meter.flagfall,
                    pickupIn = pickupSecondsLeft(),
                    away = distanceToTarget(),
                    totals = Taxi.totals,
                    vehicle = Taxi.vehicle and Taxi.vehicle.label or nil,
                },
            })

            Wait(500)
        end

        loopRunning = false
        SendNUIMessage({ action = 'meter', data = { onDuty = false } })
    end)
end

-- Seconds left to reach the pickup, or nil when that is not what is
-- happening. The meter puts this in the big slot, so it is the thing the
-- driver is racing rather than a deadline they cannot see.
function pickupSecondsLeft()
    local fare = Taxi.fare
    if not fare or fare.stage ~= 'toPickup' or not fare.deadline then return nil end

    return math.max(0, math.floor((fare.deadline - GetGameTimer()) / 1000))
end

-- How far the cab is from whatever it is heading for.
function distanceToTarget()
    local fare = Taxi.fare
    if not fare then return nil end

    local target = fare.stage == 'riding' and not fare.openEnded and fare.dropoff or fare.pickup
    if not target then return nil end

    return #(GetEntityCoords(PlayerPedId()) - vec3(target.x, target.y, target.z))
end

function StopMeterLoop()
    loopRunning = false
    ResetMeter()
    SendNUIMessage({ action = 'meter', data = { onDuty = false } })
end
