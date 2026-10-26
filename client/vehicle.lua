local NO_PASSENGERS = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

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

    SetVehicleNumberPlateText(cab, vehicle.assignedPlate or plateFor(vehicle.plate))
    SetVehicleOnGroundProperly(cab)
    SetEntityAsMissionEntity(cab, true, true)
    SetVehicleEngineOn(cab, true, true, false)
    SetVehicleDirtLevel(cab, 0.0)
    SetVehicleDoorsLocked(cab, 1)

    if vehicle.model == 'taxi' then
        SetTaxiLights(cab, true)
    end

    Taxi.cab = cab
    Taxi.cabNetId = NetworkGetNetworkIdFromEntity(cab)
    SetNetworkIdCanMigrate(Taxi.cabNetId, true)

    Fuel.Fill(cab)
    Keys.Give(cab)
    TriggerServerEvent('XS-TaxiJob:server:registerCab', Taxi.cabNetId)

    SetPedIntoVehicle(PlayerPedId(), cab, -1)
    return true
end

function PersonalCarCheck()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'Sit in the driver seat of your own car first.'
    end

    if NO_PASSENGERS[GetVehicleClass(vehicle)] then
        return nil, 'That cannot take passengers.'
    end

    if GetVehicleMaxNumberOfPassengers(vehicle) < 1 then
        return nil, 'There is no seat for a passenger.'
    end

    return vehicle, nil
end

function UsePersonalCar(vehicle)
    Taxi.cab = vehicle
    Taxi.cabNetId = NetworkGetNetworkIdFromEntity(vehicle)
end

function ReleasePersonalCar()
    if Taxi.cab and DoesEntityExist(Taxi.cab) and GetEntityModel(Taxi.cab) == `taxi` then
        SetTaxiLights(Taxi.cab, false)
    end
    Taxi.cab = nil
    Taxi.cabNetId = nil
end

function DespawnCab()
    if Taxi.cab and DoesEntityExist(Taxi.cab) then
        if not NetworkHasControlOfEntity(Taxi.cab) then
            NetworkRequestControlOfEntity(Taxi.cab)

            for _ = 1, 60 do
                if NetworkHasControlOfEntity(Taxi.cab) then break end
                Wait(0)
                NetworkRequestControlOfEntity(Taxi.cab)
            end
        end

        SetEntityAsMissionEntity(Taxi.cab, true, true)
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

function CabIsAtDepot()
    if not CabExists() then return false end
    return Depots.AtAnyBay(GetEntityCoords(Taxi.cab))
end

CreateThread(function()
    local warned = false

    while true do
        Wait(5000)

        if Taxi.onDuty and CabExists() and not Taxi.personal then
            local away = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(Taxi.cab))

            if away > 120.0 and not warned then
                warned = true
                Framework.Notify('Your cab is a long way off. Park it in a depot bay before you sign off to get the deposit back.', 'inform')
            elseif away < 60.0 then
                warned = false
            end
        end
    end
end)

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
                    Framework.Notify(Taxi.personal and 'You left your car too long. Signing you off.'
                        or 'You left the cab too long. Signing you off.', 'error')
                    EndShift()
                end
            end
        else
            awaySince = nil
        end
    end
end)
