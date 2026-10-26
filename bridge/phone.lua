Phone = { name = 'none', appId = 'xs-taxi' }

local ORDER = {
    'XS-Phone', 'lb-phone', 'qs-smartphone-pro', 'qs-smartphone', 'npwd', 'gksphone', 'okokPhone',
    'yseries', 'high-phone', 'roadphone', '17mov_Phone', 'qb-phone',
}

local function detect()
    local forced = Config.Bridges.phone
    if forced and forced ~= 'auto' then return forced end
    for _, name in ipairs(ORDER) do
        if GetResourceState(name) == 'started' then return name end
    end
    return 'none'
end

Phone.name = detect()

AddEventHandler('onResourceStart', function(resource)
    if Phone.name ~= 'none' then return end
    for _, name in ipairs(ORDER) do
        if name == resource then
            Phone.name = resource
            return
        end
    end
end)

function Phone.HasApp()
    if not Config.Phones or Config.Phones.app == false then return false end
    local name = Phone.name
    return name == 'lb-phone' or name == 'qs-smartphone-pro' or name == 'qs-smartphone'
        or name == 'gksphone' or name == 'okokPhone' or name == 'yseries'
end

if IsDuplicityVersion() then
    local function app()
        return Phone.HasApp() and Phone.appId or nil
    end

    local NOTIFY = {
        ['XS-Phone'] = function(src, title, body)
            return exports['XS-Phone']:Notify(src, { app = 'services', title = title, body = body })
        end,
        ['lb-phone'] = function(src, title, body)
            exports['lb-phone']:SendNotification(src, { app = app(), title = title, content = body })
            return true
        end,
        ['qs-smartphone'] = function(src, title, body)
            local ok, sent = pcall(function()
                return exports['qs-smartphone']:sendPhoneNotification(src, { appId = app(), title = title, text = body, closeTimeout = 6000 })
            end)
            if not ok or sent == false then
                TriggerClientEvent('qs-smartphone:client:notify', src, { title = title, text = body, timeout = 6000 })
            end
            return true
        end,
        ['gksphone'] = function(src, title, body)
            exports.gksphone:sendNotification(src, { title = title, message = body, icon = 'fas fa-taxi', duration = 6000 })
            return true
        end,
        ['okokPhone'] = function(src, title, body)
            exports.okokPhone:notifyDI(src, { title = title, text = body, app = app(), duration = 6000 })
            return true
        end,
        ['yseries'] = function(src, title, body)
            exports.yseries:SendNotification({ app = app() or 'messages', title = title, text = body, timeout = 6000 }, 'source', src)
            return true
        end,
        ['high-phone'] = function(src, title, body)
            exports['high-phone']:sendNotification(src, { title = title, content = body, application = { name = 'Taxi' }, duration = 6000 })
            return true
        end,
        ['roadphone'] = function(src, title, body)
            TriggerClientEvent('roadphone:sendNotification', src, { apptitle = 'Taxi', title = title, message = body })
            return true
        end,
        ['17mov_Phone'] = function(src, title, body)
            exports['17mov_Phone']:SendNotificationToSrc(src, { app = 'Taxi', title = title, message = body })
            return true
        end,
        ['qb-phone'] = function(src, title, body)
            TriggerClientEvent('qb-phone:client:CustomNotification', src, title, body, 'fas fa-taxi', '#f5b229', 6000)
            return true
        end,
        ['qs-smartphone-pro'] = function(src, title, body)
            TriggerClientEvent('XS-TaxiJob:client:phoneNotify', src, title, body)
            return true
        end,
        ['npwd'] = function(src, title, body)
            TriggerClientEvent('XS-TaxiJob:client:phoneNotify', src, title, body)
            return true
        end,
    }

    function Phone.Notify(src, title, body)
        if not src or src <= 0 then return end
        local send = NOTIFY[Phone.name]

        if send then
            local ok, sent = pcall(send, src, title, body)
            if ok and sent ~= false then return end
            if Config.Debug and not ok then
                print(('^1[XS-TaxiJob]^0 %s notification failed: %s'):format(Phone.name, tostring(sent)))
            end
        end

        Framework.Notify(src, ('%s: %s'):format(title, body), 'inform')
    end
end
