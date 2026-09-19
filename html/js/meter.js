window.Meter = (() => {
    const root = document.getElementById('meter');
    const title = document.getElementById('meter-title');
    const vehicle = document.getElementById('meter-vehicle');
    const amount = document.getElementById('meter-amount');
    const cap = document.getElementById('meter-cap');
    const distance = document.getElementById('meter-distance');
    const time = document.getElementById('meter-time');
    const route = document.getElementById('meter-route');
    const totals = document.getElementById('meter-totals');
    const tariff = document.getElementById('meter-tariff');
    const pips = document.getElementById('meter-pips');
    const hails = document.getElementById('hails');

    const STATES = ['s-hire', 's-call', 's-board', 's-hired', 's-paid', 's-alarm'];

    // The big figure means something different in each state, so the caption is
    // what the driver is actually reading. Held here so a change to it is what
    // triggers the roll-over.
    let shownCap = null;

    // A paid fare holds on the display for a moment before the unit goes back
    // to for-hire, the way a real meter holds the fare until it is cleared.
    let paidUntil = 0;
    let paidRows = null;

    let lastRating = 5;
    let tween = null;

    // ── The money climbs ────────────────────────────────────────────────────
    // The message arrives twice a second and the fare jumps several dollars at
    // a time. Interpolating it is what makes the thing feel alive rather than
    // like a number being overwritten.
    function tickTo(to) {
        const from = Number(amount.dataset.value || 0);

        if (tween) cancelAnimationFrame(tween);

        if (!Number.isFinite(from) || Math.abs(to - from) < 1) {
            amount.dataset.value = String(to);
            amount.textContent = window.fmt.money(to);
            return;
        }

        const started = performance.now();

        const step = (now) => {
            const at = Math.min(1, (now - started) / 420);
            const value = Math.round(from + (to - from) * at);

            amount.textContent = window.fmt.money(value);

            if (at < 1) {
                tween = requestAnimationFrame(step);
            } else {
                amount.dataset.value = String(to);
                tween = null;
            }
        };

        tween = requestAnimationFrame(step);
    }

    // A countdown is never tweened. It has to be exact.
    function setExact(text, value) {
        if (tween) { cancelAnimationFrame(tween); tween = null; }
        amount.dataset.value = String(value === undefined ? '' : value);
        amount.textContent = text;
    }

    function oneShot(name) {
        root.classList.remove(name);
        void root.offsetWidth;
        root.classList.add(name);
        setTimeout(() => root.classList.remove(name), 600);
    }

    // ── The stars, as five pips ─────────────────────────────────────────────
    function setPips(value) {
        const lit = Math.max(0, Math.min(5, Math.round(Number(value) || 5)));

        if (pips.childElementCount !== 5) {
            pips.innerHTML = '<i class="pip"></i>'.repeat(5);
        }

        [...pips.children].forEach((pip, i) => pip.classList.toggle('spent', i >= lit));

        // The cab takes a hit and the meter jolts. Until now the cost of
        // driving badly was invisible until the card at the end.
        if (lit < lastRating) oneShot('knock');

        lastRating = lit;
    }

    function setTariff(data) {
        const flags = [];

        if (data.night) flags.push('Night');
        if (data.crossTown) flags.push('Cross-town');
        if (data.kind === 'player') flags.push('Hailed');

        tariff.hidden = flags.length === 0;
        tariff.textContent = flags.join(' · ');
    }

    // ── What the unit says ──────────────────────────────────────────────────
    function paint(data) {
        const t = data.totals || {};

        // Paid holds the display for a beat before anything else gets a say.
        if (paidUntil > Date.now() && paidRows) {
            title.textContent = 'Paid';
            setExact(window.fmt.money(paidRows.total), paidRows.total);
            cap.textContent = 'Took';
            distance.textContent = `${window.fmt.money(paidRows.fare)} fare`;
            time.textContent = `${window.fmt.money(paidRows.tip)} tip`;
            route.innerHTML = window.fmt.escape(paidRows.where || '');
            totals.textContent = '';
            tariff.hidden = true;
            return 's-paid';
        }

        if (!data.hasFare) {
            title.textContent = 'For hire';
            tickTo(Math.round(t.earned || 0));
            cap.textContent = 'Shift';
            distance.textContent = `${t.fares || 0} fares`;
            time.textContent = window.fmt.distance(t.distance || 0);
            route.innerHTML = 'Lamp on. Anyone can flag you down.';
            totals.textContent = '';
            tariff.hidden = true;
            return 's-hire';
        }

        setTariff(data);

        if (data.stage === 'toPickup') {
            const left = Number(data.pickupIn);
            const alarm = Number.isFinite(left) && left <= 30;

            title.textContent = 'On call';

            // The pickup deadline was completely invisible: the first you knew
            // was "Your fare got tired of waiting". It is the thing you are
            // driving against, so it is the thing in the big slot.
            if (Number.isFinite(left)) {
                setExact(window.fmt.duration(Math.max(0, left)), left);
                cap.textContent = alarm ? 'Giving up' : 'To pickup';
            } else {
                setExact(window.fmt.distance(data.away || 0));
                cap.textContent = 'To pickup';
            }

            distance.textContent = window.fmt.distance(data.away || 0);
            time.textContent = data.vehicle || '';
            route.innerHTML = `&rarr; <strong>${window.fmt.escape(data.pickup || '')}</strong>`;
            totals.textContent = '';

            return alarm ? 's-call s-alarm' : 's-call';
        }

        if (data.stage === 'boarding') {
            title.textContent = 'Getting in';
            setExact(window.fmt.money(data.flagfall || 0), data.flagfall || 0);
            cap.textContent = 'Flagfall';
            distance.textContent = '—';
            time.textContent = '';
            route.innerHTML = window.fmt.escape(data.pickup || '');
            totals.textContent = '';
            return 's-board';
        }

        title.textContent = 'Hired';
        tickTo(Math.round(data.amount || 0));
        cap.textContent = 'Fare';
        distance.textContent = window.fmt.distance(data.distance || 0);
        time.textContent = window.fmt.duration(data.elapsed || 0);

        if (data.openEnded) {
            route.innerHTML = 'Wherever they say. <span class="mtr-cmd">/endride</span> when you get there.';
            totals.textContent = '';
        } else {
            route.innerHTML = `&rarr; <strong>${window.fmt.escape(data.dropoff || '')}</strong>`;
            totals.textContent = data.away ? window.fmt.distance(data.away) : '';
        }

        return 's-hired';
    }

    function update(data) {
        if (!data || !data.onDuty) {
            root.classList.add('hidden');
            shownCap = null;
            return;
        }

        root.classList.remove('hidden');
        vehicle.textContent = '';

        const was = shownCap;
        const state = paint(data);

        // The number rolls over when its meaning changes, not when it ticks.
        shownCap = cap.textContent;
        if (was !== null && was !== shownCap) oneShot('flip');

        for (const name of STATES) root.classList.remove(name);
        for (const name of state.split(' ')) root.classList.add(name);

        // Kept for anything still reaching for the old class.
        root.classList.toggle('running', state.includes('s-hired'));

        setPips(data.rating);
    }

    // Held by the unit rather than thrown over the middle of the screen.
    function showPaid(result) {
        paidRows = {
            total: (result.fare || 0) + (result.tip || 0),
            fare: result.fare || 0,
            tip: result.tip || 0,
            where: result.dropoff || '',
        };

        paidUntil = Date.now() + 4000;
        lastRating = 5;
        oneShot('settle');
    }

    function clearRoute() {
        route.textContent = 'Fare complete.';
    }

    // ── Calls ───────────────────────────────────────────────────────────────
    function addHail(offer) {
        if (!offer || document.getElementById(`hail-${offer.id}`)) return;

        const node = document.createElement('div');
        node.className = 'hail';
        node.id = `hail-${offer.id}`;

        // The card cannot be clicked — the page has no focus while you are
        // driving — so the command is the instruction, not a fallback.
        node.innerHTML = `
            <b>${window.fmt.escape(offer.passenger || 'Someone')}</b>
            <p>${window.fmt.distance(offer.distance || 0)} away &middot; ${window.fmt.escape(offer.label || 'Street pickup')}</p>
            <span class="cmd">/accepthail ${offer.id}</span>
            <div class="timer"></div>`;

        hails.appendChild(node);

        // .timer was fully styled and rendered by nothing. A call that visibly
        // drains is worth ten that sit there.
        const bar = node.querySelector('.timer');
        const seconds = Number(offer.expiresIn) || 0;

        if (bar && seconds > 0) {
            bar.style.transition = `transform ${seconds}s linear`;
            requestAnimationFrame(() => { bar.style.transform = 'scaleX(0)'; });
        }
    }

    function removeHail(id) {
        const node = document.getElementById(`hail-${id}`);
        if (node) node.remove();
    }

    return { update, clearRoute, addHail, removeHail, showPaid };
})();
