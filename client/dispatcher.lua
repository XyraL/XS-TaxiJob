Dispatcher = { ped = nil }

--[[ The person you talk to at the depot.

     A marker on the floor is a thing you walk into; a dispatcher is somebody
     you go and see, which is the difference between a menu and a job. The
     ground zone is still there as the fallback — a server with no target
     resource cannot interact with an entity, and neither can one that has
     switched the ped off. ]]

local function spawn()
    local cfg = Config.Depot.dispatcher
    if not cfg or not cfg.enabled then return false end

    local model = joaat(cfg.model)
    RequestModel(model)

    -- Not forever. A model that never loads is a typo in config, and hanging
    -- on it takes the depot down with it.
    for _ = 1, 200 do
        if HasModelLoaded(model) then break end
        Wait(10)
    end

    if not HasModelLoaded(model) then
        print(('^3[XS-TaxiJob]^0 dispatcher model %s would not load, using the ground marker instead')
            :format(cfg.model))
        return false
    end

    local at = cfg.coords
    local ped = CreatePed(4, model, at.x, at.y, at.z - 1.0, at.w, false, false)

    SetModelAsNoLongerNeeded(model)

    if not ped or ped == 0 then return false end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedCanBeTargetted(ped, false)

    if cfg.scenario and cfg.scenario ~= '' then
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
    end

    Dispatcher.ped = ped

    return Target.addPed('xs_taxi_dispatcher', ped, cfg.label or 'Talk to the dispatcher', cfg.distance, function()
        OpenTerminal()
    end)
end

function Dispatcher.Remove()
    if Dispatcher.ped and DoesEntityExist(Dispatcher.ped) then
        Target.removePed('xs_taxi_dispatcher', Dispatcher.ped)
        DeleteEntity(Dispatcher.ped)
    end

    Dispatcher.ped = nil
end

CreateThread(function()
    -- After client/main.lua has put its zone down, so the two agree about
    -- which one is doing the talking.
    Wait(500)

    if spawn() then
        -- The ped answers now, so the patch of floor does not need to.
        Target.removeZone('xs_taxi_terminal')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Dispatcher.Remove() end
end)
