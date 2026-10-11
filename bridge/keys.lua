Keys = { name = 'none' }

local function detect()
    local forced = Config.Bridges.keys
    if forced ~= nil and forced ~= 'auto' then return forced end
    if GetResourceState('qbx_vehiclekeys') == 'started' then return 'qbx' end
    if GetResourceState('qs-vehiclekeys') == 'started' then return 'qs-vehiclekeys' end
    if GetResourceState('qb-vehiclekeys') == 'started' then return 'qb-vehiclekeys' end
    return 'none'
end

Keys.name = detect()

function Keys.Trim(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Cabs spawn unlocked with hotwiring disabled, but most servers run a separate
-- keys system that blocks the engine until a vehicle is handed to a player.
-- Every call is wrapped so a wrong or missing export never hard-errors the job;
-- turn Config.Debug on to see the real error if a cab still will not start.
if IsDuplicityVersion() then
    function Keys.GiveServer(src, vehicle, plate)
        if Keys.name ~= 'qbx' and Keys.name ~= 'qb-vehiclekeys' then return end

        local ok, err = pcall(function()
            if Keys.name == 'qbx' then
                exports.qbx_vehiclekeys:GiveKeys(src, vehicle, false)
                return
            end

            plate = Keys.Trim(plate or GetVehicleNumberPlateText(vehicle))
            local given = pcall(function() exports['qb-vehiclekeys']:GiveKeys(src, plate) end)
            if not given then TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) end
        end)

        if not ok and Config.Debug then
            print(('^1[XS-TaxiJob]^0 %s GiveKeys failed: %s'):format(Keys.name, tostring(err)))
        end
    end
else
    function Keys.Give(vehicle)
        if Keys.name == 'none' or Keys.name == 'qbx' or Keys.name == 'qb-vehiclekeys' then return end
        if not DoesEntityExist(vehicle) then return end

        local plate = Keys.Trim(GetVehicleNumberPlateText(vehicle))
        local ok, err = true, nil

        if Keys.name == 'qs-vehiclekeys' then
            ok, err = pcall(function() exports['qs-vehiclekeys']:GiveKeys(plate) end)
        elseif Keys.name == 'custom' then
            ok, err = pcall(function() exports['XS-TaxiJob']:OnGiveKeys(vehicle, plate) end)
        end

        if not ok and Config.Debug then
            print(('^1[XS-TaxiJob]^0 keys handoff failed for "%s": %s'):format(Keys.name, tostring(err)))
        end
    end
end
