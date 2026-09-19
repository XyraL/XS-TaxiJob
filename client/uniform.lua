Uniform = { wearing = false }

local saved = nil

local COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = { 0, 1, 2, 6, 7 }

local function isFemale(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

local function outfitFor(ped)
    local U = Config.Uniform
    if not U or not U.enabled then return nil end
    return isFemale(ped) and U.female or U.male
end

-- Remember what they had on, so ending a shift gives it back rather than
-- leaving them in cab company kit.
local function capture(ped)
    local kit = { components = {}, props = {} }

    for _, id in ipairs(COMPONENTS) do
        kit.components[id] = {
            drawable = GetPedDrawableVariation(ped, id),
            texture  = GetPedTextureVariation(ped, id),
            palette  = GetPedPaletteVariation(ped, id),
        }
    end

    for _, id in ipairs(PROPS) do
        kit.props[id] = {
            drawable = GetPedPropIndex(ped, id),
            texture  = GetPedPropTextureIndex(ped, id),
        }
    end

    return kit
end

local function wear(ped, kit)
    for id, part in pairs(kit.components or {}) do
        SetPedComponentVariation(ped, tonumber(id), part.drawable or 0, part.texture or 0, part.palette or 0)
    end

    for id, prop in pairs(kit.props or {}) do
        id = tonumber(id)
        if (prop.drawable or -1) < 0 then
            ClearPedProp(ped, id)
        else
            SetPedPropIndex(ped, id, prop.drawable, prop.texture or 0, true)
        end
    end
end

function Uniform.Apply()
    local U = Config.Uniform
    if not U or not U.enabled then return end

    local ped = PlayerPedId()
    local outfit = outfitFor(ped)
    if not outfit then return end

    if U.useExport and U.exportResource ~= '' then
        if GetResourceState(U.exportResource) == 'started' then
            local ok = pcall(function()
                exports[U.exportResource]:SetTaxiUniform(outfit)
            end)
            if ok then Uniform.wearing = true return end
        end

        if Config.Debug then
            print(('^3[XS-TaxiJob]^0 %s did not take the uniform, falling back to components')
                :format(U.exportResource))
        end
    end

    if not saved then saved = capture(ped) end

    wear(ped, outfit)
    Uniform.wearing = true
end

function Uniform.Remove()
    if not Uniform.wearing then return end

    Uniform.wearing = false

    local U = Config.Uniform
    if U and U.useExport and U.exportResource ~= '' and GetResourceState(U.exportResource) == 'started' then
        local ok = pcall(function()
            exports[U.exportResource]:ClearTaxiUniform()
        end)
        if ok then saved = nil return end
    end

    if not saved then return end

    wear(PlayerPedId(), saved)
    saved = nil
end

-- A model change wipes the components, so anything we were told to wear has to
-- go back on. Without this, changing clothes mid-shift silently strips it.
RegisterNetEvent('XS-TaxiJob:client:reapplyUniform', function()
    if Uniform.wearing then
        saved = nil
        Uniform.Apply()
    end
end)

-- The event above is for a resource that changes the ped from outside. This
-- covers the ordinary way it happens: dying and respawning rebuilds the ped,
-- which wipes every component, and the job went on thinking they were still
-- in uniform for the rest of the shift.
AddEventHandler('playerSpawned', function()
    if not Uniform.wearing then return end

    saved = nil
    Uniform.Apply()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Uniform.Remove() end
end)
