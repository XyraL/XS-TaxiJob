Keys = { name = 'none' }

local ORDER = {
    { resource = 'qbx_vehiclekeys',     name = 'qbx' },
    { resource = 'Renewed-Vehiclekeys', name = 'renewed' },
    { resource = 'wasabi_carlock',      name = 'wasabi' },
    { resource = 'mk_vehiclekeys',      name = 'mk' },
    { resource = 'vehicles_keys',       name = 'jaksam' },
    { resource = 'qs-vehiclekeys',      name = 'qs-vehiclekeys' },
    { resource = 'qb-vehiclekeys',      name = 'qb-vehiclekeys' },
    { resource = 'cd_garage',           name = 'cd_garage' },
    { resource = 'okokGarage',          name = 'okokGarage' },
}

local SERVER_SIDE = {
    qbx = true, renewed = true, wasabi = true, mk = true, jaksam = true,
    ['qb-vehiclekeys'] = true, cd_garage = true,
}

local function detect()
    local forced = Config.Bridges.keys
    if forced ~= nil and forced ~= 'auto' then return forced end
    for _, entry in ipairs(ORDER) do
        if GetResourceState(entry.resource) == 'started' then return entry.name end
    end
    return 'none'
end

Keys.name = detect()

function Keys.Trim(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function report(err)
    if Config.Debug then
        print(('^1[XS-TaxiJob]^0 %s keys handoff failed: %s'):format(Keys.name, tostring(err)))
    end
end

if IsDuplicityVersion() then
    function Keys.GiveServer(src, vehicle, plate)
        if not SERVER_SIDE[Keys.name] then return end
        plate = Keys.Trim(plate or GetVehicleNumberPlateText(vehicle))

        local ok, err = pcall(function()
            if Keys.name == 'qbx' then
                exports.qbx_vehiclekeys:GiveKeys(src, vehicle, false)
            elseif Keys.name == 'renewed' then
                exports['Renewed-Vehiclekeys']:addKey(src, plate)
            elseif Keys.name == 'wasabi' then
                exports.wasabi_carlock:GiveKey(src, plate)
            elseif Keys.name == 'mk' then
                exports.mk_vehiclekeys:AddKey(vehicle, src)
            elseif Keys.name == 'jaksam' then
                exports.vehicles_keys:giveVehicleKeysToPlayerId(src, plate, 'temporary')
            elseif Keys.name == 'cd_garage' then
                TriggerClientEvent('cd_garage:AddKeys', src, plate)
            elseif Keys.name == 'qb-vehiclekeys' then
                local given = pcall(function() exports['qb-vehiclekeys']:GiveKeys(src, plate) end)
                if not given then TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) end
            end
        end)

        if not ok then report(err) end
    end
else
    function Keys.Give(vehicle)
        if SERVER_SIDE[Keys.name] or Keys.name == 'none' then return end
        if not DoesEntityExist(vehicle) then return end

        local plate = Keys.Trim(GetVehicleNumberPlateText(vehicle))
        local ok, err = pcall(function()
            if Keys.name == 'qs-vehiclekeys' then
                exports['qs-vehiclekeys']:GiveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
            elseif Keys.name == 'okokGarage' then
                TriggerServerEvent('okokGarage:GiveKeys', plate)
            elseif Keys.name == 'custom' then
                exports['XS-TaxiJob']:OnGiveKeys(vehicle, plate)
            end
        end)

        if not ok then report(err) end
    end
end
