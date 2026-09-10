local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, Config.AdminAce)
end

RegisterCommand('taxistats', function(src)
    if src == 0 then return end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return end

    local summary = Stats.Summary(citizenid)
    if not summary then return end

    Framework.Notify(src, ('%s - tier %d (%s) - %d fares - %s earned - %s'):format(
        summary.tierLabel, summary.tier, summary.reputation .. ' rep',
        summary.totalFares, Text.money(summary.totalEarned), Text.stars(summary.rating)), 'inform')
end, false)

RegisterCommand('taxirep', function(src, args)
    if not isAdmin(src) then
        if src ~= 0 then Framework.Notify(src, 'You cannot do that.', 'error') end
        return
    end

    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    if not targetId or not amount then
        print('Usage: taxirep <playerId> <amount>')
        return
    end

    local citizenid = Framework.GetCitizenId(targetId)
    if not citizenid then
        print('That player has no character loaded.')
        return
    end

    Stats.AddReputation(citizenid, amount)
    local summary = Stats.Summary(citizenid)
    Framework.Notify(targetId, ('Reputation adjusted to %d (%s).'):format(summary.reputation, summary.tierLabel), 'inform')

    if src ~= 0 then
        Framework.Notify(src, ('%s is now on %d rep.'):format(Framework.GetName(targetId), summary.reputation), 'success')
    end
end, false)

RegisterCommand('taxiendshift', function(src, args)
    if not isAdmin(src) then
        if src ~= 0 then Framework.Notify(src, 'You cannot do that.', 'error') end
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        print('Usage: taxiendshift <playerId>')
        return
    end

    if not DriverOf(targetId) then
        if src ~= 0 then Framework.Notify(src, 'They are not signed on.', 'error') end
        return
    end

    TriggerClientEvent('XS-TaxiJob:client:forceEndShift', targetId)
    if src ~= 0 then Framework.Notify(src, 'Shift ended.', 'success') end
end, false)

exports('GetDriverSummary', function(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end
    return Stats.Summary(citizenid)
end)

exports('IsDriverOnDuty', function(src)
    return IsOnDuty(src)
end)
