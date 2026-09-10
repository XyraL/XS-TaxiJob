local function requestModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end

    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end

    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function plateFor(prefix)
    return ('%s%04d'):format((prefix or 'TAXI'):sub(1, 4), math.random(0, 9999))
end

function SpawnCab(vehicle, spawn)
    local hash = requestModel(vehicle.model)
    if not hash then
        Framework.Notify(('The %s model would not load.'):format(vehicle.label), 'error')
        return false
    end

    local cab = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetModelAsNoLongerNeeded(hash)

    if not DoesEntityExist(cab) then return false end

    SetVehicleNumberPlateText(cab, plateFor(vehicle.plate))
    SetVehicleOnGroundProperly(cab)
    SetEntityAsMissionEntity(cab, true, true)
    SetVehicleEngineOn(cab, true, true, false)
    SetVehicleDirtLevel(cab, 0.0)
    SetVehicleDoorsLocked(cab, 1)

    -- Taxi lights only exist on the taxi model; guard so other cabs do not warn.
    if vehicle.model == 'taxi' then
        SetTaxiLights(cab, true)
    end

    Taxi.cab = cab
    Taxi.cabNetId = NetworkGetNetworkIdFromEntity(cab)
    SetNetworkIdCanMigrate(Taxi.cabNetId, true)

    Keys.Give(cab)
    TriggerServerEvent('XS-TaxiJob:server:registerCab', Taxi.cabNetId)

    SetPedIntoVehicle(PlayerPedId(), cab, -1)
    return true
end

function DespawnCab()
    if Taxi.cab and DoesEntityExist(Taxi.cab) then
        DeleteVehicle(Taxi.cab)
    end
    Taxi.cab = nil
    Taxi.cabNetId = nil
end

function CabExists()
    return Taxi.cab ~= nil and DoesEntityExist(Taxi.cab)
end

function InCab()
    if not CabExists() then return false end
    local ped = PlayerPedId()
    return GetVehiclePedIsIn(ped, false) == Taxi.cab and GetPedInVehicleSeat(Taxi.cab, -1) == ped
end

-- Returns whether the cab is parked in a depot bay, and its body health so the
-- server can price the damage.
function CabIsAtDepot()
    if not CabExists() then return false, 0.0 end

    local here = GetEntityCoords(Taxi.cab)
    for _, slot in ipairs(Config.Depot.cabSpawns) do
        if #(here - vec3(slot.x, slot.y, slot.z)) <= Config.Vehicles.returnDistance then
            return true, GetVehicleBodyHealth(Taxi.cab)
        end
    end

    return false, GetVehicleBodyHealth(Taxi.cab)
end

-- Signing off away from the depot is allowed but costs the deposit, so warn
-- once when the driver wanders far with the cab still out.
CreateThread(function()
    local warned = false

    while true do
        Wait(5000)

        if Taxi.onDuty and CabExists() then
            local away = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(Taxi.cab))

            if away > 120.0 and not warned then
                warned = true
                Framework.Notify('Your cab is a long way off. Sign off at the depot to get the deposit back.', 'inform')
            elseif away < 60.0 then
                warned = false
            end
        end
    end
end)

-- Auto clock-off when the driver abandons the cab for too long.
CreateThread(function()
    local awaySince = nil

    while true do
        Wait(5000)

        if Taxi.onDuty and Config.Shift.awayTimeout > 0 then
            if InCab() then
                awaySince = nil
            else
                awaySince = awaySince or GetGameTimer()
                if (GetGameTimer() - awaySince) > (Config.Shift.awayTimeout * 1000) then
                    awaySince = nil
                    Framework.Notify('You left the cab too long. Signing you off.', 'error')
                    EndShift()
                end
            end
        else
            awaySince = nil
        end
    end
end)
