local requests = {}
local cooldowns = {}
local nextRequestId = 0

local function activeRequestFor(src)
    for id, request in pairs(requests) do
        if request.src == src then return id, request end
    end
    return nil
end

local function expire(id)
    local request = requests[id]
    if not request then return end
    requests[id] = nil

    for _, driverSrc in ipairs(request.offeredTo or {}) do
        TriggerClientEvent('XS-TaxiJob:client:hailExpired', driverSrc, id)
    end

    if request.src then
        Framework.Notify(request.src, 'No driver picked up your call.', 'error')
    end
end

-- Offers the ride to every signed-on driver who is free and close enough. The
-- first to accept takes it; the rest have the offer withdrawn.
local function broadcast(id)
    local request = requests[id]
    if not request then return end

    local here = request.coords
    local offered = {}

    for driverSrc, driver in pairs(Drivers) do
        if driver.onDuty and not driver.fare and driverSrc ~= request.src then
            local ped = GetPlayerPed(driverSrc)
            local away = ped ~= 0 and #(GetEntityCoords(ped) - here) or math.huge

            if away <= Config.Hail.maxDistance then
                offered[#offered + 1] = driverSrc
                TriggerClientEvent('XS-TaxiJob:client:hailOffer', driverSrc, {
                    id = id,
                    label = request.label,
                    coords = { x = here.x, y = here.y, z = here.z },
                    distance = math.floor(away),
                    passenger = request.name,
                    expiresIn = Config.Hail.offerTimeout,
                })
            end
        end
    end

    request.offeredTo = offered

    if #offered == 0 then
        requests[id] = nil
        Framework.Notify(request.src, 'No cabs are on the road right now.', 'error')
        return
    end

    Framework.Notify(request.src, ('%d driver%s notified. Hang tight.'):format(#offered, #offered == 1 and '' or 's'), 'success')

    SetTimeout(Config.Hail.offerTimeout * 1000, function()
        if requests[id] then expire(id) end
    end)
end

RegisterCommand(Config.Hail.command, function(src)
    if src == 0 then return end
    if not Config.Hail.enabled then
        Framework.Notify(src, 'Calling a cab is disabled here.', 'error')
        return
    end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return end

    if activeRequestFor(src) then
        Framework.Notify(src, 'You already have a cab on the way.', 'error')
        return
    end

    local now = os.time()
    if cooldowns[citizenid] and now < cooldowns[citizenid] then
        Framework.Notify(src, ('Wait %d seconds before calling again.'):format(cooldowns[citizenid] - now), 'error')
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    if IsOnDuty(src) then
        Framework.Notify(src, 'You are the one driving.', 'error')
        return
    end

    cooldowns[citizenid] = now + Config.Hail.cooldown
    nextRequestId = nextRequestId + 1
    local id = nextRequestId

    local coords = GetEntityCoords(ped)
    requests[id] = {
        src = src,
        citizenid = citizenid,
        name = Framework.GetName(src),
        coords = coords,
        label = 'Street pickup',
        createdAt = now,
    }

    broadcast(id)
end, false)

lib.callback.register('XS-TaxiJob:server:acceptHail', function(src, id)
    local request = requests[id]
    if not request then return { ok = false, error = 'That call has already gone.' } end

    local driver = DriverOf(src)
    if not driver or not driver.onDuty then return { ok = false, error = 'You are not signed on.' } end
    if driver.fare then return { ok = false, error = 'You already have a fare.' } end

    local passengerPed = GetPlayerPed(request.src)
    if passengerPed == 0 then
        requests[id] = nil
        return { ok = false, error = 'That passenger is no longer around.' }
    end

    requests[id] = nil
    for _, otherSrc in ipairs(request.offeredTo or {}) do
        if otherSrc ~= src then
            TriggerClientEvent('XS-TaxiJob:client:hailExpired', otherSrc, id)
        end
    end

    local coords = GetEntityCoords(passengerPed)

    -- A hailed ride has no set destination. The meter runs from pickup until
    -- the driver ends it, wherever the passenger asked to go.
    local fare = BuildFare(driver, 'player', {
        pickup = {
            coords = vec4(coords.x, coords.y, coords.z, 0.0),
            label = 'Street pickup',
            area = 'hail',
        },
        dropoff = {
            coords = vec4(coords.x, coords.y, coords.z, 0.0),
            label = 'Passenger destination',
            area = 'hail',
        },
        passengerSrc = request.src,
        passengerCitizenId = request.citizenid,
    })

    if not fare then return { ok = false, error = 'Could not start that ride.' } end

    fare.straightLine = 0.0
    fare.crossTown = false
    fare.openEnded = true
    driver.fare = fare

    Framework.Notify(request.src, ('%s is on the way.'):format(Framework.GetName(src)), 'success')
    Phone.Notify(request.src, 'Taxi', ('%s accepted your call.'):format(Framework.GetName(src)))

    return { ok = true, fare = fare }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = activeRequestFor(src)
    if id then requests[id] = nil end
end)
