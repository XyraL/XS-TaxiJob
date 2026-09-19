Taxi = {
    onDuty = false,
    uiOpen = false,
    cab = nil,
    cabNetId = nil,
    vehicle = nil,
    fare = nil,
    stats = nil,
    totals = { fares = 0, earned = 0, distance = 0 },
}

local depotBlip

local function createDepotBlip()
    local cfg = Config.Depot.blip
    depotBlip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(depotBlip, cfg.sprite)
    SetBlipColour(depotBlip, cfg.color)
    SetBlipScale(depotBlip, cfg.scale)
    SetBlipAsShortRange(depotBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label)
    EndTextCommandSetBlipName(depotBlip)
end

function OpenTerminal()
    if Taxi.uiOpen then return end

    local state = lib.callback.await('XS-TaxiJob:server:getState', false)
    if not state then
        Framework.Notify('The depot system is not responding.', 'error')
        return
    end

    Taxi.stats = state.stats
    Taxi.uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })
end

function CloseTerminal()
    if not Taxi.uiOpen then return end
    Taxi.uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    CloseTerminal()
    cb({ ok = true })
end)

RegisterNUICallback('getState', function(_, cb)
    cb(lib.callback.await('XS-TaxiJob:server:getState', false))
end)

RegisterNUICallback('startShift', function(data, cb)
    if Taxi.onDuty then
        cb({ ok = false, error = 'You are already signed on.' })
        return
    end

    local result = lib.callback.await('XS-TaxiJob:server:startShift', false, data and data.model)
    if not result or not result.ok then
        cb(result or { ok = false, error = 'The depot refused that.' })
        return
    end

    local spawned = SpawnCab(result.vehicle, result.spawn)
    if not spawned then
        -- Hand the shift straight back rather than leaving the driver signed on
        -- with a deposit taken and no cab to show for it.
        lib.callback.await('XS-TaxiJob:server:endShift', false, { returned = true, bodyHealth = 1000.0 })
        cb({ ok = false, error = 'Could not get a cab onto the forecourt.' })
        return
    end

    Taxi.onDuty = true
    Uniform.Apply()
    Taxi.vehicle = result.vehicle
    Taxi.stats = result.stats
    Taxi.totals = { fares = 0, earned = 0, distance = 0 }

    CloseTerminal()
    StartMeterLoop()
    Framework.Notify(('Signed on. %s deposit held.'):format(Text.money(result.deposit)), 'success')

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

    local returned, bodyHealth = CabIsAtDepot()

    local result = lib.callback.await('XS-TaxiJob:server:endShift', false, {
        returned = returned,
        bodyHealth = bodyHealth,
    })

    if not result or not result.ok then
        return result or { ok = false, error = 'Could not end the shift.' }
    end

    if returned then DespawnCab() end

    Taxi.onDuty = false
    Taxi.vehicle = nil
    Uniform.Remove()
    Taxi.stats = result.summary.stats
    ClearFareState()
    StopMeterLoop()

    if not returned then
        Framework.Notify('Shift ended, but the cab was not returned. The deposit is gone.', 'error')
    end

    return result
end

RegisterNetEvent('XS-TaxiJob:client:forceEndShift', function()
    if not Taxi.onDuty then return end

    -- Told them it ended whether it did or not. If the call failed the meter
    -- kept running and the terminal still said on duty, with the two ends
    -- disagreeing about whether there was a shift at all.
    local result = EndShift()

    if result and result.ok then
        Framework.Notify('An admin ended your shift.', 'inform')
    else
        Framework.Notify('An admin tried to end your shift and it would not close.', 'error')
    end
end)

CreateThread(function()
    createDepotBlip()

    Target.addZone('xs_taxi_terminal', {
        coords = Config.Depot.terminal.coords,
        size = Config.Depot.terminal.size,
        distance = Config.Depot.terminal.distance,
        label = Config.Depot.terminal.label,
    }, function()
        OpenTerminal()
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Taxi.uiOpen then SetNuiFocus(false, false) end
    if depotBlip then RemoveBlip(depotBlip) end
    DespawnCab()
    ClearFareState()
end)
