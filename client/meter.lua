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

    local night = Config.Meter.nightBonus
    local hour = GetClockHours()
    local isNight

    if night.from <= night.to then
        isNight = hour >= night.from and hour < night.to
    else
        isNight = hour >= night.from or hour < night.to
    end

    if isNight then amount = amount * night.multiplier end

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

    if Taxi.fare and Taxi.fare.passengerPed and DoesEntityExist(Taxi.fare.passengerPed) then
        local health = GetEntityHealth(Taxi.fare.passengerPed)
        if health < 150 and not Meter.penalties.passengerHurt then
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

function StopMeterLoop()
    loopRunning = false
    ResetMeter()
    SendNUIMessage({ action = 'meter', data = { onDuty = false } })
end
