local offers = {}

local function streetAt(coords)
    local street = GetStreetNameAtCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    local name = street and street ~= 0 and GetStreetNameFromHashKey(street)
    if name and name ~= '' and name ~= 'NULL' then return name end
    return 'Street pickup'
end

local function list()
    local out = {}
    for _, offer in pairs(offers) do out[#out + 1] = offer end
    table.sort(out, function(a, b) return a.id > b.id end)
    return out
end

function RideOffers()
    return list()
end

local function drop(id)
    if not offers[id] then return end
    offers[id] = nil
    SendNUIMessage({ action = 'rideGone', data = { id = id } })
end

function ClearRideOffers()
    for id in pairs(offers) do drop(id) end
end

RegisterNetEvent('XS-TaxiJob:client:rideOffer', function(offer)
    if not Taxi.onDuty or Taxi.fare then return end
    if type(offer) ~= 'table' or not offer.id or type(offer.coords) ~= 'table' then return end

    local how = Config.Hail.acceptKey ~= '' and Config.Hail.acceptKey
        or (Config.Depot.key ~= '' and Config.Depot.key) or ('/' .. Config.Depot.command)

    offer.street = streetAt(offer.coords)
    offer.receivedAt = GetGameTimer()
    offer.answerWith = how
    offers[offer.id] = offer

    SendNUIMessage({ action = 'rideOffer', data = offer })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)

    Framework.Notify(('%s needs a cab on %s, %s away. Press %s to answer.'):format(
        offer.passenger or 'Someone', offer.street, Text.distance(offer.distance or 0), how), 'inform')

    SetTimeout((offer.expiresIn or Config.Hail.offerTimeout) * 1000, function()
        if offers[offer.id] then drop(offer.id) end
    end)
end)

RegisterNetEvent('XS-TaxiJob:client:rideWithdrawn', function(id)
    drop(id)
end)

function AcceptRide(id)
    id = tonumber(id)
    if not id then return { ok = false, error = 'Which call?' } end
    if not Taxi.onDuty then return { ok = false, error = 'You are not signed on.' } end
    if Taxi.fare then return { ok = false, error = 'You already have a fare.' } end
    if not offers[id] then return { ok = false, error = 'That call has gone.' } end

    local result = lib.callback.await('XS-TaxiJob:server:acceptRide', false, id)
    drop(id)

    if not result or not result.ok then
        Framework.Notify(result and result.error or 'Could not take that call.', 'error')
        return result or { ok = false }
    end

    ClearRideOffers()
    StartHailedFare(result.fare)
    return { ok = true }
end

function PassRide(id)
    id = tonumber(id)
    if not id or not offers[id] then return { ok = true } end
    drop(id)
    return lib.callback.await('XS-TaxiJob:server:passRide', false, id) or { ok = true }
end

local function latest()
    local newest
    for _, offer in pairs(offers) do
        if not newest or offer.id > newest.id then newest = offer end
    end
    return newest
end

RegisterNUICallback('acceptRide', function(data, cb)
    local result = AcceptRide(data and data.id)
    if result.ok then CloseTablet() end
    cb(result)
end)

RegisterNUICallback('passRide', function(data, cb)
    cb(PassRide(data and data.id))
end)

RegisterCommand('accepthail', function(_, args)
    local id = tonumber(args[1])
    if not id then
        local newest = latest()
        id = newest and newest.id
    end

    if not id then
        Framework.Notify('No taxi calls waiting.', 'error')
        return
    end

    AcceptRide(id)
end, false)

if Config.Hail.acceptKey and Config.Hail.acceptKey ~= '' then
    RegisterKeyMapping('accepthail', 'Taxi: answer the latest call', 'keyboard', Config.Hail.acceptKey)
end

RegisterNetEvent('XS-TaxiJob:client:rideStatus', function(status)
    if PhoneApp then PhoneApp.Status(status) end
end)
