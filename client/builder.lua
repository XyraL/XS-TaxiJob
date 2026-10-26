Builder = { draft = nil }

local MAX_BAYS = 16

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

local function round(n)
    return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100
end

local function spot(entity)
    local at = GetEntityCoords(entity)
    return { x = round(at.x), y = round(at.y), z = round(at.z), w = round(GetEntityHeading(entity)) }
end

local function blank()
    local ped = PlayerPedId()
    return {
        id = nil,
        name = '',
        desk = spot(ped),
        blip = { show = true, sprite = 198, color = 5, scale = 0.75 },
        dispatcher = {
            ped = true,
            model = Config.Depot.dispatcher.model,
            scenario = Config.Depot.dispatcher.scenario,
        },
        bays = {},
        personal = false,
        job = '',
        cabs = nil,
    }
end

local function push()
    SendNUIMessage({ action = 'builder', data = Builder.draft })
end

local function admin(cb)
    if not Taxi.isAdmin then
        cb({ ok = false, error = 'You are not allowed to do that.' })
        return false
    end
    return true
end

RegisterNUICallback('builderOpen', function(data, cb)
    if not admin(cb) then return end

    local id = tonumber(data and data.id)
    if id then
        local loc = Depots.byId[id]
        if not loc then
            cb({ ok = false, error = 'That depot is gone.' })
            return
        end
        Builder.draft = copy(loc)
    else
        Builder.draft = blank()
    end

    cb({ ok = true, draft = Builder.draft })
end)

RegisterNUICallback('builderField', function(data, cb)
    if not admin(cb) then return end
    local draft = Builder.draft
    if not draft or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    local key, value = data.key, data.value

    if key == 'name' or key == 'job' then
        draft[key] = tostring(value or ''):sub(1, key == 'name' and 48 or 32)
    elseif key == 'personal' then
        draft.personal = value == true
    elseif key == 'blip.show' then
        draft.blip.show = value == true
    elseif key == 'blip.sprite' or key == 'blip.color' or key == 'blip.scale' then
        draft.blip[key:sub(6)] = tonumber(value) or draft.blip[key:sub(6)]
    elseif key == 'dispatcher.ped' then
        draft.dispatcher.ped = value == true
    elseif key == 'dispatcher.model' or key == 'dispatcher.scenario' then
        draft.dispatcher[key:sub(12)] = tostring(value or ''):sub(1, 64)
    elseif key == 'cabs' then
        draft.cabs = type(value) == 'table' and value or nil
    end

    cb({ ok = true, draft = draft })
end)

RegisterNUICallback('builderDesk', function(_, cb)
    if not admin(cb) then return end
    if not Builder.draft then
        cb({ ok = false })
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        cb({ ok = false, error = 'Get out and stand where the dispatcher should stand.' })
        return
    end

    Builder.draft.desk = spot(ped)
    cb({ ok = true, draft = Builder.draft })
end)

RegisterNUICallback('builderBay', function(_, cb)
    if not admin(cb) then return end
    local draft = Builder.draft
    if not draft then
        cb({ ok = false })
        return
    end

    if #draft.bays >= MAX_BAYS then
        cb({ ok = false, error = ('A depot can have %d bays.'):format(MAX_BAYS) })
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    draft.bays[#draft.bays + 1] = spot(vehicle ~= 0 and vehicle or ped)

    cb({ ok = true, draft = draft })
end)

RegisterNUICallback('builderRemoveBay', function(data, cb)
    if not admin(cb) then return end
    local draft = Builder.draft
    local index = tonumber(data and data.index)
    if not draft or not index or not draft.bays[index] then
        cb({ ok = false })
        return
    end

    table.remove(draft.bays, index)
    cb({ ok = true, draft = draft })
end)

RegisterNUICallback('builderSave', function(_, cb)
    if not admin(cb) then return end
    local draft = Builder.draft
    if not draft then
        cb({ ok = false, error = 'Nothing to save.' })
        return
    end

    local result = lib.callback.await('XS-TaxiJob:server:adminSaveLocation', false, { id = draft.id, data = draft })
    if result and result.ok then
        Builder.draft = nil
        Framework.Notify(('%s saved.'):format(draft.name), 'success')
    end

    cb(result or { ok = false, error = 'The server did not answer.' })
end)

RegisterNUICallback('builderCancel', function(_, cb)
    Builder.draft = nil
    cb({ ok = true })
end)

RegisterNUICallback('builderDelete', function(data, cb)
    if not admin(cb) then return end
    local id = tonumber(data and data.id)
    local result = lib.callback.await('XS-TaxiJob:server:adminDeleteLocation', false, { id = id })
    if result and result.ok and Builder.draft and Builder.draft.id == id then Builder.draft = nil end
    cb(result or { ok = false, error = 'The server did not answer.' })
end)

local function label(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 214, 64, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local draft = Builder.draft

        if draft and Taxi.isAdmin then
            local here = GetEntityCoords(PlayerPedId())
            local desk = draft.desk

            if desk and #(here - vec3(desk.x, desk.y, desk.z)) < 150.0 then
                DrawMarker(1, desk.x, desk.y, desk.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.9, 0.9, 0.6, 255, 196, 0, 140, false, false, 2, false, nil, nil, false)
                label(desk.x, desk.y, desk.z + 1.1, ('%s: dispatcher'):format(draft.name ~= '' and draft.name or 'New depot'))
            end

            for index, bay in ipairs(draft.bays) do
                if #(here - vec3(bay.x, bay.y, bay.z)) < 150.0 then
                    DrawMarker(36, bay.x, bay.y, bay.z + 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, bay.w,
                        1.2, 1.2, 1.2, 255, 196, 0, 170, false, false, 2, false, nil, nil, false)
                    DrawMarker(43, bay.x, bay.y, bay.z - 0.45, 0.0, 0.0, 0.0, 0.0, 0.0, bay.w,
                        2.3, 5.0, 0.25, 255, 196, 0, 60, false, false, 2, false, nil, nil, false)
                    label(bay.x, bay.y, bay.z + 1.5, ('Bay %d'):format(index))
                end
            end

            Wait(0)
        else
            Wait(750)
        end
    end
end)
