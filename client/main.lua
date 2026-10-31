Taxi = {
    onDuty = false,
    uiOpen = false,
    cab = nil,
    cabNetId = nil,
    vehicle = nil,
    personal = false,
    location = nil,
    fare = nil,
    stats = nil,
    isAdmin = false,
    totals = { fares = 0, earned = 0, distance = 0 },
}

local function myPosition()
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    return { x = at.x, y = at.y, z = at.z, h = GetEntityHeading(ped) }
end

local function fetchState()
    local state = lib.callback.await('XS-TaxiJob:server:getState', false)
    if not state then return nil end

    Taxi.isAdmin = state.isAdmin == true
    Taxi.stats = state.stats or Taxi.stats

    state.me = myPosition()
    state.offers = RideOffers and RideOffers() or {}
    state.builder = Builder and Builder.draft or nil
    state.keys = {
        tablet = Config.Depot.key ~= '' and Config.Depot.key or ('/' .. Config.Depot.command),
        lamp = '/' .. Config.Flagdown.command,
    }
    local car, problem = PersonalCarCheck()
    state.carReady = car ~= nil
    state.carProblem = problem
    return state
end

function OpenTablet(opts)
    if Taxi.uiOpen then return end

    local state = fetchState()
    if not state then
        Framework.Notify('The taxi system is not responding.', 'error')
        return
    end

    if not state.onDuty and not state.at and not state.isAdmin then
        local depot = lib.callback.await('XS-TaxiJob:server:nearestDepot', false)
        if depot then
            SetNewWaypoint(depot.x + 0.0, depot.y + 0.0)
            Framework.Notify(('Sign on at a taxi depot first. GPS set to %s.'):format(depot.name), 'inform')
        else
            Framework.Notify('Sign on at a taxi depot first.', 'error')
        end
        return
    end

    state.page = opts and opts.page or nil
    Taxi.uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })

    CreateThread(function()
        while Taxi.uiOpen do
            Wait(1000)
            if Taxi.uiOpen then SendNUIMessage({ action = 'me', data = myPosition() }) end
        end
    end)
end

function CloseTablet()
    if not Taxi.uiOpen then return end
    Taxi.uiOpen = false
    if not Taxi.summaryOpen then SetNuiFocus(false, false) end
    SendNUIMessage({ action = 'close' })
end

function RefreshTablet()
    if not Taxi.uiOpen then return end
    local state = fetchState()
    if state then SendNUIMessage({ action = 'state', state = state }) end
end

RegisterNUICallback('close', function(_, cb)
    CloseTablet()
    cb({ ok = true })
end)

RegisterNUICallback('summaryShown', function(_, cb)
    Taxi.summaryOpen = true
    SetNuiFocus(true, true)
    cb({ ok = true })
end)

RegisterNUICallback('summaryClosed', function(_, cb)
    Taxi.summaryOpen = false
    if not Taxi.uiOpen then SetNuiFocus(false, false) end
    cb({ ok = true })
end)

RegisterNUICallback('getState', function(_, cb)
    cb(fetchState())
end)

RegisterNUICallback('setLamp', function(data, cb)
    if not Taxi.onDuty then
        cb({ ok = false, error = 'You are not signed on.' })
        return
    end

    SetLamp(data and data.on == true)
    cb({ ok = true })
end)

RegisterNUICallback('gps', function(data, cb)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if not x or not y then
        cb({ ok = false })
        return
    end
    SetNewWaypoint(x + 0.0, y + 0.0)
    cb({ ok = true })
end)

local function signedOn(result, location)
    Taxi.onDuty = true
    Taxi.location = location
    Taxi.vehicle = result.vehicle
    Taxi.personal = result.personal == true
    Taxi.stats = result.stats
    Taxi.totals = { fares = 0, earned = 0, distance = 0 }

    Uniform.Apply()
    SetLamp(Config.Flagdown.lampOnAtSignOn)
    StartMeterLoop()
end

RegisterNUICallback('startShift', function(data, cb)
    if Taxi.onDuty then
        cb({ ok = false, error = 'You are already signed on.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local location = tonumber(data.location)

    if data.personal then
        local vehicle, problem = PersonalCarCheck()
        if not vehicle then
            cb({ ok = false, error = problem })
            return
        end

        local model = GetEntityModel(vehicle)
        local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
        if not label or label == 'NULL' then label = GetDisplayNameFromVehicleModel(model) end

        local result = lib.callback.await('XS-TaxiJob:server:startShift', false, {
            location = location,
            personal = true,
            netId = NetworkGetNetworkIdFromEntity(vehicle),
            label = label,
        })

        if not result or not result.ok then
            cb(result or { ok = false, error = 'The depot refused that.' })
            return
        end

        UsePersonalCar(vehicle)
        signedOn(result, location)
        CloseTablet()
        Framework.Notify(('Signed on in your %s. Press %s for your tablet.'):format(result.vehicle.label,
            Config.Depot.key ~= '' and Config.Depot.key or ('/' .. Config.Depot.command)), 'success')
        cb({ ok = true })
        return
    end

    local result = lib.callback.await('XS-TaxiJob:server:startShift', false, {
        location = location,
        model = data.model,
    })

    if not result or not result.ok then
        cb(result or { ok = false, error = 'The depot refused that.' })
        return
    end

    if not SpawnCab(result.vehicle, result.spawn) then
        lib.callback.await('XS-TaxiJob:server:abortShift', false)
        cb({ ok = false, error = 'Could not get a cab onto the forecourt. Your deposit was given back.' })
        return
    end

    signedOn(result, location)
    CloseTablet()
    Framework.Notify(('Signed on. %s deposit held. Press %s for your tablet.'):format(Text.money(result.deposit),
        Config.Depot.key ~= '' and Config.Depot.key or ('/' .. Config.Depot.command)), 'success')
    cb({ ok = true })
end)

RegisterNUICallback('endShift', function(_, cb)
    cb(EndShift())
end)

RegisterNUICallback('requestFare', function(_, cb)
    cb(RequestFare())
end)

RegisterNUICallback('cancelFare', function(_, cb)
    cb(CancelFare('cancelled'))
end)

function EndShift()
    if not Taxi.onDuty then return { ok = false, error = 'You are not signed on.' } end

    local result = lib.callback.await('XS-TaxiJob:server:endShift', false)

    if not result or not result.ok then
        return result or { ok = false, error = 'Could not end the shift.' }
    end

    local summary = result.summary or {}

    if summary.personal then
        ReleasePersonalCar()
    elseif summary.returned then
        DespawnCab()
    end

    Taxi.onDuty = false
    Taxi.lamp = false
    Taxi.vehicle = nil
    Taxi.personal = false
    Taxi.location = nil
    Uniform.Remove()
    Taxi.stats = summary.stats
    ClearFareState()
    ClearRideOffers()
    StopMeterLoop()

    if not summary.personal and not summary.returned then
        Framework.Notify('Shift ended, but the cab was not parked in a depot bay. The deposit is gone.', 'error')
    end

    return result
end

RegisterCommand(Config.Depot.command, function()
    if Taxi.uiOpen then
        CloseTablet()
        return
    end
    OpenTablet()
end, false)

RegisterCommand(Config.Flagdown.command, function()
    if not Taxi.onDuty then
        Framework.Notify('You are not signed on.', 'error')
        return
    end

    SetLamp(not Taxi.lamp)
end, false)

if Config.Flagdown.key ~= '' then
    RegisterKeyMapping(Config.Flagdown.command, 'Taxi: toggle the roof lamp', 'keyboard', Config.Flagdown.key)
end

RegisterKeyMapping(Config.Depot.command, 'Taxi: open the driver tablet', 'keyboard', Config.Depot.key or '')

RegisterNetEvent('XS-TaxiJob:client:forceEndShift', function()
    if not Taxi.onDuty then return end

    local result = EndShift()

    if result and result.ok then
        Framework.Notify('An admin ended your shift.', 'inform')
    else
        Framework.Notify('An admin tried to end your shift and it would not close.', 'error')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CloseTablet()
    if Taxi.summaryOpen then
        Taxi.summaryOpen = false
        SetNuiFocus(false, false)
    end

    if not Taxi.onDuty then return end

    FlagdownClear()
    ClearFareState()
    ClearRideOffers()
    if Taxi.personal then ReleasePersonalCar() else DespawnCab() end

    Taxi.onDuty = false
    Taxi.lamp = false
    Taxi.vehicle = nil
    Taxi.personal = false
    Taxi.location = nil
    Taxi.stats = nil
    Taxi.totals = { fares = 0, earned = 0, distance = 0 }
    Uniform.Remove()
    StopMeterLoop()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Taxi.uiOpen or Taxi.summaryOpen then SetNuiFocus(false, false) end
    if not Taxi.personal then DespawnCab() end
    ClearFareState()
end)
