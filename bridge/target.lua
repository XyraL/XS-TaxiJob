Target = { name = 'builtin' }

local function detect()
    local forced = Config.Bridges.target
    if forced and forced ~= 'auto' then return forced end
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    return 'builtin'
end

Target.name = detect()

local builtinZones = {}

-- Registers an interaction at a fixed point. With no target resource running,
-- the zone falls back to a marker and an E prompt so the job still works.
function Target.addZone(id, zone, onSelect)
    if Target.name == 'ox_target' then
        exports.ox_target:addBoxZone({
            name = id,
            coords = vec3(zone.coords.x, zone.coords.y, zone.coords.z),
            size = zone.size,
            rotation = zone.coords.w or 0.0,
            debug = Config.Debug,
            options = {
                {
                    name = id,
                    label = zone.label,
                    icon = zone.icon or 'fa-solid fa-taxi',
                    distance = zone.distance or 2.0,
                    onSelect = onSelect,
                },
            },
        })
        return
    end

    if Target.name == 'qb-target' then
        exports['qb-target']:AddBoxZone(id, vec3(zone.coords.x, zone.coords.y, zone.coords.z),
            zone.size.x, zone.size.y, {
                name = id,
                heading = zone.coords.w or 0.0,
                debugPoly = Config.Debug,
                minZ = zone.coords.z - (zone.size.z / 2),
                maxZ = zone.coords.z + (zone.size.z / 2),
            }, {
                options = { { label = zone.label, icon = 'fas fa-taxi', action = onSelect } },
                distance = zone.distance or 2.0,
            })
        return
    end

    builtinZones[id] = { zone = zone, onSelect = onSelect }
end

function Target.removeZone(id)
    if Target.name == 'ox_target' then
        exports.ox_target:removeZone(id)
    elseif Target.name == 'qb-target' then
        exports['qb-target']:RemoveZone(id)
    else
        builtinZones[id] = nil
    end
end

if Target.name == 'builtin' then
    CreateThread(function()
        while true do
            local wait = 900
            local ped = PlayerPedId()
            local here = GetEntityCoords(ped)

            for _, entry in pairs(builtinZones) do
                local point = vec3(entry.zone.coords.x, entry.zone.coords.y, entry.zone.coords.z)
                local away = #(here - point)

                if away < 18.0 then
                    wait = 0
                    DrawMarker(21, point.x, point.y, point.z + 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.28, 0.28, 0.28, 240, 200, 40, 120, false, true, 2, nil, nil, false)

                    if away < (entry.zone.distance or 2.0) then
                        lib.showTextUI(('[E] %s'):format(entry.zone.label))
                        if IsControlJustReleased(0, 38) then
                            lib.hideTextUI()
                            entry.onSelect()
                        end
                    else
                        lib.hideTextUI()
                    end
                end
            end

            Wait(wait)
        end
    end)
end
