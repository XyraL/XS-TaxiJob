Text = {}

function Text.money(amount)
    local whole = math.floor(math.abs(tonumber(amount) or 0) + 0.5)
    local formatted = tostring(whole)
    local grouped = formatted:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return ('%s$%s'):format((tonumber(amount) or 0) < 0 and '-' or '', grouped)
end

function Text.distance(metres)
    metres = tonumber(metres) or 0
    if metres < 1000 then return ('%dm'):format(math.floor(metres)) end
    return ('%.1fkm'):format(metres / 1000)
end

function Text.duration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return ('%d:%02d'):format(minutes, seconds % 60) end
    return ('%dh %dm'):format(math.floor(minutes / 60), minutes % 60)
end

function Text.trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Text.round(value, places)
    local mult = 10 ^ (places or 0)
    return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

-- Returns the reputation tier a driver sits in, and how far into it they are.
function Text.tierFor(reputation)
    reputation = tonumber(reputation) or 0
    local current = Config.Reputation.tiers[1]

    for _, tier in ipairs(Config.Reputation.tiers) do
        if reputation >= tier.at then current = tier end
    end

    local next
    for _, tier in ipairs(Config.Reputation.tiers) do
        if tier.at > reputation then
            next = tier
            break
        end
    end

    local span = next and (next.at - current.at) or 0
    local into = next and (reputation - current.at) or 0

    return current, next, span > 0 and (into / span) or 1.0
end

function Text.stars(rating)
    local rounded = math.max(1, math.min(5, math.floor((tonumber(rating) or 5) + 0.5)))
    return ('%s%s'):format(string.rep('*', rounded), string.rep('.', 5 - rounded))
end
