local pending = {}

local function dismiss(id)
    pending[id] = nil
    SendNUIMessage({ action = 'hailDismiss', data = { id = id } })
end

RegisterNetEvent('XS-TaxiJob:client:hailOffer', function(offer)
    if not Taxi.onDuty or Taxi.fare then return end
    if type(offer) ~= 'table' or not offer.id then return end

    pending[offer.id] = offer
    SendNUIMessage({ action = 'hailOffer', data = offer })

    lib.notify({
        id = ('xs_taxi_hail_%d'):format(offer.id),
        title = 'Taxi call',
        description = ('%s needs a cab, %s away. Accept with /accepthail %d'):format(
            offer.passenger or 'Someone', Text.distance(offer.distance or 0), offer.id),
        type = 'inform',
        duration = (offer.expiresIn or 30) * 1000,
    })

    SetTimeout((offer.expiresIn or Config.Hail.offerTimeout) * 1000, function()
        if pending[offer.id] then dismiss(offer.id) end
    end)
end)

RegisterNetEvent('XS-TaxiJob:client:hailExpired', function(id)
    if pending[id] then dismiss(id) end
end)

function AcceptHail(id)
    id = tonumber(id)
    if not id then return { ok = false, error = 'Which call?' } end
    if not Taxi.onDuty then return { ok = false, error = 'You are not signed on.' } end
    if Taxi.fare then return { ok = false, error = 'You already have a fare.' } end
    if not pending[id] then return { ok = false, error = 'That call has gone.' } end

    local result = lib.callback.await('XS-TaxiJob:server:acceptHail', false, id)
    dismiss(id)

    if not result or not result.ok then
        Framework.Notify(result and result.error or 'Could not take that call.', 'error')
        return result or { ok = false }
    end

    StartHailedFare(result.fare)
    return { ok = true }
end

RegisterCommand('accepthail', function(_, args)
    -- With one call waiting the id is redundant; take it as read.
    local id = tonumber(args[1])
    if not id then
        for pendingId in pairs(pending) do
            id = pendingId
            break
        end
    end

    if not id then
        Framework.Notify('No taxi calls waiting.', 'error')
        return
    end

    AcceptHail(id)
end, false)

-- No NUI callback for this. A call card is shown while the driver is driving,
-- when the page has no focus and nothing on it can be clicked — and while the
-- terminal IS open the dock it lives in is hidden. /accepthail is the way in,
-- which is why the card prints it.
