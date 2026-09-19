Config = {}

Config.Debug = false

-- Force a bridge instead of auto-detecting. 'auto' is almost always right.
Config.Bridges = {
    framework = 'auto',   -- auto | qbox | qbcore
    target    = 'auto',   -- auto | ox_target | qb-target | builtin
    phone     = 'auto',   -- auto | XS-Phone | none

    -- Cabs spawn unlocked, but most servers run a keys system that blocks the
    -- engine until a vehicle is handed over. 'auto' finds the one you run.
    --   'qbx'            -> qbx_vehiclekeys (applied server-side)
    --   'qb-vehiclekeys' -> vehiclekeys:client:SetOwner
    --   'qs-vehiclekeys' -> exports['qs-vehiclekeys']:GiveKeys(plate)
    --   'custom'         -> exports['XS-TaxiJob']:OnGiveKeys(vehicle, plate)
    --   'none'           -> no keys system on this server
    keys      = 'auto',
}

-- ─────────────────────────────────────────────────────────────
-- Depot
-- Where the job starts. The blip puts it on the map, the terminal is the
-- world prop players interact with, and the cab spawns are where rented
-- vehicles appear and must be returned.
-- ─────────────────────────────────────────────────────────────
Config.Depot = {}

-- Downtown Cab Co. in Alta. Move this if your map uses a different building.
Config.Depot.blip = {
    coords = vec3(895.47, -178.92, 73.70),
    sprite = 198,
    color  = 5,
    scale  = 0.75,
    label  = 'Taxi Depot',
}

-- The terminal players interact with to sign on. A target zone is placed here;
-- with no target resource running, this becomes a marker and an E prompt.
Config.Depot.terminal = {
    coords   = vec4(895.47, -178.92, 73.70, 242.21),
    size     = vec3(1.2, 1.2, 1.4),
    distance = 2.0,
    label    = 'Taxi terminal',
}

-- The dispatcher. A person to talk to rather than a circle on the floor.
-- Switch this off, or run no target resource, and the terminal zone above is
-- used instead — an entity is not something the built-in marker fallback can
-- interact with.
Config.Depot.dispatcher = {
    enabled  = true,
    model    = 'a_m_m_business_01',
    coords   = vec4(895.47, -178.92, 73.70, 242.21),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    label    = 'Talk to the dispatcher',
    distance = 2.0,

    -- How close you have to get before the dispatcher is spawned. The ground
    -- is only probed once the map around the depot has loaded, so spawning
    -- from across the city would put them at the configured z instead.
    spawnRange = 120.0,
}

-- Opens the terminal from wherever you are. At the depot anybody can use it;
-- away from it, only a driver already signed on — so the cab has a terminal in
-- it without the depot becoming something you can skip.
Config.Depot.command = 'cab'

-- A key for the same thing. Left empty so it cannot fight another resource for
-- a binding; players set it themselves under Settings, Key Bindings, FiveM.
-- Put something like 'F6' here to ship a default.
Config.Depot.key = ''

-- How far from the depot counts as being at it, for the command above.
Config.Depot.useRange = 25.0

-- Cab spawn and return slots. A free slot is picked on rental; returning
-- means parking within Config.Vehicles.returnDistance of any of them.
Config.Depot.cabSpawns = {
    vec4(908.57, -183.39, 72.75, 236.27),
    vec4(906.94, -186.33, 72.61, 237.31),
    vec4(905.22, -189.03, 72.43, 239.54),
    vec4(903.63, -191.92, 72.39, 238.21),
}

-- ─────────────────────────────────────────────────────────────
-- Vehicles
-- Cabs are rented, not owned. The deposit is held while the cab is out and
-- returned when it comes back — damaged cabs get a repair fee taken off it.
-- Each entry lists the reputation tier needed to rent it.
-- ─────────────────────────────────────────────────────────────
Config.Vehicles = {}

Config.Vehicles.deposit = 500
Config.Vehicles.returnDistance = 8.0

-- Fraction of the deposit kept per point of body damage, capped at the
-- whole deposit. 0 turns damage fees off entirely.
Config.Vehicles.damageFeeRate = 0.6

Config.Vehicles.list = {
    {
        model   = 'taxi',
        label   = 'Taxi',
        tier    = 1,
        -- Multiplies the fare. Slower, cheaper cabs earn less per trip.
        rate    = 1.0,
        plate   = 'TAXI',
    },
    {
        model   = 'stanier',
        label   = 'Stanier',
        tier    = 2,
        rate    = 1.05,
        plate   = 'CAB',
    },
    {
        model   = 'primo2',
        label   = 'Primo Custom',
        tier    = 3,
        rate    = 1.15,
        plate   = 'CAB',
    },
    {
        model   = 'baller3',
        label   = 'Baller',
        tier    = 4,
        rate    = 1.3,
        plate   = 'LUX',
    },
    {
        model   = 'stretch',
        label   = 'Stretch',
        tier    = 5,
        rate    = 1.5,
        plate   = 'LUX',
    },
}

-- ─────────────────────────────────────────────────────────────
-- The meter
-- Base fare on pickup, then distance travelled plus time spent waiting.
-- Waiting only accrues while a passenger is aboard and the cab is stopped,
-- so sitting at the depot earns nothing.
-- ─────────────────────────────────────────────────────────────
Config.Meter = {}

Config.Meter.flagfall = 12          -- charged the moment a passenger gets in
Config.Meter.perKm = 9.0
Config.Meter.perWaitingMinute = 0.9
Config.Meter.waitingSpeedThreshold = 2.0   -- m/s below which waiting time accrues
Config.Meter.minimumFare = 20

-- Night rides pay more. Hours are in-game, 24h, start inclusive.
Config.Meter.nightBonus = { from = 22, to = 6, multiplier = 1.25 }

-- The account payouts land in, and where the passenger's money comes from
-- on player-hailed rides.
Config.Meter.account = 'cash'

-- ─────────────────────────────────────────────────────────────
-- Ride quality
-- Every fare starts at five stars and loses them for bad driving. The rating
-- sets the tip and how much reputation the fare is worth, so driving well is
-- the progression, not the number of trips.
-- ─────────────────────────────────────────────────────────────
Config.Quality = {}

Config.Quality.speedLimit = 30.0          -- m/s (~108 km/h) before speeding counts
Config.Quality.speedGracePeriod = 4       -- seconds over the limit before a penalty

-- Penalties, in stars. They stack, and the rating floors at 1.
Config.Quality.penalties = {
    collision      = 0.5,
    speeding       = 0.25,
    passengerHurt  = 1.5,
    cabFlipped     = 1.0,
}

-- Tip as a fraction of the fare, by rounded star rating.
Config.Quality.tips = {
    [5] = 0.25,
    [4] = 0.15,
    [3] = 0.07,
    [2] = 0.0,
    [1] = 0.0,
}

-- ─────────────────────────────────────────────────────────────
-- Reputation
-- Earned per completed fare, scaled by the rating. Tiers unlock vehicles and
-- multiply every fare, so a veteran driver out-earns a new one in the same cab.
-- ─────────────────────────────────────────────────────────────
Config.Reputation = {}

Config.Reputation.perFare = 3
Config.Reputation.ratingScale = true       -- multiply perFare by rating/5
Config.Reputation.cancelPenalty = 2        -- lost for abandoning a fare

Config.Reputation.tiers = {
    { tier = 1, at = 0,   label = 'Trainee',  fareMultiplier = 1.0 },
    { tier = 2, at = 40,  label = 'Driver',   fareMultiplier = 1.08 },
    { tier = 3, at = 140, label = 'Veteran',  fareMultiplier = 1.16 },
    { tier = 4, at = 320, label = 'Elite',    fareMultiplier = 1.25 },
    { tier = 5, at = 650, label = 'Legend',   fareMultiplier = 1.35 },
}

-- ─────────────────────────────────────────────────────────────
-- Fares
-- NPC fares keep a lone driver busy. Points are grouped by area so a fare can
-- prefer a destination across town, and premium areas stay locked until the
-- driver has the reputation for them.
-- ─────────────────────────────────────────────────────────────
Config.Fares = {}

Config.Fares.searchRadius = 1200.0     -- only offer pickups within this range
Config.Fares.pickupTimeout = 180       -- seconds to reach the pickup before the fare gives up
Config.Fares.pickupDistance = 12.0     -- how close a PLAYER hail needs you before they can get in

-- Pickups and drop-offs anywhere on the road network rather than from the
-- named list below. The server picks the spots; the client puts them on the
-- nearest road, so they land at a kerb rather than in somebody's garden.
--
-- Off falls back to Config.Fares.points, which is still there and still works.
Config.Fares.randomStreets = true

-- How far apart a random pickup and its drop-off have to be, in metres. Too
-- small and every fare is round the corner.
Config.Fares.minTripDistance = 600.0

-- And the furthest. The straight line, not the drive.
Config.Fares.maxTripDistance = 2600.0

-- How far out the passenger is put on the pavement. Far enough that they are
-- stood waiting as you come round the corner, rather than appearing in front
-- of the bonnet — and inside the distance the game will stream a ped at.
Config.Fares.spawnDistance = 170.0

-- How close you have to get before they leave the kerb and walk to the cab.
-- They will come to you; you do not have to park on the marker.
Config.Fares.walkDistance = 32.0
Config.Fares.dropoffDistance = 15.0
Config.Fares.boardingTimeout = 60      -- seconds a ped waits at the kerb before giving up
Config.Fares.cooldownBetween = 8       -- seconds after a drop-off before the next offer

-- ─────────────────────────────────────────────────────────────
-- Getting flagged down
-- With the roof lamp on, people on the pavement put a hand out as the cab goes
-- past. Pulling over takes them; driving on does not. The lamp is the off
-- switch for the whole thing, so a driver heading back to the depot at the end
-- of a shift can stop being stopped.
--
-- Only the taxi model has a sign on its roof. On the other cabs the lamp is a
-- state the job keeps rather than a bulb you can see.
-- ─────────────────────────────────────────────────────────────
Config.Flagdown = {}

Config.Flagdown.enabled = true

-- Toggles the lamp. Bind a key to it under Settings, Key Bindings, FiveM, or
-- put one in `key` to ship a default — empty so it cannot fight another
-- resource for a binding.
Config.Flagdown.command = 'lamp'
Config.Flagdown.key = ''

-- Lamp on the moment you sign on. Off means you start quiet and turn it on.
Config.Flagdown.lampOnAtSignOn = true

-- How far from the cab somebody can be and still flag it down.
Config.Flagdown.range = 45.0

-- How close you have to stop to pick them up.
Config.Flagdown.stopDistance = 12.0

-- Seconds they will stand there with a hand out before giving up on you.
Config.Flagdown.offerSeconds = 25

-- Seconds after one flag-down before another can happen. Without this a busy
-- pavement is a wall of people waving.
Config.Flagdown.cooldown = 45

-- Percent chance per check (twice a second while driving with the lamp on).
Config.Flagdown.chance = 4

-- Peds used as passengers. Picked at random.
Config.Fares.peds = {
    'a_m_y_business_01', 'a_f_y_business_02', 'a_m_m_business_01',
    'a_f_y_hipster_01', 'a_m_y_hipster_02', 'a_f_m_soucent_01',
    'a_m_y_downtown_01', 'a_f_y_tourist_01', 'a_m_y_tourist_01',
    'a_m_m_eastsa_01', 'a_f_y_femaleagent', 'a_m_y_stwhi_01',
}

-- Where fares start and end. `tier` gates the point behind reputation.
-- `area` lets a fare pick a destination somewhere else in the city.
Config.Fares.points = {
    -- Downtown and central
    { coords = vec4(195.63, -933.52, 30.69, 145.0), label = 'Legion Square',      area = 'central', tier = 1 },
    { coords = vec4(298.35, -584.24, 43.26, 70.0),  label = 'Pillbox Hospital',   area = 'central', tier = 1 },
    { coords = vec4(-247.85, -883.15, 31.22, 250.0), label = 'Alta Street',       area = 'central', tier = 1 },
    { coords = vec4(-531.24, -854.12, 29.29, 90.0), label = 'Little Seoul',       area = 'central', tier = 1 },
    { coords = vec4(-1035.62, -1396.75, 5.55, 200.0), label = 'Vespucci Canals',  area = 'central', tier = 1 },

    -- Beach and west side
    { coords = vec4(-1223.45, -1490.32, 4.36, 125.0), label = 'Vespucci Beach',   area = 'beach', tier = 1 },
    { coords = vec4(-1850.21, -1231.88, 13.02, 320.0), label = 'Del Perro Pier',  area = 'beach', tier = 1 },
    { coords = vec4(-1150.44, -1521.63, 4.38, 30.0), label = 'Magellan Avenue',   area = 'beach', tier = 1 },

    -- East side
    { coords = vec4(1145.32, -644.18, 57.04, 45.0), label = 'Mirror Park',        area = 'east', tier = 1 },
    { coords = vec4(100.21, -1940.55, 20.80, 320.0), label = 'Grove Street',      area = 'east', tier = 1 },
    { coords = vec4(1136.75, -982.44, 45.94, 100.0), label = 'Murrieta Heights',  area = 'east', tier = 2 },

    -- Hills and money
    { coords = vec4(-1300.11, 300.42, 63.15, 190.0), label = 'Rockford Hills',    area = 'hills', tier = 2 },
    { coords = vec4(-174.32, 502.18, 137.42, 15.0), label = 'Vinewood Hills',     area = 'hills', tier = 3 },
    { coords = vec4(925.44, 46.12, 80.91, 240.0),   label = 'Casino',             area = 'hills', tier = 3 },

    -- Airport and long hauls
    { coords = vec4(-1037.55, -2737.21, 20.17, 330.0), label = 'LSIA Terminal',   area = 'airport', tier = 2 },
    { coords = vec4(-1642.88, -1058.44, 13.15, 145.0), label = 'Del Perro Heights', area = 'airport', tier = 2 },

    -- County
    { coords = vec4(1961.32, 3740.55, 32.34, 210.0), label = 'Sandy Shores',      area = 'county', tier = 4 },
    { coords = vec4(-103.44, 6457.18, 31.63, 45.0),  label = 'Paleto Bay',        area = 'county', tier = 4 },
    { coords = vec4(1692.21, 4822.44, 42.06, 100.0), label = 'Grapeseed',         area = 'county', tier = 4 },
}

-- Long trips are worth more per kilometre. Applied when pickup and drop-off
-- are in different areas.
Config.Fares.crossTownBonus = 1.12

-- ─────────────────────────────────────────────────────────────
-- Hailing
-- Players calling a cab. The request goes to every on-duty driver in range;
-- the first to accept gets it. The passenger is charged the meter on arrival.
-- ─────────────────────────────────────────────────────────────
Config.Hail = {}

Config.Hail.enabled = true
Config.Hail.command = 'taxi'
Config.Hail.offerTimeout = 45          -- seconds before the request expires
Config.Hail.maxDistance = 3000.0       -- how far a driver can be and still be offered
Config.Hail.cooldown = 120             -- seconds between requests from one player
Config.Hail.playerFareMultiplier = 1.0 -- charge passengers more or less than NPCs

-- ─────────────────────────────────────────────────────────────
-- Shift
-- ─────────────────────────────────────────────────────────────
Config.Shift = {}

-- Ending a shift with a fare aboard costs reputation. Set to false to allow it
-- freely.
Config.Shift.penaliseAbandon = true

-- Auto-clock-off if the driver leaves the cab for this long, in seconds.
-- 0 disables it.
Config.Shift.awayTimeout = 300

-- ─────────────────────────────────────────────────────────────
-- Admin
-- ─────────────────────────────────────────────────────────────
Config.AdminAce = 'xstaxi.admin'

-- ─────────────────────────────────────────────────────────────
-- Uniform
-- Put drivers in cab company kit while they are signed on, and give them their
-- own clothes back when they sign off. Off by default — a server that lets
-- people drive in whatever they own should leave it that way.
--
-- This sets clothing components directly, so it needs no appearance resource.
-- Component ids: 1 mask, 3 arms, 4 legs, 5 bag, 6 shoes, 7 neck, 8 undershirt,
-- 9 vest, 10 badge, 11 top. Prop ids: 0 hat, 1 glasses, 2 ears.
--
-- Finding the numbers: use your clothing menu to build the outfit on a
-- character, then read the component values off it.
-- ─────────────────────────────────────────────────────────────
Config.Uniform = {}

Config.Uniform.enabled = false

-- Hand the outfit to your own appearance resource instead of setting
-- components here. It must export SetTaxiUniform(outfit) and ClearTaxiUniform().
-- If the export is missing or errors, the components below are used anyway.
Config.Uniform.useExport = false
Config.Uniform.exportResource = ''

-- drawable is the clothing item, texture is its colour variant.
Config.Uniform.male = {
    components = {
        [11] = { drawable = 55,  texture = 0 },   -- top
        [8]  = { drawable = 15,  texture = 0 },   -- undershirt
        [4]  = { drawable = 10,  texture = 0 },   -- legs
        [6]  = { drawable = 25,  texture = 0 },   -- shoes
        [3]  = { drawable = 0,   texture = 0 },   -- arms
    },
    props = {
        [0] = { drawable = 8, texture = 0 },      -- cap
    },
}

Config.Uniform.female = {
    components = {
        [11] = { drawable = 56,  texture = 0 },
        [8]  = { drawable = 14,  texture = 0 },
        [4]  = { drawable = 11,  texture = 0 },
        [6]  = { drawable = 25,  texture = 0 },
        [3]  = { drawable = 0,   texture = 0 },
    },
    props = {
        [0] = { drawable = 8, texture = 0 },
    },
}
