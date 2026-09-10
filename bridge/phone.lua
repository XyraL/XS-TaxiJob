Phone = { name = 'none' }

local function detect()
    local forced = Config.Bridges.phone
    if forced and forced ~= 'auto' then return forced end
    if GetResourceState('XS-Phone') == 'started' then return 'XS-Phone' end
    return 'none'
end

Phone.name = detect()

-- Sends a phone notification where a phone exists, and falls back to a plain
-- notification where it does not. Never required: the job works without one.
if IsDuplicityVersion() then
    function Phone.Notify(src, title, body)
        if Phone.name == 'XS-Phone' then
            local ok = pcall(function()
                exports['XS-Phone']:PushNotification(src, {
                    app = 'services',
                    title = title,
                    body = body,
                })
            end)
            if ok then return end
        end

        Framework.Notify(src, ('%s - %s'):format(title, body), 'inform')
    end
end
