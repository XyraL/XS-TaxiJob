Fuel = { name = 'none' }

local ORDER = {
    'cdn-fuel', 'ps-fuel', 'lc_fuel', 'lj-fuel', 'qb-fuel', 'Renewed-Fuel', 'okokGasStation',
    'ti_fuel', 'BigDaddy-Fuel', 'x-fuel', 'rcore_fuel', 'qs-fuelstations', 'ND_Fuel',
    'melons_fuel', 'LegacyFuel', 'ox_fuel',
}

local function detect()
    local forced = Config.Bridges.fuel
    if forced and forced ~= 'auto' then return forced end
    for _, name in ipairs(ORDER) do
        if GetResourceState(name) == 'started' then return name end
    end
    return 'none'
end

Fuel.name = detect()

local CALLS = {
    ['cdn-fuel'] = function(v, l) exports['cdn-fuel']:SetFuel(v, l) end,
    ['ps-fuel'] = function(v, l) exports['ps-fuel']:SetFuel(v, l) end,
    ['lc_fuel'] = function(v, l) exports['lc_fuel']:SetFuel(v, l) end,
    ['lj-fuel'] = function(v, l) exports['lj-fuel']:SetFuel(v, l) end,
    ['qb-fuel'] = function(v, l) exports['qb-fuel']:SetFuel(v, l) end,
    ['Renewed-Fuel'] = function(v, l) exports['Renewed-Fuel']:SetFuel(v, l) end,
    ['okokGasStation'] = function(v, l) exports['okokGasStation']:SetFuel(v, l) end,
    ['ti_fuel'] = function(v, l) exports['ti_fuel']:setFuel(v, l) end,
    ['BigDaddy-Fuel'] = function(v, l) exports['BigDaddy-Fuel']:SetFuel(v, l) end,
    ['x-fuel'] = function(v, l) exports['x-fuel']:SetFuel(v, l) end,
    ['rcore_fuel'] = function(v, l) exports['rcore_fuel']:SetVehicleFuel(v, l) end,
    ['qs-fuelstations'] = function(v, l) exports['qs-fuelstations']:SetFuel(v, l) end,
    ['ND_Fuel'] = function(v, l) DecorSetFloat(v, '_ANDY_FUEL_DECORE_', l) end,
    ['LegacyFuel'] = function(v, l) exports['LegacyFuel']:SetFuel(v, l) end,
}

function Fuel.Fill(vehicle, level)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    level = (tonumber(level) or 100.0) + 0.0

    SetVehicleFuelLevel(vehicle, level)
    if DecorIsRegisteredAsType('_FUEL_LEVEL', 1) then DecorSetFloat(vehicle, '_FUEL_LEVEL', level) end
    if NetworkGetEntityIsNetworked(vehicle) then
        pcall(function() Entity(vehicle).state:set('fuel', level, true) end)
    end

    local call = CALLS[Fuel.name]
    if not call then return end

    local ok, err = pcall(call, vehicle, level)
    if not ok and Config.Debug then
        print(('^1[XS-TaxiJob]^0 %s fuel call failed: %s'):format(Fuel.name, tostring(err)))
    end
end
