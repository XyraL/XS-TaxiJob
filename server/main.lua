Drivers = {}
TaxiSchemaReady = false

local slotsInUse = {}
local seenCitizenIds = {}

local function vehicleByModel(model)
    for _, entry in ipairs(Config.Vehicles.list) do
        if entry.model == model then return entry end
    end
    return nil
end

local function slotKey(locationId, index)
    return ('%d:%d'):format(locationId, index)
end

local function freeBay(location)
    for index, bay in ipairs(location.data.bays) do
        local key = slotKey(location.id, index)
        if not slotsInUse[key] then return key, bay end
    end
    return nil
end

local function releaseSlot(key)
    if key then slotsInUse[key] = nil end
end

function IsOnDuty(src)
    local driver = Drivers[src]
    return driver ~= nil and driver.onDuty == true
end

function DriverOf(src)
    return Drivers[src]
end

local function closeShift(src, reason)
    local driver = Drivers[src]
    if not driver then return end

    if driver.fare and Config.Shift.penaliseAbandon and reason ~= 'clean' then
        Stats.AddReputation(driver.citizenid, -Config.Reputation.cancelPenalty)
    end

    Stats.EndShift(driver.shiftId, driver.totals)
    releaseSlot(driver.slot)
    Drivers[src] = nil

    if Rides then Rides.DriverGone(src) end
end

local function safeName(value)
    return type(value) == 'string' and value:match('^[%w_]+$') and value or nil
end

local function ownsVehicle(citizenid, plate)
    local cfg = Config.PersonalVehicles or {}
    local tbl = safeName(cfg.table or 'player_vehicles')
    local owner = safeName(cfg.ownerColumn or 'citizenid')
    local plateColumn = safeName(cfg.plateColumn or 'plate')
    if not tbl or not owner or not plateColumn then return false end

    local ok, found = pcall(MySQL.scalar.await,
        ('SELECT 1 FROM `%s` WHERE `%s` = ? AND TRIM(`%s`) = ? LIMIT 1'):format(tbl, owner, plateColumn),
        { citizenid, plate })

    if not ok then
        print(('^3[XS-TaxiJob]^0 could not check car ownership in %s: %s'):format(tbl, tostring(found)))
        return false
    end

    return found ~= nil
end

local function jobAllowed(src, location)
    local job = Locations.Job(location)
    return not job or Framework.GetJobName(src) == job
end

local function where(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function publicFare(fare)
    if not fare then return nil end
    return {
        id = fare.id,
        kind = fare.kind,
        stage = fare.boardedAt and 'riding' or 'toPickup',
        pickup = fare.pickup,
        dropoff = fare.dropoff,
        openEnded = fare.openEnded == true,
        night = fare.night == true,
        crossTown = fare.crossTown == true,
        passenger = fare.passengerName,
        extra = fare.extra,
        rates = fare.rates,
    }
end

lib.callback.register('XS-TaxiJob:server:getState', function(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end

    seenCitizenIds[src] = citizenid

    local summary = Stats.Summary(citizenid)
    if not summary then return nil end

    local driver = Drivers[src]
    local here = where(src)
    local at = here and Locations.Near(here, Config.Depot.useRange + 5.0) or nil

    local vehicles = {}
    for _, entry in ipairs(Config.Vehicles.list) do
        vehicles[#vehicles + 1] = {
            model = entry.model,
            label = entry.label,
            tier = entry.tier,
            rate = entry.rate,
            locked = summary.tier < entry.tier,
            offered = at == nil or Locations.AllowsCab(at, entry.model),
        }
    end

    return {
        name = Framework.GetName(src),
        onDuty = driver ~= nil and driver.onDuty or false,
        vehicle = driver and driver.vehicle or nil,
        location = driver and driver.location or nil,
        totals = driver and driver.totals or { fares = 0, earned = 0, distance = 0 },
        startedAt = driver and driver.startedAt or nil,
        now = os.time(),
        hasFare = driver ~= nil and driver.fare ~= nil,
        fare = driver and publicFare(driver.fare) or nil,
        openEnded = driver ~= nil and driver.fare ~= nil and driver.fare.openEnded == true,
        deposit = (driver and driver.vehicle and driver.vehicle.deposit) or Config.Vehicles.deposit,
        stats = summary,
        tiers = Config.Reputation.tiers,
        vehicles = vehicles,
        recent = Stats.Recent(citizenid, 12),
        leaderboard = Stats.Leaderboard(10),
        hailEnabled = Config.Hail.enabled and (not Admin or Admin.settings.hailEnabled ~= false),
        isAdmin = Admin ~= nil and Admin.IsAdmin(src) or false,
        lamp = driver ~= nil and driver.lamp ~= false,
        locations = Locations.Public(),
        at = at and at.id or nil,
        atName = at and at.name or nil,
        personalAllowed = at ~= nil and at.data.personal == true,
        jobOk = at == nil or jobAllowed(src, at),
        rides = Rides and Rides.OffersFor(src) or {},
        flagdown = Config.Flagdown.enabled,
    }
end)

local function startPersonal(src, citizenid, location, data, summary)
    if not location.data.personal then
        return { ok = false, error = 'This depot only rents cabs.' }
    end

    local ped = GetPlayerPed(src)
    local netId = tonumber(data.netId)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId) or 0

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return { ok = false, error = 'Get in your car first.' }
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return { ok = false, error = 'You need to be in the driver seat.' }
    end

    if GetVehicleType(vehicle) ~= 'automobile' then
        return { ok = false, error = 'That cannot take passengers.' }
    end

    local plate = Keys.Trim(GetVehicleNumberPlateText(vehicle))
    if plate == '' or not ownsVehicle(citizenid, plate) then
        return { ok = false, error = 'That car is not registered to you.' }
    end

    local label = tostring(data.label or ''):gsub('[%c<>]', ''):sub(1, 32)
    if label == '' then label = 'Own car' end

    Drivers[src] = {
        citizenid = citizenid,
        onDuty = true,
        location = location.id,
        slot = nil,
        shiftId = Stats.StartShift(citizenid, 'personal'),
        startedAt = os.time(),
        totals = { fares = 0, earned = 0, distance = 0 },
        fare = nil,
        lamp = Config.Flagdown.lampOnAtSignOn,
        vehicle = {
            model = 'personal',
            label = label,
            rate = (Config.PersonalVehicles and Config.PersonalVehicles.rate) or 1.0,
            plate = plate,
            assignedPlate = plate,
            personal = true,
            netId = netId,
        },
    }

    return {
        ok = true,
        personal = true,
        vehicle = Drivers[src].vehicle,
        deposit = 0,
        stats = summary,
    }
end

lib.callback.register('XS-TaxiJob:server:startShift', function(src, data)
    if type(data) ~= 'table' then data = { model = data } end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return { ok = false, error = 'No character loaded.' } end
    if Drivers[src] then return { ok = false, error = 'You are already signed on.' } end

    local here = where(src)
    local location = Locations.Get(data.location)
    if not location and here then location = Locations.Near(here, Config.Depot.useRange + 5.0) end
    if not location then return { ok = false, error = 'Sign on at a taxi depot.' } end

    if not here or #(here - Locations.Desk(location)) > Config.Depot.useRange + 10.0 then
        return { ok = false, error = ('Sign on at %s.'):format(location.name) }
    end

    if not jobAllowed(src, location) then
        return { ok = false, error = 'Only hired cab drivers can sign on here.' }
    end

    local summary = Stats.Summary(citizenid)

    if data.personal then
        return startPersonal(src, citizenid, location, data, summary)
    end

    local entry = vehicleByModel(data.model)
    if not entry then return { ok = false, error = 'That cab is not on the roster.' } end

    if not Locations.AllowsCab(location, entry.model) then
        return { ok = false, error = ('%s does not rent the %s.'):format(location.name, entry.label) }
    end

    if summary.tier < entry.tier then
        return { ok = false, error = ('The %s needs tier %d. You are tier %d.'):format(entry.label, entry.tier, summary.tier) }
    end

    local deposit = Config.Vehicles.deposit
    if Framework.GetMoney(src, Config.Meter.account) < deposit then
        return { ok = false, error = ('You need %s for the deposit.'):format(Text.money(deposit)) }
    end

    local slot, bay = freeBay(location)
    if not slot then return { ok = false, error = 'Every cab bay here is taken. Try again shortly.' } end

    if deposit > 0 and not Framework.RemoveMoney(src, Config.Meter.account, deposit, 'XS-TaxiJob:deposit') then
        return { ok = false, error = 'Could not take the deposit.' }
    end

    slotsInUse[slot] = src

    Drivers[src] = {
        citizenid = citizenid,
        onDuty = true,
        location = location.id,
        slot = slot,
        shiftId = Stats.StartShift(citizenid, entry.model),
        startedAt = os.time(),
        totals = { fares = 0, earned = 0, distance = 0 },
        fare = nil,
        lamp = Config.Flagdown.lampOnAtSignOn,
        vehicle = {
            model = entry.model,
            label = entry.label,
            rate = entry.rate,
            plate = entry.plate,
            assignedPlate = ('%s%04d'):format((entry.plate or 'TAXI'):sub(1, 4), math.random(0, 9999)),
            netId = nil,
            deposit = deposit,
        },
    }

    return {
        ok = true,
        spawn = { x = bay.x, y = bay.y, z = bay.z, w = bay.w },
        vehicle = Drivers[src].vehicle,
        deposit = deposit,
        stats = summary,
    }
end)

RegisterNetEvent('XS-TaxiJob:server:setLamp', function(on)
    local driver = Drivers[source]
    if driver then driver.lamp = on == true end
end)

RegisterNetEvent('XS-TaxiJob:server:registerCab', function(netId)
    local src = source
    local driver = Drivers[src]
    if not driver or driver.vehicle.personal or type(netId) ~= 'number' then return end
    driver.vehicle.netId = netId

    local vehicle

    for _ = 1, 50 do
        vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then break end

        vehicle = nil
        Wait(10)
    end

    if not vehicle then
        print(('^3[XS-TaxiJob]^0 cab %d never reached the server, so %s has no keys')
            :format(netId, Framework.GetName(src)))
        return
    end

    Keys.GiveServer(src, vehicle, driver.vehicle.assignedPlate)
end)

local function atAnyBay(coords)
    for _, location in ipairs(Locations.list) do
        for _, bay in ipairs(location.data.bays) do
            if #(coords - vec3(bay.x, bay.y, bay.z)) <= Config.Vehicles.returnDistance then return true end
        end
    end
    return false
end

lib.callback.register('XS-TaxiJob:server:endShift', function(src)
    local driver = Drivers[src]
    if not driver then return { ok = false, error = 'You are not signed on.' } end

    local personal = driver.vehicle and driver.vehicle.personal == true
    local returned = false
    local bodyHealth = 1000.0

    if not personal then
        local netId = driver.vehicle and driver.vehicle.netId
        local cab = netId and NetworkGetEntityFromNetworkId(netId)

        if cab and cab ~= 0 and DoesEntityExist(cab) then
            bodyHealth = GetVehicleBodyHealth(cab)
            returned = atAnyBay(GetEntityCoords(cab))
        end
    end

    local refund, fee = 0, 0

    if returned then
        local damage = math.max(0.0, math.min(1.0, (1000.0 - bodyHealth) / 1000.0))
        local paid = driver.vehicle.deposit or Config.Vehicles.deposit
        fee = math.min(paid, math.floor(paid * damage * Config.Vehicles.damageFeeRate))
        refund = math.max(0, paid - fee)
        if refund > 0 then
            Framework.AddMoney(src, Config.Meter.account, refund, 'XS-TaxiJob:depositRefund')
        end
    end

    local summary = {
        fares = driver.totals.fares,
        earned = driver.totals.earned,
        distance = driver.totals.distance,
        minutes = math.floor((os.time() - driver.startedAt) / 60),
        refund = refund,
        damageFee = fee,
        abandoned = driver.fare ~= nil,
        personal = personal,
        returned = returned,
    }

    closeShift(src, driver.fare and 'abandoned' or 'clean')

    summary.stats = Stats.Summary(Framework.GetCitizenId(src))
    return { ok = true, summary = summary }
end)

lib.callback.register('XS-TaxiJob:server:abortShift', function(src)
    local driver = Drivers[src]
    if not driver then return { ok = false } end
    if driver.vehicle.personal or driver.vehicle.netId or driver.fare then return { ok = false } end
    if os.time() - driver.startedAt > 60 then return { ok = false } end

    local paid = driver.vehicle.deposit or Config.Vehicles.deposit
    if paid > 0 then Framework.AddMoney(src, Config.Meter.account, paid, 'XS-TaxiJob:depositRefund') end
    closeShift(src, 'clean')
    return { ok = true }
end)

lib.callback.register('XS-TaxiJob:server:nearestDepot', function(src)
    local here = where(src)
    if not here then return nil end
    local location = Locations.Nearest(here)
    if not location then return nil end
    local desk = location.data.desk
    return { id = location.id, name = location.name, x = desk.x, y = desk.y, z = desk.z }
end)

local function leave(src, reason)
    local citizenid = Drivers[src] and Drivers[src].citizenid or seenCitizenIds[src]

    if Drivers[src] then closeShift(src, reason) end

    if citizenid then Stats.Forget(citizenid) end
    seenCitizenIds[src] = nil
end

AddEventHandler('playerDropped', function()
    leave(source, 'dropped')
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    leave(tonumber(src) or source, 'logout')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, driver in pairs(Drivers) do
        Stats.EndShift(driver.shiftId, driver.totals)
        Drivers[src] = nil
    end
end)

CreateThread(function()
    local file = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if file then
        for statement in file:gmatch('[^;]+') do
            if statement:match('%S') then
                local ok, err = pcall(MySQL.query.await, statement)
                if not ok then print(('^1[XS-TaxiJob]^0 could not create a table: %s'):format(tostring(err))) end
            end
        end
    end
    TaxiSchemaReady = true
end)
