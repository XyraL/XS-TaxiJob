PhoneApp = { added = false }

local RES = GetCurrentResourceName()
local PAGE = ('https://cfx-nui-%s/html/phone/index.html?res=%s'):format(RES, RES)
local ICON = ('https://cfx-nui-%s/html/phone/icon.png'):format(RES)

local function label()
    return (Config.Phones and Config.Phones.appName) or 'Taxi'
end

local ADD = {
    ['lb-phone'] = function()
        return exports['lb-phone']:AddCustomApp({
            identifier = Phone.appId,
            name = label(),
            description = 'Call a cab to where you are.',
            developer = 'XyraL',
            defaultApp = true,
            ui = RES .. '/html/phone/index.html?res=' .. RES,
            icon = ICON,
            fixBlur = true,
        })
    end,
    ['qs-smartphone-pro'] = function()
        return exports['qs-smartphone-pro']:addCustomApp({
            app = Phone.appId,
            label = label(),
            image = ICON,
            ui = PAGE,
            job = false,
            blockedJobs = {},
            timeout = 5000,
            creator = 'XyraL',
            category = 'social',
            isGame = false,
            description = 'Call a cab to where you are.',
            age = '16+',
            extraDescription = {},
        })
    end,
    ['qs-smartphone'] = function()
        return exports['qs-smartphone']:addCustomApp({
            id = Phone.appId,
            label = label(),
            icon = ICON,
            category = 'Utilities',
            creator = 'XyraL',
            description = 'Call a cab to where you are.',
            appStoreOnly = false,
            price = 0,
            sizeMb = 1,
            iframe = { url = PAGE },
            custom = { enabled = true, bridge = { enabled = true, allowedOrigins = { 'https://cfx-nui-' .. RES } } },
        })
    end,
    ['gksphone'] = function()
        return exports.gksphone:AddCustomApp({
            name = label(),
            appurl = PAGE,
            icons = ICON,
            description = 'Call a cab to where you are.',
            show = true,
        })
    end,
    ['yseries'] = function()
        return exports.yseries:AddCustomApp({
            key = Phone.appId,
            name = label(),
            defaultApp = true,
            ui = PAGE,
            icon = ICON,
        })
    end,
    ['okokPhone'] = function()
        return exports.okokPhone:loadApp({
            id = Phone.appId,
            label = label(),
            description = 'Call a cab to where you are.',
            custom = true,
            icon = ICON,
            resourceName = RES,
            webUrl = PAGE,
        })
    end,
}

local REMOVE = {
    ['lb-phone'] = function() exports['lb-phone']:RemoveCustomApp(Phone.appId) end,
    ['qs-smartphone-pro'] = function() exports['qs-smartphone-pro']:removeCustomApp(Phone.appId) end,
    ['qs-smartphone'] = function() exports['qs-smartphone']:removeCustomApp(Phone.appId) end,
    ['yseries'] = function() exports.yseries:RemoveCustomApp(Phone.appId) end,
}

local function addApp()
    if not Phone.HasApp() then return end
    local add = ADD[Phone.name]
    if not add then return end

    local ok, err = pcall(add)
    PhoneApp.added = ok
    if not ok and Config.Debug then
        print(('^1[XS-TaxiJob]^0 could not add the %s app: %s'):format(Phone.name, tostring(err)))
    end
end

function PhoneApp.Status(status)
    if Phone.name == 'lb-phone' and PhoneApp.added then
        pcall(function()
            exports['lb-phone']:SendCustomAppMessage(Phone.appId, { type = 'status', status = status })
        end)
    end
end

RegisterNUICallback('phoneStatus', function(_, cb)
    cb(lib.callback.await('XS-TaxiJob:server:rideStatus', false) or { state = 'none' })
end)

RegisterNUICallback('phoneRequest', function(_, cb)
    cb(lib.callback.await('XS-TaxiJob:server:requestRide', false) or { ok = false, error = 'Dispatch did not answer.' })
end)

RegisterNUICallback('phoneCancel', function(_, cb)
    cb(lib.callback.await('XS-TaxiJob:server:cancelRide', false) or { ok = false, error = 'Dispatch did not answer.' })
end)

RegisterNetEvent('XS-TaxiJob:client:phoneNotify', function(title, body)
    if Phone.name == 'npwd' then
        pcall(function()
            exports.npwd:createNotification({
                notisId = ('xs-taxi:%d'):format(GetGameTimer()),
                appId = 'MESSAGES',
                content = body,
                secondaryTitle = title,
                duration = 6000,
            })
        end)
    elseif Phone.name == 'qs-smartphone-pro' then
        pcall(function()
            exports['qs-smartphone-pro']:SendTempNotification({ title = title, text = body, app = Phone.appId, timeout = 6000 })
        end)
    else
        Framework.Notify(('%s: %s'):format(title, body), 'inform')
    end
end)

CreateThread(function()
    Wait(1500)
    addApp()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= Phone.name then return end
    CreateThread(function()
        Wait(1000)
        addApp()
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RES or not PhoneApp.added then return end
    local remove = REMOVE[Phone.name]
    if remove then pcall(remove) end
end)
