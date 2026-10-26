Rides = {}

local requests = {}
local cooldowns = {}
local nextRequestId = 0

local function fail(message)
    return { ok = false, error = message }
end

local function pendingFor(src)
    for id, request in pairs(requests) do
        if request.src == src then return id, request end
    end
    return nil
end

local function acceptedFor(src)
    for driverSrc, driver in pairs(Drivers) do
        local fare = driver.fare
        if fare and fare.passengerSrc == src then return driverSrc, driver, fare end
    end
    return nil
end

function Rides.Status(src)
    local id, request = pendingFor(src)
    if id then
        local waiting = 0
        for _ in pairs(request.offered) do waiting = waiting + 1 end
        return {
            state = 'waiting',
            id = id,
            drivers = waiting,
            expiresIn = math.max(0, request.expiresAt - os.time()),
        }
    end

    local driverSrc, _, fare = acceptedFor(src)
    if driverSrc then
        return {
            state = fare.boardedAt and 'riding' or 'accepted',
            driver = Framework.GetName(driverSrc),
            vehicle = Drivers[driverSrc].vehicle and Drivers[driverSrc].vehicle.label or nil,
            plate = Drivers[driverSrc].vehicle and Drivers[driverSrc].vehicle.assignedPlate or nil,
        }
    end

    return { state = 'none', drivers = Rides.DriversFree(), driving = IsOnDuty(src) or nil }
end

function Rides.Push(src)
    if not src or GetPlayerPing(src) == 0 then return end
    TriggerClientEvent('XS-TaxiJob:client:rideStatus', src, Rides.Status(src))
end

function Rides.DriversOnShift()
    local count = 0
    for _, driver in pairs(Drivers) do
        if driver.onDuty then count = count + 1 end
    end
    return count
end

function Rides.DriversFree()
    local count = 0
    for _, driver in pairs(Drivers) do
        if driver.onDuty and not driver.fare and driver.lamp ~= false then count = count + 1 end
    end
    return count
end

local function offerFor(id, request, driverSrc)
    local ped = GetPlayerPed(driverSrc)
    local away = ped ~= 0 and #(GetEntityCoords(ped) - request.coords) or nil

    return {
        id = id,
        passenger = request.name,
        origin = request.origin,
        coords = { x = request.coords.x, y = request.coords.y, z = request.coords.z },
        distance = away and math.floor(away) or nil,
        expiresIn = math.max(0, request.expiresAt - os.time()),
    }
end

function Rides.OffersFor(driverSrc)
    local out = {}
    for id, request in pairs(requests) do
        if request.offered[driverSrc] then out[#out + 1] = offerFor(id, request, driverSrc) end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function withdraw(id, driverSrc)
    TriggerClientEvent('XS-TaxiJob:client:rideWithdrawn', driverSrc, id)
end

local function expire(id, message)
    local request = requests[id]
    if not request then return end
    requests[id] = nil

    for driverSrc in pairs(request.offered) do withdraw(id, driverSrc) end

    if request.src then
        Framework.Notify(request.src, message or 'No driver picked up your call.', 'error')
        Phone.Notify(request.src, 'Taxi', message or 'No driver picked up your call.')
        Rides.Push(request.src)
    end
end

local function eligible(driverSrc, driver, request)
    if not driver.onDuty or driver.fare or driver.lamp == false then return nil end
    if driverSrc == request.src then return nil end

    local ped = GetPlayerPed(driverSrc)
    if ped == 0 then return nil end

    local away = #(GetEntityCoords(ped) - request.coords)
    if away > Config.Hail.maxDistance then return nil end
    return away
end

function Rides.Request(src, origin)
    if Admin and Admin.settings.hailEnabled == false then return fail('Taxi dispatch is not taking calls right now.') end
    if not Config.Hail.enabled then return fail('Calling a cab is turned off here.') end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return fail('No character loaded.') end
    if IsOnDuty(src) then return fail('You are the one driving.') end
    if pendingFor(src) or acceptedFor(src) then return fail('You already have a cab coming.') end

    local now = os.time()
    if cooldowns[citizenid] and now < cooldowns[citizenid] then
        return fail(('Wait %d seconds before calling again.'):format(cooldowns[citizenid] - now))
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return fail('Could not find you.') end

    nextRequestId = nextRequestId + 1
    local id = nextRequestId

    local request = {
        src = src,
        citizenid = citizenid,
        name = Framework.GetName(src),
        coords = GetEntityCoords(ped),
        origin = origin or 'command',
        createdAt = now,
        expiresAt = now + Config.Hail.offerTimeout,
        offered = {},
    }

    local count = 0
    for driverSrc, driver in pairs(Drivers) do
        local away = eligible(driverSrc, driver, request)
        if away then
            request.offered[driverSrc] = true
            count = count + 1
        end
    end

    if count == 0 then return fail('No cabs are free right now. Try again in a bit.') end

    requests[id] = request
    cooldowns[citizenid] = now + Config.Hail.cooldown

    for driverSrc in pairs(request.offered) do
        local offer = offerFor(id, request, driverSrc)
        TriggerClientEvent('XS-TaxiJob:client:rideOffer', driverSrc, offer)
        Phone.Notify(driverSrc, 'Taxi call', ('%s needs a cab, %s away.'):format(
            request.name, Text.distance(offer.distance or 0)))
    end

    SetTimeout(Config.Hail.offerTimeout * 1000, function()
        if requests[id] then expire(id) end
    end)

    Rides.Push(src)
    return { ok = true, id = id, drivers = count }
end

function Rides.Cancel(src)
    local id = pendingFor(src)
    if id then
        local request = requests[id]
        requests[id] = nil
        for driverSrc in pairs(request.offered) do withdraw(id, driverSrc) end
        Rides.Push(src)
        return { ok = true }
    end

    local driverSrc, driver, fare = acceptedFor(src)
    if driverSrc then
        if fare.boardedAt then return fail('You are already in the cab.') end
        driver.fare = nil
        TriggerClientEvent('XS-TaxiJob:client:fareCancelled', driverSrc)
        Framework.Notify(driverSrc, 'Your passenger cancelled.', 'inform')
        Rides.Push(src)
        return { ok = true }
    end

    return fail('You have no cab coming.')
end

function Rides.Pass(driverSrc, id)
    local request = requests[id]
    if not request or not request.offered[driverSrc] then return { ok = true } end

    request.offered[driverSrc] = nil
    withdraw(id, driverSrc)

    if next(request.offered) == nil then
        expire(id, 'No driver could take your call.')
    else
        Rides.Push(request.src)
    end

    return { ok = true }
end

function Rides.Accept(driverSrc, id)
    local request = requests[id]
    if not request then return fail('That call has already gone.') end

    local driver = DriverOf(driverSrc)
    if not driver or not driver.onDuty then return fail('You are not signed on.') end
    if driver.fare then return fail('You already have a fare.') end
    if not request.offered[driverSrc] then return fail('That call was not offered to you.') end

    local passengerPed = GetPlayerPed(request.src)
    if not passengerPed or passengerPed == 0 then
        expire(id)
        return fail('That passenger is no longer around.')
    end

    requests[id] = nil
    for otherSrc in pairs(request.offered) do
        if otherSrc ~= driverSrc then withdraw(id, otherSrc) end
    end

    local coords = GetEntityCoords(passengerPed)

    local fare = BuildFare(driver, 'player', {
        pickup = {
            coords = vec4(coords.x, coords.y, coords.z, 0.0),
            label = 'Street pickup',
            area = 'hail',
        },
        dropoff = {
            coords = vec4(coords.x, coords.y, coords.z, 0.0),
            label = 'Wherever they ask',
            area = 'hail',
        },
        passengerSrc = request.src,
        passengerCitizenId = request.citizenid,
        passengerName = request.name,
    })

    if not fare then return fail('Could not start that ride.') end

    fare.straightLine = 0.0
    fare.crossTown = false
    fare.openEnded = true
    driver.fare = fare

    local name = Framework.GetName(driverSrc)
    Framework.Notify(request.src, ('%s is on the way.'):format(name), 'success')
    Phone.Notify(request.src, 'Taxi', ('%s accepted your call and is on the way.'):format(name))
    Rides.Push(request.src)

    return { ok = true, fare = fare }
end

function Rides.Boarded(fare)
    if fare and fare.passengerSrc then
        Phone.Notify(fare.passengerSrc, 'Taxi', 'Your driver has picked you up.')
        Rides.Push(fare.passengerSrc)
    end
end

function Rides.Finished(fare)
    if fare and fare.passengerSrc then Rides.Push(fare.passengerSrc) end
end

function Rides.Dropped(fare, message)
    if fare and fare.passengerSrc then
        Framework.Notify(fare.passengerSrc, message, 'error')
        Phone.Notify(fare.passengerSrc, 'Taxi', message)
        Rides.Push(fare.passengerSrc)
    end
end

function Rides.DriverGone(driverSrc)
    for id, request in pairs(requests) do
        if request.offered[driverSrc] then
            request.offered[driverSrc] = nil
            if next(request.offered) == nil then expire(id) end
        end
    end
end

lib.callback.register('XS-TaxiJob:server:acceptRide', function(src, id)
    return Rides.Accept(src, tonumber(id))
end)

lib.callback.register('XS-TaxiJob:server:passRide', function(src, id)
    return Rides.Pass(src, tonumber(id))
end)

lib.callback.register('XS-TaxiJob:server:requestRide', function(src)
    return Rides.Request(src, 'phone')
end)

lib.callback.register('XS-TaxiJob:server:cancelRide', function(src)
    return Rides.Cancel(src)
end)

lib.callback.register('XS-TaxiJob:server:rideStatus', function(src)
    return Rides.Status(src)
end)

local function say(src, result, success)
    if result.ok then
        Framework.Notify(src, success, 'success')
    else
        Framework.Notify(src, result.error, 'error')
    end
end

RegisterCommand(Config.Hail.command, function(src)
    if src == 0 then return end
    local result = Rides.Request(src, 'command')
    if result.ok then
        say(src, result, ('%d driver%s notified. Hang tight.'):format(result.drivers, result.drivers == 1 and '' or 's'))
    else
        say(src, result)
    end
end, false)

if Config.Hail.cancelCommand and Config.Hail.cancelCommand ~= '' then
    RegisterCommand(Config.Hail.cancelCommand, function(src)
        if src == 0 then return end
        say(src, Rides.Cancel(src), 'Call cancelled.')
    end, false)
end

exports('RequestRide', function(src, origin) return Rides.Request(tonumber(src), origin == 'phone' and 'phone' or 'export') end)
exports('CancelRide', function(src) return Rides.Cancel(tonumber(src)) end)
exports('GetRideStatus', function(src) return Rides.Status(tonumber(src)) end)
exports('GetDriversOnShift', function() return Rides.DriversOnShift() end)
exports('GetFreeDrivers', function() return Rides.DriversFree() end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = pendingFor(src)
    if id then
        local request = requests[id]
        requests[id] = nil
        for driverSrc in pairs(request.offered) do withdraw(id, driverSrc) end
    end

    local driverSrc, driver, fare = acceptedFor(src)
    if driverSrc and not fare.boardedAt then
        driver.fare = nil
        TriggerClientEvent('XS-TaxiJob:client:fareCancelled', driverSrc)
        Framework.Notify(driverSrc, 'Your passenger left the city.', 'inform')
    end
end)
