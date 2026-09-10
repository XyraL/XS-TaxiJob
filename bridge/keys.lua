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

-- Cabs spawn unlocked with hotwiring disabled, but most servers run a separate
-- keys system that blocks the engine until a vehicle is handed to a player.
-- Every call is wrapped so a wrong or missing export never hard-errors the job;
-- turn Config.Debug on to see the real error if a cab still will not start.
if IsDuplicityVersion() then
    -- qbx_vehiclekeys' GiveKeys export is server-side and needs the server's
    -- own resolved handle, so that one option is handled here rather than on
    -- the client with everything else.
    function Keys.GiveServer(src, vehicle)
        if Keys.name ~= 'qbx' then return end

        local ok, err = pcall(function()
            exports.qbx_vehiclekeys:GiveKeys(src, vehicle, false)
        end)

        if not ok and Config.Debug then
            print(('^1[XS-TaxiJob]^0 qbx_vehiclekeys GiveKeys failed: %s'):format(tostring(err)))
        end
    end
else
    function Keys.Give(vehicle)
        if Keys.name == 'none' or Keys.name == 'qbx' then return end
        if not DoesEntityExist(vehicle) then return end

        local plate = GetVehicleNumberPlateText(vehicle)
        local ok, err = true, nil

        if Keys.name == 'qb-vehiclekeys' then
            ok, err = pcall(function() TriggerEvent('vehiclekeys:client:SetOwner', plate) end)
        elseif Keys.name == 'qs-vehiclekeys' then
            ok, err = pcall(function() exports['qs-vehiclekeys']:GiveKeys(plate) end)
        elseif Keys.name == 'custom' then
            ok, err = pcall(function() exports['XS-TaxiJob']:OnGiveKeys(vehicle, plate) end)
        end

        if not ok and Config.Debug then
            print(('^1[XS-TaxiJob]^0 keys handoff failed for "%s": %s'):format(Keys.name, tostring(err)))
        end
    end
end
