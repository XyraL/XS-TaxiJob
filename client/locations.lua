Depots = { list = {}, byId = {} }

local blips = {}
local peds = {}
local zones = {}

local function deskVec(loc)
    return vec3(loc.desk.x, loc.desk.y, loc.desk.z)
end

local function removePed(id)
    local ped = peds[id]
    if ped and DoesEntityExist(ped) then
        Target.removePed('xs_taxi_desk_' .. id, ped)
        DeleteEntity(ped)
    end
    peds[id] = nil
end

local function removeZone(id)
    if zones[id] then
        Target.removeZone('xs_taxi_desk_' .. id)
        zones[id] = nil
    end
end

local function clear(id)
    if blips[id] and DoesBlipExist(blips[id]) then RemoveBlip(blips[id]) end
    blips[id] = nil
    removePed(id)
    removeZone(id)
end

local function interact(loc)
    OpenTablet({ at = loc.id })
end

local function addZone(loc)
    if zones[loc.id] then return end
    zones[loc.id] = true
    Target.addZone('xs_taxi_desk_' .. loc.id, {
        coords = vec4(loc.desk.x, loc.desk.y, loc.desk.z, loc.desk.w),
        size = vec3(1.4, 1.4, 2.0),
        distance = 2.2,
        label = ('%s: taxi terminal'):format(loc.name),
    }, function() interact(loc) end)
end

local function addBlip(loc)
    if not loc.blip or loc.blip.show == false then return end
    local blip = AddBlipForCoord(loc.desk.x, loc.desk.y, loc.desk.z)
    SetBlipSprite(blip, loc.blip.sprite or 198)
    SetBlipColour(blip, loc.blip.color or 5)
    SetBlipScale(blip, (loc.blip.scale or 0.75) + 0.0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(loc.name)
    EndTextCommandSetBlipName(blip)
    blips[loc.id] = blip
end

local function usesPed(loc)
    return loc.dispatcher and loc.dispatcher.ped ~= false and Target.name ~= 'builtin'
end

local function spawnPed(loc)
    local model = joaat(loc.dispatcher.model or Config.Depot.dispatcher.model)
    if not IsModelInCdimage(model) then return false end

    RequestModel(model)
    for _ = 1, 200 do
        if HasModelLoaded(model) then break end
        Wait(10)
    end
    if not HasModelLoaded(model) then return false end

    local at = loc.desk
    local found, groundZ = GetGroundZFor_3dCoord(at.x, at.y, at.z + 1.0, false)
    local ped = CreatePed(4, model, at.x, at.y, found and groundZ or (at.z - 1.0), at.w + 0.0, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return false end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedCanBeTargetted(ped, false)

    local scenario = loc.dispatcher.scenario
    if scenario and scenario ~= '' then TaskStartScenarioInPlace(ped, scenario, 0, true) end

    peds[loc.id] = ped

    if not Target.addPed('xs_taxi_desk_' .. loc.id, ped, ('%s: talk to the dispatcher'):format(loc.name), 2.2, function()
        interact(loc)
    end) then
        addZone(loc)
    end

    return true
end

function Depots.Set(list)
    for id in pairs(Depots.byId) do clear(id) end

    Depots.list = type(list) == 'table' and list or {}
    Depots.byId = {}

    for _, loc in ipairs(Depots.list) do
        Depots.byId[loc.id] = loc
        addBlip(loc)
        if not usesPed(loc) then addZone(loc) end
    end

    SendNUIMessage({ action = 'locations', data = Depots.list })
end

function Depots.Near(range)
    local here = GetEntityCoords(PlayerPedId())
    local best, bestAway
    for _, loc in ipairs(Depots.list) do
        local away = #(here - deskVec(loc))
        if away <= (range or Config.Depot.useRange) and (not bestAway or away < bestAway) then
            best, bestAway = loc, away
        end
    end
    return best
end

function Depots.Nearest()
    local here = GetEntityCoords(PlayerPedId())
    local best, bestAway
    for _, loc in ipairs(Depots.list) do
        local away = #(here - deskVec(loc))
        if not bestAway or away < bestAway then best, bestAway = loc, away end
    end
    return best, bestAway
end

function Depots.AtAnyBay(coords)
    for _, loc in ipairs(Depots.list) do
        for _, bay in ipairs(loc.bays or {}) do
            if #(coords - vec3(bay.x, bay.y, bay.z)) <= Config.Vehicles.returnDistance then return true end
        end
    end
    return false
end

RegisterNetEvent('XS-TaxiJob:client:locations', function(list)
    Depots.Set(list)
end)

CreateThread(function()
    Wait(1000)
    local list = lib.callback.await('XS-TaxiJob:server:locations', false)
    if list then Depots.Set(list) end

    local range = Config.Depot.dispatcher.spawnRange or 120.0

    while true do
        local here = GetEntityCoords(PlayerPedId())
        local soonest = 2000

        for _, loc in ipairs(Depots.list) do
            if usesPed(loc) and not zones[loc.id] then
                local away = #(here - deskVec(loc))
                if away <= range then
                    if not peds[loc.id] or not DoesEntityExist(peds[loc.id]) then
                        peds[loc.id] = nil
                        if not spawnPed(loc) then addZone(loc) end
                    end
                    soonest = 1000
                elseif peds[loc.id] then
                    removePed(loc.id)
                end
            end
        end

        Wait(soonest)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(Depots.byId) do clear(id) end
end)
