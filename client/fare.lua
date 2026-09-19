local fareBlip
local lastCompletedAt = 0

local function clearBlip()
    if fareBlip then
        RemoveBlip(fareBlip)
        fareBlip = nil
    end
end

local function setBlip(coords, label, sprite, colour)
    clearBlip()
    fareBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(fareBlip, sprite or 280)
    SetBlipColour(fareBlip, colour or 5)
    SetBlipScale(fareBlip, 0.85)
    SetBlipRoute(fareBlip, true)
    SetBlipRouteColour(fareBlip, colour or 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(fareBlip)
end

function ClearFareState()
    clearBlip()

    if Taxi.fare and Taxi.fare.passengerPed and DoesEntityExist(Taxi.fare.passengerPed) then
        DeleteEntity(Taxi.fare.passengerPed)
    end

    Taxi.fare = nil
    StopMeter()
end

--[[ Put a point on the nearest road and name it after that road.

     The server picks a bearing and a distance and has no road network to ask,
     so its spot can land in a garden or on a central reservation. This is the
     half that knows where the tarmac is. ]]
local function onStreet(point)
    local found, node, heading = GetNthClosestVehicleNodeWithHeading(
        point.x, point.y, point.z, 1, 1, 3.0, 0)

    if found and node then
        point.x, point.y, point.z = node.x, node.y, node.z
        point.w = heading or point.w or 0.0
    end

    -- Two returns: the street and whatever it crosses. Only the first is
    -- wanted, and taking it into one local is what truncates it.
    local street = GetStreetNameAtCoord(point.x, point.y, point.z)
    local name = street and street ~= 0 and GetStreetNameFromHashKey(street)

    if name and name ~= '' and name ~= 'NULL' then point.label = name end

    return point
end

local function spawnPassenger(fare)
    local hash = joaat(fare.ped)
    RequestModel(hash)

    local waited = 0
    while not HasModelLoaded(hash) and waited < 4000 do
        Wait(50)
        waited = waited + 50
    end
    if not HasModelLoaded(hash) then return nil end

    --[[ Feet on the floor, whichever kind of spot this is.

         A named point's z was captured at head height, so it wanted a metre
         off it. A snapped road node's z IS the tarmac, so taking a metre off
         that one buries the passenger in the road. Ask the map instead, and
         keep the old guess only for when the map has not loaded. ]]
    local found, groundZ = GetGroundZFor_3dCoord(fare.pickup.x, fare.pickup.y, fare.pickup.z + 1.0, false)
    local z = found and groundZ or (fare.pickup.z - 1.0)

    local ped = CreatePed(4, hash, fare.pickup.x, fare.pickup.y, z, fare.pickup.w or 0.0, true, false)
    SetModelAsNoLongerNeeded(hash)

    if not DoesEntityExist(ped) then return nil end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    -- They are put out early now, so they can be stood here a while. Standing
    -- still for a fixed number of seconds looked like a mannequin and ran out
    -- before the cab arrived.
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    return ped
end

-- Waits for the passenger to be aboard, then flips the fare into its riding
-- stage: meter on, route swapped to the destination.
local function boardPassenger(fare)
    fare.stage = 'boarding'

    if fare.kind == 'player' then
        Framework.Notify('Wait for your passenger to get in.', 'inform')
    else
        -- Normally already stood at the kerb, put there on the way in. The
        -- spawn here is for the case where the driver arrived before the
        -- passenger could be streamed.
        fare.passengerPed = fare.passengerPed or spawnPassenger(fare)

        if not fare.passengerPed then
            Framework.Notify('Your fare gave up waiting.', 'error')
            CancelFare('failed')
            return false
        end

        -- TaskEnterVehicle walks them over, so boarding starting further out
        -- is what makes them come to the cab rather than the cab having to
        -- land on the marker.
        ClearPedTasks(fare.passengerPed)
        SetPedKeepTask(fare.passengerPed, true)
        TaskEnterVehicle(fare.passengerPed, Taxi.cab, Config.Fares.boardingTimeout * 1000, 2, 1.6, 1, 0)
    end

    local deadline = GetGameTimer() + (Config.Fares.boardingTimeout * 1000)

    while GetGameTimer() < deadline do
        Wait(300)

        if not Taxi.fare or Taxi.fare.id ~= fare.id then return false end
        if not CabExists() then
            CancelFare('failed')
            return false
        end

        if fare.kind == 'player' then
            local passengerPed = GetPlayerPed(GetPlayerFromServerId(fare.passengerSrc or -1))
            if passengerPed and passengerPed ~= 0 and IsPedInVehicle(passengerPed, Taxi.cab, false) then
                return true
            end
        elseif IsPedInVehicle(fare.passengerPed, Taxi.cab, false) then
            return true
        end
    end

    Framework.Notify(fare.kind == 'player' and 'Your passenger never got in.' or 'Your fare gave up waiting.', 'error')
    CancelFare('failed')
    return false
end

local function dropOff(fare)
    if fare.passengerPed and DoesEntityExist(fare.passengerPed) then
        TaskLeaveVehicle(fare.passengerPed, Taxi.cab, 0)
        SetPedKeepTask(fare.passengerPed, true)
    end

    local result = lib.callback.await('XS-TaxiJob:server:completeFare', false, {
        fareId = fare.id,
        distance = Meter.distance,
        duration = MeterElapsed(),
        waiting = Meter.waiting,
        rating = Meter.rating,
    })

    if not result or not result.ok then
        Framework.Notify(result and result.error or 'The fare could not be settled.', 'error')
        return result or { ok = false }
    end

    Taxi.totals = result.totals
    Taxi.stats = result.stats
    lastCompletedAt = GetGameTimer()

    local ped = fare.passengerPed
    if ped and DoesEntityExist(ped) then
        CreateThread(function()
            Wait(2500)
            if DoesEntityExist(ped) then
                TaskWanderStandard(ped, 10.0, 10)
                SetPedAsNoLongerNeeded(ped)
            end
        end)
    end

    Taxi.fare = nil
    StopMeter()
    clearBlip()

    SendNUIMessage({ action = 'fareComplete', data = result })
    Framework.Notify(('%s fare, %s tip, %s stars. +%d rep.'):format(
        Text.money(result.fare), Text.money(result.tip), Text.round(result.rating, 1), result.reputation or 0), 'success')

    return result
end

-- Drives a fare from offer through to payout. Runs in its own thread so the
-- NUI callback that started it can return straight away.
local function runFare(fare)
    Taxi.fare = fare
    fare.stage = 'toPickup'

    -- A random spot is a bearing and a distance until this puts it on a road
    -- and names it. Named points are already somewhere real.
    if fare.random then
        onStreet(fare.pickup)
        if fare.dropoff then onStreet(fare.dropoff) end
    end

    setBlip(fare.pickup, ('Pickup - %s'):format(fare.pickup.label), 280, 5)
    Framework.Notify(('Pickup at %s.'):format(fare.pickup.label), 'inform')

    local deadline = GetGameTimer() + (Config.Fares.pickupTimeout * 1000)

    -- On the fare, so the meter can count it down. It was a local, which is
    -- why the pickup running out was a silent failure: the first the driver
    -- knew about it was being told the fare had given up.
    fare.deadline = deadline

    -- A player walks to you, so you have to get close. An NPC comes to the
    -- cab, so you only have to get near enough for them to see you.
    local reach = fare.kind == 'player'
        and Config.Fares.pickupDistance
        or Config.Fares.walkDistance

    while true do
        Wait(500)

        if not Taxi.fare or Taxi.fare.id ~= fare.id then return end
        if not Taxi.onDuty then
            CancelFare('failed')
            return
        end

        if GetGameTimer() > deadline then
            Framework.Notify('Your fare got tired of waiting.', 'error')
            CancelFare('failed')
            return
        end

        local here = GetEntityCoords(PlayerPedId())
        local away = #(here - vec3(fare.pickup.x, fare.pickup.y, fare.pickup.z))

        -- Put them on the pavement while the cab is still on its way, so they
        -- are stood waiting when it comes round the corner instead of
        -- appearing in front of the bonnet.
        if fare.kind ~= 'player' and not fare.passengerPed and away <= Config.Fares.spawnDistance then
            fare.passengerPed = spawnPassenger(fare)
        end

        local stopped = not CabExists() or GetEntitySpeed(Taxi.cab) < 3.0

        if away <= reach and stopped then
            break
        end
    end

    if not boardPassenger(fare) then return end
    if not Taxi.fare or Taxi.fare.id ~= fare.id then return end

    fare.stage = 'riding'
    StartMeter()
    TriggerServerEvent('XS-TaxiJob:server:fareBoarded', fare.id)

    if fare.openEnded then
        clearBlip()
        Framework.Notify('Meter running. End the ride from the terminal, or with /endride, where they ask to be dropped.', 'success')
        return
    end

    setBlip(fare.dropoff, ('Drop off - %s'):format(fare.dropoff.label), 280, 2)
    Framework.Notify(('Take them to %s.'):format(fare.dropoff.label), 'success')

    while true do
        Wait(500)

        if not Taxi.fare or Taxi.fare.id ~= fare.id then return end
        if not Taxi.onDuty then
            CancelFare('abandoned')
            return
        end

        local passengerAboard = fare.passengerPed and DoesEntityExist(fare.passengerPed)
            and IsPedInVehicle(fare.passengerPed, Taxi.cab, false)

        if not passengerAboard and fare.stage == 'riding' then
            Framework.Notify('Your passenger got out early. No fare.', 'error')
            CancelFare('abandoned')
            return
        end

        local here = GetEntityCoords(PlayerPedId())
        local away = #(here - vec3(fare.dropoff.x, fare.dropoff.y, fare.dropoff.z))
        local stopped = not CabExists() or GetEntitySpeed(Taxi.cab) < 3.0

        if away <= Config.Fares.dropoffDistance and stopped then
            dropOff(fare)
            return
        end
    end
end

RegisterNetEvent('XS-TaxiJob:client:fareCancelled', function()
    if not Taxi.fare then return end

    ClearFareState()
    StopMeter()
    Framework.Notify('Your fare was cleared.', 'inform')
end)

function RequestFare()
    if not Taxi.onDuty then return { ok = false, error = 'You are not signed on.' } end
    if Taxi.fare then return { ok = false, error = 'You already have a fare.' } end
    if not InCab() then return { ok = false, error = 'Get behind the wheel first.' } end

    local since = (GetGameTimer() - lastCompletedAt) / 1000
    if lastCompletedAt > 0 and since < Config.Fares.cooldownBetween then
        return { ok = false, error = ('Give it %d more seconds.'):format(math.ceil(Config.Fares.cooldownBetween - since)) }
    end

    local coords = GetEntityCoords(PlayerPedId())
    local result = lib.callback.await('XS-TaxiJob:server:requestFare', false, {
        coords = { x = coords.x, y = coords.y, z = coords.z },
    })

    if not result or not result.ok then
        return result or { ok = false, error = 'No fares available.' }
    end

    CreateThread(function() runFare(result.fare) end)
    return { ok = true, fare = result.fare }
end

function CancelFare(reason)
    if not Taxi.fare then return { ok = false, error = 'No fare running.' } end

    local result = lib.callback.await('XS-TaxiJob:server:cancelFare', false, reason or 'cancelled')
    ClearFareState()

    if result and result.ok then
        Taxi.stats = result.stats
    end

    if reason == 'abandoned' then
        Framework.Notify('You dropped a fare. That costs reputation.', 'error')
    end

    return result or { ok = true }
end

-- Ends an open-ended hailed ride wherever the cab currently is.
RegisterCommand('endride', function()
    if not Taxi.fare or not Taxi.fare.openEnded then
        Framework.Notify('You have no hailed ride running.', 'error')
        return
    end
    if Taxi.fare.stage ~= 'riding' then
        Framework.Notify('Your passenger is not aboard yet.', 'error')
        return
    end

    dropOff(Taxi.fare)
end, false)

RegisterNUICallback('endRide', function(_, cb)
    if not Taxi.fare or not Taxi.fare.openEnded or Taxi.fare.stage ~= 'riding' then
        cb({ ok = false, error = 'No hailed ride running.' })
        return
    end
    cb(dropOff(Taxi.fare))
end)

function StartHailedFare(fare)
    CreateThread(function() runFare(fare) end)
end
