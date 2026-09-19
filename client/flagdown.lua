--[[ Getting flagged down.

     The job's other two sources of work are both something you ask for: a
     button in the terminal, or a player typing /taxi. This one arrives through
     the windscreen. With the roof lamp on, people on the pavement put a hand
     out as you drive past, and you either pull over or you do not.

     Which pedestrian is chosen here, because only this end can see them. The
     SERVER owns everything that matters: whether the claim is granted, where
     they are going, what the trip is worth and every cooldown. Nothing below
     is trusted with a number.

     The lamp is also the off switch for all of it. A driver heading back to
     the depot at the end of a shift wants to stop being stopped. ]]

local candidate = nil
local offeredAt = 0
local lastFlagAt = 0

local function clearCandidate()
    if candidate and DoesEntityExist(candidate) then
        ClearPedTasks(candidate)
        -- Released, never deleted. It was somebody the world put there and it
        -- goes back to being the world's.
        SetPedAsNoLongerNeeded(candidate)
    end

    candidate = nil
    offeredAt = 0
end

function FlagdownClear()
    clearCandidate()
end

-- Somebody worth stopping for: on foot, not in a car, not already busy being
-- something else, and stood on the side of the road rather than in it.
local function usable(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if ped == PlayerPedId() then return false end
    if IsPedAPlayer(ped) then return false end
    if not IsPedHuman(ped) then return false end
    if IsPedInAnyVehicle(ped, true) then return false end
    if IsPedDeadOrDying(ped, true) or IsPedInjured(ped) then return false end
    if IsPedInCombat(ped, PlayerPedId()) or IsPedRagdoll(ped) then return false end

    return true
end

local function look()
    local cab = Taxi.cab
    if not cab or not DoesEntityExist(cab) then return nil end

    local here = GetEntityCoords(cab)
    local best, bestAway

    -- GetGamePool is the supported way to walk what is loaded. There is no
    -- ped enumerator in the native set.
    for _, ped in ipairs(GetGamePool('CPed')) do
        if usable(ped) then
            local away = #(here - GetEntityCoords(ped))

            if away <= Config.Flagdown.range and (not bestAway or away < bestAway) then
                best, bestAway = ped, away
            end
        end
    end

    return best
end

--[[ The offer.

     The server is asked first, because two cabs can drive past the same person
     and only one of them can have them. The claim is by position rather than
     by entity: an ambient ped is a different handle on every machine, so a
     handle is meaningless to anybody but the client that read it. ]]
local function offer(ped)
    local at = GetEntityCoords(ped)

    local claimed = lib.callback.await('XS-TaxiJob:server:claimFlagdown', false, {
        x = at.x, y = at.y, z = at.z,
    })

    if not claimed or not claimed.ok then return false end

    candidate = ped
    offeredAt = GetGameTimer()

    SetEntityAsMissionEntity(ped, true, true)
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, Taxi.cab, 2000)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    Framework.Notify(('Someone is flagging you down. Pull over, or %s to wave them off.')
        :format('/' .. Config.Flagdown.command), 'inform')

    return true
end

-- Pulling over is the accept. There is no prompt and no key: you either stop
-- for them or you drive on, which is what the gesture means.
local function takeIt(ped)
    local at = GetEntityCoords(ped)

    local result = lib.callback.await('XS-TaxiJob:server:flagdownFare', false, {
        x = at.x, y = at.y, z = at.z, h = GetEntityHeading(ped),
    })

    if not result or not result.ok then
        Framework.Notify(result and result.error or 'They changed their mind.', 'error')
        clearCandidate()
        return
    end

    -- The person already stood there IS the passenger. Nothing is spawned.
    local fare = result.fare
    fare.passengerPed = ped

    candidate = nil
    offeredAt = 0
    lastFlagAt = GetGameTimer()

    StartFlaggedFare(fare)
end

function SetLamp(on)
    Taxi.lamp = on and true or false

    TriggerServerEvent('XS-TaxiJob:server:setLamp', Taxi.lamp)

    if not Taxi.lamp then clearCandidate() end

    -- Only the taxi model has a sign on the roof. On the other cabs the lamp
    -- is a state the job keeps rather than a bulb, which is worth knowing
    -- before somebody files it as broken.
    if Taxi.cab and DoesEntityExist(Taxi.cab) and Taxi.vehicle and Taxi.vehicle.model == 'taxi' then
        SetTaxiLights(Taxi.cab, Taxi.lamp)
    end

    Framework.Notify(Taxi.lamp and 'Lamp on. Anyone can flag you down.' or 'Lamp off.', 'inform')
end

CreateThread(function()
    while true do
        local wait = 1200

        if Taxi.onDuty and Taxi.lamp and not Taxi.fare and Config.Flagdown.enabled then
            wait = 500

            local cab = Taxi.cab
            local speed = cab and DoesEntityExist(cab) and GetEntitySpeed(cab) or 0.0

            if candidate and not DoesEntityExist(candidate) then
                clearCandidate()
            elseif candidate then
                local away = #(GetEntityCoords(cab) - GetEntityCoords(candidate))

                -- Stopped beside them is the accept.
                if speed < 2.0 and away <= Config.Flagdown.stopDistance then
                    takeIt(candidate)
                elseif away > Config.Flagdown.range * 1.6
                    or GetGameTimer() - offeredAt > Config.Flagdown.offerSeconds * 1000 then
                    -- Driven past, or stood there long enough.
                    clearCandidate()
                end
            elseif speed > 2.0
                and GetGameTimer() - lastFlagAt > Config.Flagdown.cooldown * 1000
                and math.random(100) <= Config.Flagdown.chance then
                local found = look()
                if found then offer(found) end
            end
        elseif candidate then
            clearCandidate()
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearCandidate() end
end)
