(() => {
    if (typeof GetParentResourceName === 'function') return;

    const params = new URLSearchParams(location.search);
    const scenario = params.get('scenario') || 'on';
    const send = (action, payload) => window.dispatchEvent(new MessageEvent('message', { data: { action, ...payload } }));
    const clone = (v) => JSON.parse(JSON.stringify(v));

    const TIERS = [
        { tier: 1, at: 0, label: 'Trainee', fareMultiplier: 1.0 },
        { tier: 2, at: 40, label: 'Driver', fareMultiplier: 1.08 },
        { tier: 3, at: 140, label: 'Veteran', fareMultiplier: 1.16 },
        { tier: 4, at: 320, label: 'Elite', fareMultiplier: 1.25 },
        { tier: 5, at: 650, label: 'Legend', fareMultiplier: 1.35 },
    ];

    const CABS = [
        { model: 'taxi', label: 'Taxi', tier: 1, rate: 1.0 },
        { model: 'stanier', label: 'Stanier', tier: 2, rate: 1.05 },
        { model: 'primo2', label: 'Primo Custom', tier: 3, rate: 1.15 },
        { model: 'baller3', label: 'Baller', tier: 4, rate: 1.3 },
        { model: 'stretch', label: 'Stretch', tier: 5, rate: 1.5 },
    ];

    const RATES = {
        flagfall: 12, perKm: 9, perWaitingMinute: 0.9, minimumFare: 20, night: 1.25, crossTown: 1.12,
        player: 1, ownCar: 1, deposit: 500, damageFee: 0.6,
        tips: { 1: 0, 2: 0, 3: 0.07, 4: 0.15, 5: 0.25 },
        cabList: CABS.map((c) => ({ model: c.model, label: c.label, tier: c.tier, rate: c.rate })),
        tierList: TIERS.map((t) => ({ tier: t.tier, label: t.label, at: t.at, rate: t.fareMultiplier })),
        nightFrom: 22, nightTo: 6, saved: false,
    };
    let rates = clone(RATES);

    let locations = [
        {
            id: 1, name: 'Downtown Cab Co.', personal: false, job: '',
            desk: { x: 895.47, y: -178.92, z: 73.7, w: 242.21 },
            blip: { show: true, sprite: 198, color: 5, scale: 0.75 },
            dispatcher: { ped: true, model: 'a_m_m_business_01', scenario: 'WORLD_HUMAN_CLIPBOARD' },
            bays: [
                { x: 908.57, y: -183.39, z: 72.75, w: 236.27 },
                { x: 906.94, y: -186.33, z: 72.61, w: 237.31 },
                { x: 905.22, y: -189.03, z: 72.43, w: 239.54 },
                { x: 903.63, y: -191.92, z: 72.39, w: 238.21 },
            ],
            cabs: null,
        },
        {
            id: 2, name: 'Vespucci Cabs', personal: true, job: '',
            desk: { x: -1235.4, y: -1435.2, z: 4.32, w: 120.0 },
            blip: { show: true, sprite: 198, color: 46, scale: 0.75 },
            dispatcher: { ped: true, model: 'a_m_m_business_01', scenario: 'WORLD_HUMAN_CLIPBOARD' },
            bays: [{ x: -1244.1, y: -1441.6, z: 4.3, w: 33.0 }, { x: -1246.9, y: -1437.9, z: 4.3, w: 33.0 }],
            cabs: ['taxi', 'stanier'],
        },
        {
            id: 3, name: 'Sandy Shores Taxi', personal: true, job: '',
            desk: { x: 1853.2, y: 3686.4, z: 34.27, w: 210.0 },
            blip: { show: true, sprite: 198, color: 5, scale: 0.75 },
            dispatcher: { ped: true, model: 'a_m_m_business_01', scenario: 'WORLD_HUMAN_CLIPBOARD' },
            bays: [{ x: 1862.3, y: 3681.2, z: 33.8, w: 210.0 }],
            cabs: null,
        },
    ];

    const stats = {
        reputation: 62, tier: 2, tierLabel: 'Driver', fareMultiplier: 1.08,
        nextTier: { tier: 3, label: 'Veteran', at: 140 }, progress: 0.22,
        totalFares: 41, totalEarned: 6385, totalDistance: 118400, rating: 4.82,
    };

    const S = {
        name: 'Vincent Valentine',
        onDuty: scenario !== 'off' && scenario !== 'builder',
        vehicle: { model: 'taxi', label: 'Taxi', rate: 1.0, plate: 'TAXI', assignedPlate: 'TAXI4821' },
        location: 1,
        totals: { fares: 3, earned: 412, distance: 7400 },
        startedAt: 1700000000 - 1860,
        now: 1700000000,
        hasFare: false,
        deposit: 500,
        stats,
        tiers: TIERS,
        vehicles: CABS.map((c) => ({ ...c, locked: stats.tier < c.tier, offered: true })),
        recent: [
            { pickup_label: 'Legion Square', dropoff_label: 'Vespucci Beach', distance: 4100, fare: 92, tip: 23, rating: 5, kind: 'npc' },
            { pickup_label: 'Alta Street', dropoff_label: 'Mirror Park', distance: 3600, fare: 74, tip: 11, rating: 4.25, kind: 'player' },
            { pickup_label: 'Pillbox Hospital', dropoff_label: 'Del Perro Pier', distance: 6200, fare: 128, tip: 32, rating: 5, kind: 'npc' },
        ],
        leaderboard: [
            { rank: 1, name: 'Isabel Ferreira', tierLabel: 'Elite', reputation: 344, earned: 41200, rating: 4.9 },
            { rank: 2, name: 'Terrence Obi', tierLabel: 'Veteran', reputation: 212, earned: 26870, rating: 4.7 },
            { rank: 3, name: 'Vincent Valentine', tierLabel: 'Driver', reputation: 62, earned: 6385, rating: 4.82 },
            { rank: 4, name: 'Nadia Kowalski', tierLabel: 'Driver', reputation: 51, earned: 5110, rating: 4.6 },
        ],
        hailEnabled: true,
        isAdmin: true,
        lamp: true,
        locations,
        at: scenario === 'off' || scenario === 'builder' ? 1 : null,
        personalAllowed: false,
        jobOk: true,
        carReady: false,
        carProblem: 'Sit in the driver seat of your own car first.',
        me: { x: 412.6, y: -862.3, z: 29.3, h: 90 },
        keys: { tablet: 'F6', lamp: '/lamp' },
        offers: [],
        builder: null,
    };

    const offerPool = [
        { id: 11, passenger: 'Isabel Ferreira', origin: 'phone', street: 'Vespucci Boulevard', distance: 820, coords: { x: 196.2, y: -932.8, z: 30.7 }, expiresIn: 45 },
        { id: 12, passenger: 'Terrence Obi', origin: 'command', street: 'Alta Street', distance: 1900, coords: { x: -247.9, y: -883.2, z: 31.2 }, expiresIn: 45 },
    ];
    if (scenario === 'on' || scenario === 'admin') S.offers = clone(offerPool);

    let fare = null;
    let meterTimer = null;
    let draft = null;

    function meterTick() {
        const data = {
            onDuty: S.onDuty, running: !!(fare && fare.stage === 'riding'), hasFare: !!fare,
            stage: fare ? fare.stage : null, amount: fare ? Math.round(fare.amount) : 0,
            distance: fare ? fare.distance : 0, elapsed: fare ? fare.elapsed : 0, rating: fare ? fare.rating : 5,
            pickup: fare ? fare.pickup : null, dropoff: fare ? fare.dropoff : null, openEnded: fare ? fare.openEnded : false,
            kind: fare ? fare.kind : null, night: false, crossTown: fare ? fare.crossTown : false, flagfall: 12,
            pickupIn: fare && fare.stage === 'toPickup' ? 118 : null, away: fare ? fare.away : null,
            totals: S.totals, vehicle: S.vehicle ? S.vehicle.label : null, lamp: S.lamp,
            passenger: fare ? fare.passenger : null, fareId: fare ? 1 : null,
            pickupAt: fare ? fare.pickupAt : null, dropoffAt: fare && !fare.openEnded ? fare.dropoffAt : null,
            me: { x: S.me.x, y: S.me.y, h: S.me.h },
        };
        if (fare && fare.stage === 'riding') {
            fare.distance += 18;
            fare.elapsed += 0.5;
            fare.amount = 12 + (fare.distance / 1000) * 9 * 1.08;
            fare.away = Math.max(0, fare.away - 18);
        }
        send('meter', { data });
    }

    function startMeter() {
        clearInterval(meterTimer);
        meterTimer = setInterval(meterTick, 500);
        meterTick();
    }

    function stopMeter() {
        clearInterval(meterTimer);
        send('meter', { data: { onDuty: false } });
    }

    function makeFare(kind, extra) {
        fare = Object.assign({
            kind, stage: 'riding', amount: 12, distance: 940, elapsed: 74, rating: 4.75,
            pickup: 'Power Street', dropoff: 'Del Perro Pier', openEnded: false, crossTown: true,
            pickupAt: { x: 296.1, y: -900.4 }, dropoffAt: { x: -1850.2, y: -1231.9 }, away: 2860,
        }, extra || {});
        S.hasFare = true;
    }

    const ok = (extra) => Object.assign({ ok: true }, extra || {});
    const no = (error) => ({ ok: false, error });

    const handlers = {
        getState: () => clone(Object.assign({}, S, { locations, builder: draft, hasFare: !!fare })),
        close: () => ok(),
        summaryShown: () => ok(),
        summaryClosed: () => ok(),
        gps: () => ok(),
        setLamp: (d) => {
            S.lamp = !!d.on;
            setTimeout(() => send('lamp', { data: { on: S.lamp } }), 10);
            return ok();
        },
        startShift: (d) => {
            S.onDuty = true;
            S.location = d.location;
            if (d.personal) S.vehicle = { model: 'personal', label: 'Sultan', rate: 1.0, plate: 'VV 1985', personal: true };
            else S.vehicle = Object.assign({}, CABS.find((c) => c.model === d.model), { assignedPlate: 'TAXI4821' });
            S.totals = { fares: 0, earned: 0, distance: 0 };
            S.startedAt = S.now;
            setTimeout(() => { send('close', {}); startMeter(); }, 50);
            return ok();
        },
        endShift: () => {
            const summary = { fares: S.totals.fares, earned: S.totals.earned, distance: S.totals.distance, minutes: 31,
                refund: S.vehicle && S.vehicle.personal ? 0 : 500, damageFee: 0, abandoned: false,
                personal: !!(S.vehicle && S.vehicle.personal), returned: true };
            S.onDuty = false;
            fare = null;
            S.hasFare = false;
            stopMeter();
            return ok({ summary });
        },
        requestFare: () => {
            if (fare) return no('You already have a fare.');
            makeFare('npc', { stage: 'toPickup', distance: 0, elapsed: 0, away: 640 });
            startMeter();
            return ok();
        },
        cancelFare: () => {
            fare = null;
            S.hasFare = false;
            return ok();
        },
        endRide: () => {
            const amount = fare ? Math.round(fare.amount) : 0;
            fare = null;
            S.hasFare = false;
            S.totals.fares += 1;
            S.totals.earned += amount + 14;
            setTimeout(() => send('fareComplete', { data: { fare: amount, tip: 14, rating: 4.75, reputation: 3 } }), 30);
            return ok();
        },
        acceptRide: (d) => {
            const offer = S.offers.find((o) => o.id === d.id);
            if (!offer) return no('That call has gone.');
            S.offers = [];
            makeFare('player', { passenger: offer.passenger, pickup: offer.street, dropoff: 'Wherever they ask', openEnded: true, stage: 'toPickup', away: offer.distance, pickupAt: offer.coords, dropoffAt: null, crossTown: false });
            setTimeout(() => { offerPool.forEach((o) => send('rideGone', { data: { id: o.id } })); send('close', {}); startMeter(); }, 30);
            return ok();
        },
        passRide: (d) => {
            S.offers = S.offers.filter((o) => o.id !== d.id);
            return ok();
        },
        adminState: () => ok({
            drivers: [
                { src: 1, citizenid: 'VV1985', name: 'Vincent Valentine', vehicle: 'Taxi', personal: false, location: 'Downtown Cab Co.', fare: fare ? { boarded: fare.stage === 'riding' } : null, earned: S.totals.earned, reputation: 62 },
                { src: 7, citizenid: 'IF2203', name: 'Isabel Ferreira', vehicle: 'Baller', personal: false, location: 'Downtown Cab Co.', fare: null, earned: 1240, reputation: 344 },
                { src: 9, citizenid: 'TO7741', name: 'Terrence Obi', vehicle: 'Sultan', personal: true, location: 'Vespucci Cabs', fare: { boarded: true }, earned: 860, reputation: 212 },
            ],
            totals: { onDuty: 3, earnedThisShift: S.totals.earned + 2100, faresThisShift: 14, allTime: { fares: 1922, earned: 212400 } },
            settings: { paused: false, hailEnabled: true, fareMultiplier: 1.0 },
        }),
        adminSetting: () => ok(),
        adminRates: () => ok({ rates: clone(rates) }),
        adminSaveRates: (d) => {
            const v = (d && d.rates) || {};
            ['flagfall', 'perKm', 'perWaitingMinute', 'minimumFare', 'night', 'crossTown', 'player', 'ownCar', 'deposit', 'damageFee'].forEach((k) => {
                if (Number.isFinite(v[k])) rates[k] = Math.max(0, v[k]);
            });
            Object.keys(v.tips || {}).forEach((k) => { if (Number.isFinite(v.tips[k])) rates.tips[k] = v.tips[k]; });
            rates.cabList.forEach((c) => { if (Number.isFinite((v.cabs || {})[c.model])) c.rate = v.cabs[c.model]; });
            rates.tierList.forEach((t) => { if (Number.isFinite((v.tiers || {})[t.tier])) t.rate = v.tiers[t.tier]; });
            rates.saved = true;
            return ok({ rates: clone(rates) });
        },
        adminResetRates: () => {
            rates = clone(RATES);
            return ok({ rates: clone(rates) });
        },
        adminSetReputation: () => ok(),
        adminEndShift: () => ok(),
        adminWipe: () => ok(),
        adminClearFare: () => ok(),
        adminLocations: () => ok({ locations: clone(locations), cabs: CABS.map((c) => ({ model: c.model, label: c.label, tier: c.tier })) }),
        builderOpen: (d) => {
            draft = d.id ? clone(locations.find((l) => l.id === d.id)) : {
                id: null, name: '', desk: { x: S.me.x, y: S.me.y, z: S.me.z, w: S.me.h },
                blip: { show: true, sprite: 198, color: 5, scale: 0.75 },
                dispatcher: { ped: true, model: 'a_m_m_business_01', scenario: 'WORLD_HUMAN_CLIPBOARD' },
                bays: [], personal: false, job: '', cabs: null,
            };
            return ok({ draft: clone(draft) });
        },
        builderField: (d) => {
            if (!draft) return no('No draft.');
            const [a, b] = String(d.key).split('.');
            if (b) draft[a][b] = (a === 'blip' && b !== 'show') ? Number(d.value) : d.value;
            else draft[a] = d.value;
            return ok({ draft: clone(draft) });
        },
        builderDesk: () => {
            draft.desk = { x: S.me.x, y: S.me.y, z: S.me.z, w: S.me.h };
            return ok({ draft: clone(draft) });
        },
        builderBay: () => {
            if (draft.bays.length >= 16) return no('A depot can have 16 bays.');
            draft.bays.push({ x: S.me.x + draft.bays.length * 3, y: S.me.y - 6, z: S.me.z, w: S.me.h });
            return ok({ draft: clone(draft) });
        },
        builderRemoveBay: (d) => {
            draft.bays.splice(d.index - 1, 1);
            return ok({ draft: clone(draft) });
        },
        builderSave: () => {
            if (!draft.name) return no('Give the depot a name.');
            if (!draft.bays.length && !draft.personal) return no('Add at least one cab bay, or let drivers use their own cars.');
            if (draft.id) locations = locations.map((l) => (l.id === draft.id ? clone(draft) : l));
            else locations.push(Object.assign(clone(draft), { id: Math.max(...locations.map((l) => l.id)) + 1 }));
            draft = null;
            return ok({ locations: clone(locations) });
        },
        builderCancel: () => { draft = null; return ok(); },
        builderDelete: (d) => {
            if (locations.length <= 1) return no('Keep at least one depot.');
            locations = locations.filter((l) => l.id !== d.id);
            draft = null;
            return ok({ locations: clone(locations) });
        },
    };

    window.post = (name, data = {}) => {
        const handler = handlers[name];
        const result = handler ? handler(data || {}) : { ok: false, error: `mock has no ${name}` };
        return new Promise((resolve) => setTimeout(() => resolve(result), 40));
    };

    window.__mock = { send, S, handlers, makeFare: (k, e) => { makeFare(k, e); startMeter(); } };

    document.addEventListener('DOMContentLoaded', () => {
        document.body.style.background = '#1b2026 url("assets/maps/tiles/3_3_5.webp") center/cover';
        if (scenario === 'fare') makeFare('npc');
        if (scenario === 'builder') {
            handlers.builderOpen({ id: 1 });
        }
        if (S.onDuty) startMeter();
        setTimeout(() => send('open', { state: handlers.getState() }), 150);
        if (scenario === 'on') {
            setTimeout(() => send('rideOffer', { data: Object.assign({}, offerPool[0], { answerWith: 'F6', id: 13, passenger: 'Nadia Kowalski', street: 'Strawberry Avenue', distance: 1240 }) }), 1200);
        }
    });
})();
