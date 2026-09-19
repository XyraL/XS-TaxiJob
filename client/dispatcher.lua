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

    --[[ Put its feet on the floor.

         The z in config is a target zone's centre, which sits about chest
         height — spawning a ped there and freezing it buries it to the neck,
         or drops it through the floor if you guess an offset and guess wrong.
         Ask the map where the ground is instead.

         The probe needs collision loaded, so it answers with nothing when the
         depot is streamed out. The configured z is the fallback, and a frozen
         ped a little off the floor is still a ped you can see and talk to. ]]
    local found, groundZ = GetGroundZFor_3dCoord(at.x, at.y, at.z + 1.0, false)
    local z = found and groundZ or at.z

    local ped = CreatePed(4, model, at.x, at.y, z, at.w, false, false)

    SetModelAsNoLongerNeeded(model)

    if not ped or ped == 0 then
        print('^1[XS-TaxiJob]^0 the dispatcher ped could not be created')
        return false
    end

    if Config.Debug then
        print(('^2[XS-TaxiJob]^0 dispatcher at %.2f, %.2f, %.2f (ground %s)')
            :format(at.x, at.y, z, found and 'found' or 'not loaded, used config z'))
    end

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

--[[ Kept alive near the depot and nowhere else.

     Spawning once at resource start does not work: the ground probe needs
     collision, and a player who logs in on the other side of the map has none
     loaded at the depot. The game also clears local peds it decides are far
     away, so one that spawned successfully can quietly stop existing.

     So it is checked rather than assumed — cheaply, twice a second at most,
     and only while somebody is close enough to see it. ]]
CreateThread(function()
    -- After client/main.lua has put its zone down, so the two agree about
    -- which one is doing the talking.
    Wait(500)

    local cfg = Config.Depot.dispatcher
    if not cfg or not cfg.enabled then return end

    local at = cfg.coords
    local point = vec3(at.x, at.y, at.z)
    local took = false

    while true do
        local away = #(GetEntityCoords(PlayerPedId()) - point)

        if away <= (cfg.spawnRange or 120.0) then
            if not Dispatcher.ped or not DoesEntityExist(Dispatcher.ped) then
                Dispatcher.ped = nil

                if spawn() then
                    -- The ped answers now, so the patch of floor does not
                    -- need to. Only done once: putting the zone back every
                    -- time the ped is cleaned up would register it twice.
                    if not took then
                        Target.removeZone('xs_taxi_terminal')
                        took = true
                    end
                end
            end
        elseif Dispatcher.ped then
            Dispatcher.Remove()
        end

        Wait(away <= (cfg.spawnRange or 120.0) and 2000 or 500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Dispatcher.Remove() end
end)
