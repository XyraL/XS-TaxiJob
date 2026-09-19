Taxi.isAdmin = false

CreateThread(function()
    Wait(2000)
    Taxi.isAdmin = lib.callback.await('XS-TaxiJob:server:isAdmin', false) == true
end)

local function proxy(endpoint, callback)
    RegisterNUICallback(endpoint, function(data, cb)
        if not Taxi.isAdmin then
            cb({ ok = false, error = 'You are not allowed to do that.' })
            return
        end
        cb(lib.callback.await(callback, false, data) or { ok = false, error = 'The server did not answer.' })
    end)
end

proxy('adminState',         'XS-TaxiJob:server:adminState')
proxy('adminSetReputation', 'XS-TaxiJob:server:adminSetReputation')
proxy('adminEndShift',      'XS-TaxiJob:server:adminEndShift')
proxy('adminClearFare',     'XS-TaxiJob:server:adminClearFare')
proxy('adminSetting',       'XS-TaxiJob:server:adminSetting')
proxy('adminWipe',          'XS-TaxiJob:server:adminWipe')
