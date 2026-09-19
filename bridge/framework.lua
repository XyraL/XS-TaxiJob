-- Patching the registrar rather than each call site gives every NUI callback in
-- the resource two guarantees, including any added later:
--
-- 1. Each handler runs in its own thread. FiveM will not dispatch the next NUI
--    callback while the current one is still yielding, and most handlers here
--    yield on a server round-trip.
-- 2. A nil payload is sent as `false`. cb(nil) sends no response body at all,
--    leaving the page's fetch pending forever. Several callbacks return nil
--    legitimately, and every consumer tests for truthiness, so `false` reads
--    the same to the page and actually resolves.
if not IsDuplicityVersion() and type(RegisterNUICallback) == 'function' then
    local _registerNUI = RegisterNUICallback

    RegisterNUICallback = function(name, handler)
        return _registerNUI(name, function(data, cb)
            CreateThread(function()
                handler(data, function(payload, ...)
                    if payload == nil then payload = false end
                    cb(payload, ...)
                end)
            end)
        end)
    end
end

Framework = { name = nil, core = nil }

local function detect()
    local forced = Config.Bridges.framework
    if forced == 'qbox' or forced == 'qbcore' then return forced end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    return nil
end

Framework.name = detect()

if Framework.name == 'qbcore' then
    Framework.core = exports['qb-core']:GetCoreObject()
elseif not Framework.name then
    print('^1[XS-TaxiJob]^0 No supported framework found. Start qbx_core or qb-core before XS-TaxiJob.')
end

if IsDuplicityVersion() then
    function Framework.GetPlayer(src)
        if Framework.name == 'qbox' then return exports.qbx_core:GetPlayer(src) end
        if Framework.name == 'qbcore' then return Framework.core.Functions.GetPlayer(src) end
        return nil
    end

    function Framework.GetCitizenId(src)
        local player = Framework.GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    end

    function Framework.GetName(src)
        local player = Framework.GetPlayer(src)
        local info = player and player.PlayerData and player.PlayerData.charinfo
        if not info then return GetPlayerName(src) or 'Unknown' end
        return (('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''))
    end

    function Framework.GetNameByCitizenId(citizenid)
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if not row or not row.charinfo then return citizenid end
        local ok, info = pcall(json.decode, row.charinfo)
        if not ok or not info then return citizenid end
        return (('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''))
    end

    function Framework.AddMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account or 'cash', math.floor(amount), reason or 'XS-TaxiJob')
    end

    function Framework.RemoveMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveMoney(account or 'cash', math.floor(amount), reason or 'XS-TaxiJob')
    end

    function Framework.GetMoney(src, account)
        local player = Framework.GetPlayer(src)
        if not player then return 0 end
        local money = player.PlayerData and player.PlayerData.money
        return money and money[account or 'cash'] or 0
    end

    function Framework.Notify(src, message, kind)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Taxi',
            description = message,
            type = kind or 'inform',
        })
    end
else
    function Framework.GetPlayerData()
        if Framework.name == 'qbox' then return exports.qbx_core:GetPlayerData() end
        if Framework.name == 'qbcore' then return Framework.core.Functions.GetPlayerData() end
        return nil
    end

    function Framework.Notify(message, kind)
        lib.notify({ title = 'Taxi', description = message, type = kind or 'inform' })
    end
end
