local candidate = nil
local candidateBlip = nil
local offeredAt = 0
local lastFlagAt = 0

local function removeBlip()
    if candidateBlip and DoesBlipExist(candidateBlip) then RemoveBlip(candidateBlip) end
    candidateBlip = nil
end

local function clearCandidate()
    removeBlip()

    if candidate and DoesEntityExist(candidate) then
        ClearPedTasks(candidate)
        SetPedAsNoLongerNeeded(candidate)
    end

    candidate = nil
    offeredAt = 0
end

function FlagdownClear()
    clearCandidate()
end

local function usable(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if ped == PlayerPedId() then return false end
    if IsPedAPlayer(ped) then return false end
    if not IsPedHuman(ped) then return false end
    if IsEntityAMissionEntity(ped) then return false end
    if IsPedInAnyVehicle(ped, true) then return false end
    if IsPedDeadOrDying(ped, true) or IsPedInjured(ped) then return false end
    if IsPedInCombat(ped, PlayerPedId()) or IsPedRagdoll(ped) then return false end
    if IsPedFleeing(ped) or IsPedSwimming(ped) then return false end
    if GetInteriorFromEntity(ped) ~= 0 then return false end

    return true
end

local function atTheKerb(at)
    if IsPointOnRoad(at.x, at.y, at.z, 0) then return false end

    local found, node = GetClosestVehicleNode(at.x, at.y, at.z, 1, 3.0, 0)
    return found and node ~= nil and #(vec3(node.x, node.y, node.z) - at) <= 14.0
end

local function look()
    local cab = Taxi.cab
    if not cab or not DoesEntityExist(cab) then return nil end

    local here = GetEntityCoords(cab)
    local forward = GetEntityForwardVector(cab)
    local best, bestScore

    for _, ped in ipairs(GetGamePool('CPed')) do
        if usable(ped) then
            local at = GetEntityCoords(ped)
            local away = #(here - at)

            if away >= 10.0 and away <= Config.Flagdown.range and math.abs(at.z - here.z) <= 3.5 then
                local dx, dy = at.x - here.x, at.y - here.y
                local flat = math.sqrt(dx * dx + dy * dy)
                local ahead = flat > 0 and (forward.x * dx + forward.y * dy) / flat or -1.0

                if ahead >= 0.35
                    and IsEntityOnScreen(ped)
                    and HasEntityClearLosToEntity(cab, ped, 17)
                    and atTheKerb(at) then
                    local score = away * (1.6 - ahead)

                    if not bestScore or score < bestScore then
                        best, bestScore = ped, score
                    end
                end
            end
        end
    end

    return best
end

local function sideOf(ped)
    local offset = GetOffsetFromEntityGivenWorldCoords(Taxi.cab, GetEntityCoords(ped))
    return offset.x >= 0.0 and 'right' or 'left'
end

local function markCandidate(ped)
    removeBlip()

    candidateBlip = AddBlipForEntity(ped)
    SetBlipSprite(candidateBlip, 280)
    SetBlipColour(candidateBlip, 5)
    SetBlipScale(candidateBlip, 0.9)
    SetBlipFlashes(candidateBlip, true)
    SetBlipAsShortRange(candidateBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Flagging you down')
    EndTextCommandSetBlipName(candidateBlip)

    CreateThread(function()
        while candidate == ped and DoesEntityExist(ped) do
            local at = GetEntityCoords(ped)
            DrawMarker(2, at.x, at.y, at.z + 1.25, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                0.32, 0.32, 0.32, 255, 196, 0, 210, true, true, 2, false, nil, nil, false)
            Wait(0)
        end
    end)
end

local function offer(ped)
    local at = GetEntityCoords(ped)

    local claimed = lib.callback.await('XS-TaxiJob:server:claimFlagdown', false, {
        x = at.x, y = at.y, z = at.z,
    })

    if not claimed or not claimed.ok then return false end
    if not DoesEntityExist(ped) then return false end

    candidate = ped
    offeredAt = GetGameTimer()

    SetEntityAsMissionEntity(ped, true, true)
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, Taxi.cab, 2000)

    if pcall(lib.requestAnimDict, 'taxi_hail', 1500) then
        TaskPlayAnim(ped, 'taxi_hail', 'hail_taxi', 8.0, -8.0, -1, 1, 0, false, false, false)
        RemoveAnimDict('taxi_hail')
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end

    markCandidate(ped)

    Framework.Notify(('Someone ahead on your %s is flagging you down. Pull over next to them, or %s to wave them off.')
        :format(sideOf(ped), '/' .. Config.Flagdown.command), 'inform')

    return true
end

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

    local fare = result.fare
    fare.passengerPed = ped

    removeBlip()
    candidate = nil
    offeredAt = 0
    lastFlagAt = GetGameTimer()

    StartFlaggedFare(fare)
end

function SetLamp(on)
    Taxi.lamp = on and true or false

    TriggerServerEvent('XS-TaxiJob:server:setLamp', Taxi.lamp)

    if not Taxi.lamp then clearCandidate() end

    if Taxi.cab and DoesEntityExist(Taxi.cab) and GetEntityModel(Taxi.cab) == `taxi` then
        SetTaxiLights(Taxi.cab, Taxi.lamp)
    end

    Framework.Notify(Taxi.lamp and 'Lamp on. Anyone can flag you down.' or 'Lamp off.', 'inform')
    SendNUIMessage({ action = 'lamp', data = { on = Taxi.lamp } })
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

                if speed < 2.0 and away <= Config.Flagdown.stopDistance then
                    takeIt(candidate)
                elseif away > Config.Flagdown.range * 1.6
                    or GetGameTimer() - offeredAt > Config.Flagdown.offerSeconds * 1000 then
                    clearCandidate()
                end
            elseif speed > 2.0 and InCab()
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
