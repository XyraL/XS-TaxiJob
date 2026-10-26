local cfg = Config.Phones or {}

local function answer(src)
    local result = Rides.Request(src, 'phone')
    local text = result.ok
        and ('A cab is on the way. %d driver%s got your call.'):format(result.drivers, result.drivers == 1 and '' or 's')
        or result.error
    Phone.Notify(src, 'Taxi', text)
    return result, text
end

if cfg.company and cfg.company ~= '' then
    AddEventHandler('lb-phone:newCompanyMessage', function(message)
        if type(message) ~= 'table' or message.company ~= cfg.company or message.sentByEmployee then return end
        local ok, src = pcall(function() return exports['lb-phone']:GetSourceFromNumber(message.sender) end)
        if ok and type(src) == 'number' and src > 0 then answer(src) end
    end)

    AddEventHandler('gksphone:services:newReport', function(report)
        if type(report) ~= 'table' or report.job ~= cfg.company then return end
        local src = tonumber(report.source)
        if src and src > 0 then answer(src) end
    end)
end

local function hookNpwd()
    if not cfg.number or cfg.number == '' or GetResourceState('npwd') ~= 'started' then return end

    pcall(function()
        exports.npwd:onCall(cfg.number, function(ctx)
            local caller = ctx.incomingCaller and tonumber(ctx.incomingCaller.source)
            if caller then
                local _, text = answer(caller)
                pcall(ctx.reply, text)
            end
            pcall(ctx.exit)
        end)
    end)

    pcall(function()
        exports.npwd:onMessage(cfg.number, function(ctx)
            local src = tonumber(ctx.source)
            if not src then return end
            local _, text = answer(src)
            local from = ctx.data and ctx.data.sourcePhoneNumber
            if from then
                pcall(function()
                    exports.npwd:emitMessage({ senderNumber = cfg.number, targetNumber = from, message = text })
                end)
            end
        end)
    end)
end

CreateThread(function()
    Wait(1000)
    hookNpwd()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == 'npwd' then
        SetTimeout(1500, hookNpwd)
    end
end)
