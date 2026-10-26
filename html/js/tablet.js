window.Tablet = (() => {
    const root = document.getElementById('tablet');
    const stage = root.querySelector('.tb-stage');
    const railEl = root.querySelector('.tb-nav');
    const headEl = root.querySelector('.tb-ph');
    const bodyEl = root.querySelector('.tb-body');
    const toastBox = root.querySelector('.tb-toastbox');

    const esc = (v) => window.fmt.escape(v);
    const money = (v) => window.fmt.money(v);
    const dist = (v) => window.fmt.distance(v);

    const ICON = {
        calls: '<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z"/>',
        fare: '<path d="M5 17h14M6 17l1.5-5h9L18 17M8 12l1-3h6l1 3M7 20a1.5 1.5 0 1 0 0-3M17 20a1.5 1.5 0 1 0 0-3M10 6h4"/>',
        shift: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        earnings: '<path d="M12 2v20M17 6H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>',
        record: '<path d="M12 2l3 6.3 7 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 7-1z"/>',
        cabs: '<path d="M3 13l2-6h14l2 6M5 13h14v5H5zM7 18v2M17 18v2M7 15.5h.01M17 15.5h.01"/>',
        board: '<path d="M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0zM17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>',
        drivers: '<circle cx="9" cy="8" r="4"/><path d="M2 21a7 7 0 0 1 14 0M17 3a4 4 0 0 1 0 8M22 21a6 6 0 0 0-4-5.6"/>',
        dispatch: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
        depots: '<path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-6h6v6"/>',
        close: '<path d="M18 6 6 18M6 6l12 12"/>',
        gps: '<path d="M3 11l19-9-9 19-2-8z"/>',
        plus: '<path d="M12 5v14M5 12h14"/>',
        trash: '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>',
        check: '<path d="M20 6 9 17l-5-5"/>',
        lamp: '<path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7V16h8v-1.3A7 7 0 0 0 12 2z"/>',
        edit: '<path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
        pin: '<path d="M12 22s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>',
        flag: '<path d="M4 22V4M4 4h12l-2 4 2 4H4"/>',
        pay: '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 12h.01M18 12h.01"/>',
    };
    const icon = (name) => `<svg class="tb-i" viewBox="0 0 24 24">${ICON[name] || ''}</svg>`;

    const BLIP_COLOURS = [
        [5, 'Yellow', '#f0cb57'], [46, 'Gold', '#e6b44d'], [17, 'Orange', '#f28b3a'], [1, 'Red', '#e03232'],
        [2, 'Green', '#71cb71'], [3, 'Blue', '#5db6e5'], [38, 'Dark blue', '#2c6bd3'], [27, 'Purple', '#a35ec4'],
        [0, 'White', '#ffffff'], [40, 'Dark grey', '#4c4c4c'],
    ];
    const BLIP_SPRITES = [[198, 'Taxi'], [56, 'Cab'], [225, 'Car'], [326, 'Car (side)'], [523, 'Sports car'], [357, 'Garage']];
    const BLIP_SCALES = [[0.6, 'Small'], [0.75, 'Normal'], [0.9, 'Large']];

    let S = null;
    let page = 'calls';
    let offers = [];
    let live = null;
    let locs = [];
    let draft = null;
    let admin = { drivers: null, cabs: null };
    let mapView = null;
    let open = false;
    let modalResolve = null;

    function fit() {
        const s = Math.min(window.innerWidth / 1600, window.innerHeight / 900);
        stage.style.setProperty('--tb-s', String(Math.max(0.5, s)));
    }
    window.addEventListener('resize', fit);

    function toast(text, kind) {
        const node = document.createElement('div');
        node.className = `tb-toast ${kind === 'error' ? 't-err' : kind === 'ok' ? 't-ok' : ''}`;
        node.textContent = text;
        toastBox.appendChild(node);
        setTimeout(() => node.remove(), 3800);
    }

    async function act(name, data, okText) {
        const result = await window.post(name, data || {});
        if (!result || result.ok === false) {
            toast((result && result.error) || 'That did not work.', 'error');
            return null;
        }
        if (okText) toast(okText, 'ok');
        return result;
    }

    async function refresh() {
        const next = await window.post('getState');
        if (next) setState(next);
    }

    function confirmBox(text, okLabel, danger) {
        const over = document.createElement('div');
        over.className = 'tb-over';
        over.innerHTML = `
            <div class="tb-modal">
                <div class="tb-ch">${icon('check')} Are you sure?</div>
                <p>${esc(text)}</p>
                <div class="tb-modal-foot">
                    <button class="tb-btn b-ghost" data-no>Back</button>
                    <button class="tb-btn ${danger ? 'b-red' : 'b-go'}" data-yes>${esc(okLabel || 'Yes')}</button>
                </div>
            </div>`;
        root.querySelector('.tb-main').appendChild(over);
        return new Promise((resolve) => {
            modalResolve = (value) => {
                over.remove();
                modalResolve = null;
                resolve(value);
            };
            over.querySelector('[data-no]').onclick = () => modalResolve(false);
            over.querySelector('[data-yes]').onclick = () => modalResolve(true);
        });
    }

    function numberBox(text, value) {
        const over = document.createElement('div');
        over.className = 'tb-over';
        over.innerHTML = `
            <div class="tb-modal">
                <div class="tb-ch">${icon('edit')} ${esc(text)}</div>
                <div class="tb-cb"><input class="tb-input" type="number" value="${esc(value)}" data-num></div>
                <div class="tb-modal-foot">
                    <button class="tb-btn b-ghost" data-no>Back</button>
                    <button class="tb-btn b-go" data-yes>Apply</button>
                </div>
            </div>`;
        root.querySelector('.tb-main').appendChild(over);
        const input = over.querySelector('[data-num]');
        input.focus();
        return new Promise((resolve) => {
            modalResolve = (value) => {
                over.remove();
                modalResolve = null;
                resolve(value);
            };
            over.querySelector('[data-no]').onclick = () => modalResolve(null);
            over.querySelector('[data-yes]').onclick = () => modalResolve(Number(input.value));
        });
    }

    function onShift() { return !!(S && S.onDuty); }
    function hasFare() { return !!((live && live.hasFare) || (S && S.hasFare)); }

    function pages() {
        const list = [];
        if (onShift()) {
            list.push({ sec: 'On shift' });
            list.push({ id: 'calls', label: 'Calls', icon: 'calls', badge: offers.length || null });
            list.push({ id: 'fare', label: 'Fare', icon: 'fare', badge: hasFare() ? '1' : null, n: true });
        }
        list.push({ sec: 'Driver' });
        list.push({ id: 'shift', label: onShift() ? 'Shift' : 'Sign on', icon: 'shift' });
        list.push({ id: 'earnings', label: 'Earnings', icon: 'earnings' });
        list.push({ id: 'record', label: 'Record', icon: 'record' });
        list.push({ id: 'cabs', label: 'Cabs', icon: 'cabs' });
        list.push({ id: 'board', label: 'Leaderboard', icon: 'board' });
        if (S && S.isAdmin) {
            list.push({ sec: 'Admin' });
            list.push({ id: 'drivers', label: 'Drivers', icon: 'drivers' });
            list.push({ id: 'dispatch', label: 'Dispatch', icon: 'dispatch' });
            list.push({ id: 'pay', label: 'Pay & rates', icon: 'pay' });
            list.push({ id: 'depots', label: 'Depots', icon: 'depots', badge: draft ? 'edit' : null, n: true });
        }
        return list;
    }

    function renderRail() {
        railEl.innerHTML = pages().map((p) => {
            if (p.sec) return `<div class="tb-sec">${esc(p.sec)}</div>`;
            const badge = p.badge ? `<span class="tb-badge${p.n ? ' n' : ''}">${esc(p.badge)}</span>` : '';
            return `<div class="tb-item${page === p.id ? ' on' : ''}" data-page="${p.id}">${icon(p.icon)}<span>${esc(p.label)}</span>${badge}</div>`;
        }).join('');

        railEl.querySelectorAll('[data-page]').forEach((el) => {
            el.onclick = () => go(el.dataset.page);
        });

        const company = (S && S.location && locs.find((l) => l.id === S.location))
            || (S && S.at && locs.find((l) => l.id === S.at));
        root.querySelector('[data-brand]').innerHTML = esc(company ? company.name : 'Taxi');

        const stats = (S && S.stats) || {};
        root.querySelector('[data-me-name]').textContent = (S && S.name) || 'Driver';
        root.querySelector('[data-me-sub]').textContent = `${stats.tierLabel || 'Trainee'} · ${stats.reputation || 0} rep`;
        root.querySelector('[data-me-av]').textContent = initials((S && S.name) || 'Driver');
        root.querySelector('[data-me-dot]').classList.toggle('off', !onShift());
        tickClock();
    }

    function initials(name) {
        return String(name).split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('') || 'DR';
    }

    function tickClock() {
        const clock = root.querySelector('[data-clock]');
        const sub = root.querySelector('[data-clock-sub]');
        if (!clock) return;
        const now = new Date();
        clock.textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
        if (onShift() && S.startedAt && S.now) {
            const elapsed = Math.max(0, (S.now - S.startedAt) + Math.floor((Date.now() - S.openedAt) / 1000));
            sub.textContent = `On shift ${window.fmt.duration(elapsed)}`;
        } else {
            sub.textContent = 'Off shift';
        }
    }
    setInterval(() => { if (open) tickClock(); }, 1000);

    function header(sub, title, right) {
        headEl.innerHTML = `
            <div class="tb-ph-l">
                <span class="tb-ph-sub">${esc(sub)}</span>
                <span class="tb-ph-title">${title}</span>
            </div>
            <div class="tb-ph-r">${right || ''}</div>`;
    }

    function dropMap() {
        if (mapView) {
            mapView.destroy();
            mapView = null;
        }
    }

    function mountMap(el, draw) {
        dropMap();
        if (!el || !window.L) return;
        mapView = window.TaxiMap.create(el);
        if (S && S.me) mapView.setMe(S.me.x, S.me.y);
        draw(mapView);
    }

    function go(next) {
        page = next;
        render();
    }

    function render() {
        if (!S) return;
        renderRail();
        dropMap();
        const fn = PAGES[page] || PAGES.shift;
        fn();
    }

    function stars(rating) {
        const n = Math.max(0, Math.min(5, Math.round(Number(rating) || 0)));
        return `<span class="tx-stars">${'★'.repeat(n)}<i>${'★'.repeat(5 - n)}</i></span>`;
    }

    function empty(iconName, title, text, extra) {
        return `<div class="tb-empty">${icon(iconName)}<b>${esc(title)}</b><span>${esc(text)}</span>${extra || ''}</div>`;
    }

    function depotPins(view) {
        locs.forEach((loc) => view.pin(loc.desk.x, loc.desk.y, 'depot', { title: loc.name }));
    }

    const PAGES = {
        calls() {
            header('Dispatch board', `${icon('calls')} Calls`, `
                <button class="tb-btn ${S.lamp ? 'b-go' : ''}" data-lamp>${icon('lamp')} Lamp ${S.lamp ? 'on' : 'off'}</button>
                <button class="tb-btn b-blue" data-find>${icon('flag')} Find me a fare</button>`);

            const banner = hasFare()
                ? `<div class="tx-banner">${icon('fare')}<span><b>You have a fare running.</b> Calls come back when it's done.</span><button class="tb-btn b-sm" data-go-fare>Go to fare</button></div>`
                : '';

            const rows = offers.map((o) => {
                const left = Math.max(0, (o.expiresIn || 0) - Math.floor((Date.now() - (o.seenAt || Date.now())) / 1000));
                return `
                <div class="tb-row tx-call" data-call="${o.id}">
                    <div>
                        <div class="who"><b>${esc(o.passenger || 'Someone')}</b><span class="tb-tag ${o.origin === 'phone' ? 'g-blue' : 'g-yellow'}">${o.origin === 'phone' ? 'Phone' : 'Call'}</span></div>
                        <span class="s">${esc(o.street || 'Street pickup')} · ${dist(o.distance || 0)} away</span>
                    </div>
                    <div class="acts">
                        <button class="tb-btn b-sm b-ghost" data-pass="${o.id}">Pass</button>
                        <button class="tb-btn b-sm b-go" data-accept="${o.id}" ${hasFare() ? 'disabled' : ''}>Accept</button>
                    </div>
                    <div class="life"><i style="transform:scaleX(${o.expiresIn ? Math.min(1, left / o.expiresIn) : 0});transition:transform ${left}s linear" data-life="${left}"></i></div>
                </div>`;
            }).join('');

            bodyEl.innerHTML = `
                ${banner}
                <div class="tx-grid">
                    <div class="tx-col">
                        <div class="tb-card c-fill">
                            <div class="tb-ch">${icon('calls')} Ride requests<span class="tb-ch-r"><span class="tb-tag">${offers.length} waiting</span></span></div>
                            <div class="tb-scroll">${rows || empty('calls', 'No calls right now',
                                S.lamp ? 'Keep driving with the lamp on and people will flag you down, or ask dispatch for a fare.'
                                    : 'Your lamp is off, so nobody can flag you down. Turn it on, or ask dispatch for a fare.')}</div>
                        </div>
                    </div>
                    <div class="tx-col">
                        <div class="tb-card c-fill"><div class="tb-ch">${icon('pin')} Map</div><div class="tx-map" data-map></div></div>
                    </div>
                </div>`;

            requestAnimationFrame(() => {
                bodyEl.querySelectorAll('[data-life]').forEach((bar) => { bar.style.transform = 'scaleX(0)'; });
            });

            mountMap(bodyEl.querySelector('[data-map]'), (view) => {
                depotPins(view);
                offers.forEach((o) => view.pin(o.coords.x, o.coords.y, 'call', {
                    title: `${o.passenger || 'Someone'} · ${o.street || ''}`, z: 500,
                }));
                view.fit([S.me, ...offers.map((o) => o.coords)], 4);
            });

            wireCommon();
            bodyEl.querySelectorAll('[data-accept]').forEach((b) => {
                b.onclick = async () => {
                    b.disabled = true;
                    const result = await act('acceptRide', { id: Number(b.dataset.accept) });
                    if (!result) b.disabled = false;
                };
            });
            bodyEl.querySelectorAll('[data-pass]').forEach((b) => {
                b.onclick = async () => {
                    await window.post('passRide', { id: Number(b.dataset.pass) });
                    rideGone(Number(b.dataset.pass));
                };
            });
        },

        fare() {
            const f = live && live.hasFare ? live : null;
            header('Current fare', `${icon('fare')} Fare`, f ? `<button class="tb-btn b-red" data-cancel>${icon('close')} Cancel fare</button>` : '');

            if (!f) {
                bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('fare', 'No fare running',
                    'Answer a call, let somebody flag you down, or ask dispatch for a fare.',
                    '<div style="margin-top:12px"><button class="tb-btn b-go" data-find>Find me a fare</button></div>')}</div>`;
                wireCommon();
                return;
            }

            const stageText = { toPickup: 'Heading to the pickup', boarding: 'Waiting for them to get in', riding: 'Passenger aboard' }[f.stage] || 'On the way';
            const kind = f.kind === 'player' ? 'Phone or street call' : 'Street fare';
            const end = f.openEnded && f.stage === 'riding'
                ? '<button class="tb-btn b-go b-lg" data-endride>End the ride here</button>' : '';

            bodyEl.innerHTML = `
                <div class="tx-fare">
                    <div class="big"><small>Meter</small><b data-live="amount">${money(f.amount || 0)}</b></div>
                    <div><small>Distance</small><b data-live="distance">${dist(f.distance || 0)}</b></div>
                    <div><small>Time</small><b data-live="elapsed">${window.fmt.duration(f.elapsed || 0)}</b></div>
                    <div><small>Rating</small><b data-live="rating">${stars(f.rating || 5)}</b></div>
                </div>
                <div class="tx-grid">
                    <div class="tx-col">
                        <div class="tb-card">
                            <div class="tb-ch">${icon('fare')} Trip<span class="tb-ch-r">${f.night ? '<span class="tb-tag g-purple">Night rate</span>' : ''}${f.crossTown ? '<span class="tb-tag g-blue">Cross-town</span>' : ''}</span></div>
                            <div class="tb-cb">
                                <div class="tb-info"><span class="k">Stage</span><span class="v" data-live="stage">${esc(stageText)}</span></div>
                                <div class="tb-info"><span class="k">Type</span><span class="v">${esc(kind)}</span></div>
                                ${f.passenger ? `<div class="tb-info"><span class="k">Passenger</span><span class="v">${esc(f.passenger)}</span></div>` : ''}
                                <div class="tb-info"><span class="k">Pickup</span><span class="v">${esc(f.pickup || 'The kerb')}</span></div>
                                <div class="tb-info"><span class="k">Drop-off</span><span class="v">${esc(f.openEnded ? 'Wherever they ask' : (f.dropoff || '...'))}</span></div>
                                <div class="tb-info"><span class="k">Distance left</span><span class="v" data-live="away">${f.away != null ? dist(f.away) : '-'}</span></div>
                            </div>
                        </div>
                        <div class="tb-card"><div class="tb-cb" style="display:flex;gap:8px;flex-wrap:wrap">
                            ${end}
                            ${f.pickupAt && f.stage !== 'riding' ? `<button class="tb-btn" data-gps="${f.pickupAt.x},${f.pickupAt.y}">${icon('gps')} GPS to pickup</button>` : ''}
                            ${f.dropoffAt && f.stage === 'riding' ? `<button class="tb-btn" data-gps="${f.dropoffAt.x},${f.dropoffAt.y}">${icon('gps')} GPS to drop-off</button>` : ''}
                        </div></div>
                    </div>
                    <div class="tx-col"><div class="tb-card c-fill"><div class="tb-ch">${icon('pin')} Map</div><div class="tx-map" data-map></div></div></div>
                </div>`;

            mountMap(bodyEl.querySelector('[data-map]'), (view) => {
                if (f.pickupAt) view.pin(f.pickupAt.x, f.pickupAt.y, 'pick', { title: 'Pickup' });
                if (f.dropoffAt) view.pin(f.dropoffAt.x, f.dropoffAt.y, 'drop', { title: 'Drop-off' });
                view.fit([f.me || S.me, f.stage === 'riding' ? f.dropoffAt : f.pickupAt], 4);
            });

            wireCommon();
            const cancel = headEl.querySelector('[data-cancel]');
            if (cancel) cancel.onclick = async () => {
                const yes = await confirmBox(f.stage === 'riding'
                    ? 'Your passenger is in the cab. Dropping them now costs reputation.'
                    : 'Drop this fare?', 'Cancel fare', true);
                if (!yes) return;
                if (await act('cancelFare', {}, 'Fare cancelled.')) { live = null; render(); }
            };
            const endBtn = bodyEl.querySelector('[data-endride]');
            if (endBtn) endBtn.onclick = async () => {
                endBtn.disabled = true;
                if (!(await act('endRide'))) endBtn.disabled = false;
            };
        },

        shift() {
            if (onShift()) return shiftOn();
            return shiftOff();
        },

        earnings() {
            const t = (S && S.totals) || {};
            header('This shift and recent fares', `${icon('earnings')} Earnings`);
            const recent = (S.recent || []).map((r) => `
                <div class="tb-row tx-recent">
                    <div><b>${esc(r.pickup_label)} → ${esc(r.dropoff_label)}</b><span class="s">${esc(r.kind === 'player' ? 'Call' : 'Street fare')} · ${dist(r.distance)}</span></div>
                    <span class="m">${money(r.fare)}</span>
                    <span class="m">+${money(r.tip)}</span>
                    <span class="m">${Number(r.rating || 5).toFixed(1)}★</span>
                </div>`).join('');

            bodyEl.innerHTML = `
                <div class="tb-stats">
                    <div class="tb-st"><div class="l">Earned this shift</div><div class="v a">${money(t.earned || 0)}</div><div class="t">${onShift() ? 'Fares and tips' : 'Not on shift'}</div></div>
                    <div class="tb-st"><div class="l">Fares</div><div class="v">${t.fares || 0}</div></div>
                    <div class="tb-st"><div class="l">Driven</div><div class="v">${dist(t.distance || 0)}</div></div>
                    <div class="tb-st"><div class="l">All time</div><div class="v g">${money((S.stats || {}).totalEarned || 0)}</div></div>
                </div>
                <div class="tb-card c-fill">
                    <div class="tb-ch">${icon('earnings')} Recent fares</div>
                    <div class="tb-scroll">${recent || empty('earnings', 'No fares yet', 'Finished fares show up here.')}</div>
                </div>`;
        },

        record() {
            const st = S.stats || {};
            header('Your standing', `${icon('record')} Record`);
            const next = st.nextTier;
            const ladder = (S.tiers || []).map((t) => `
                <div class="tb-row tx-ladder${t.tier === st.tier ? ' on' : ''}">
                    <span class="n">${t.tier}</span>
                    <div><b>${esc(t.label)}</b><span class="s">${t.at} rep</span></div>
                    <span class="m">x${Number(t.fareMultiplier).toFixed(2)} fares</span>
                    <span class="m">${st.reputation >= t.at ? 'Unlocked' : `${t.at - (st.reputation || 0)} to go`}</span>
                </div>`).join('');

            bodyEl.innerHTML = `
                <div class="tb-stats">
                    <div class="tb-st"><div class="l">Tier</div><div class="v a">${esc(st.tierLabel || 'Trainee')}</div><div class="t">${st.reputation || 0} reputation</div></div>
                    <div class="tb-st"><div class="l">Rating</div><div class="v">${Number(st.rating || 5).toFixed(2)}</div><div class="t">${stars(st.rating || 5)}</div></div>
                    <div class="tb-st"><div class="l">Fares</div><div class="v">${st.totalFares || 0}</div></div>
                    <div class="tb-st"><div class="l">Driven</div><div class="v">${dist(st.totalDistance || 0)}</div></div>
                </div>
                <div class="tb-card"><div class="tb-cb">
                    <span class="tb-label">${next ? `Next: ${esc(next.label)} at ${next.at} rep` : 'Top tier reached'}</span>
                    <div class="tx-bar"><i style="width:${Math.round((st.progress || (next ? 0 : 1)) * 100)}%"></i></div>
                </div></div>
                <div class="tb-card c-fill"><div class="tb-ch">${icon('record')} Tiers</div><div class="tb-scroll">${ladder}</div></div>`;
        },

        cabs() {
            header('What you can rent', `${icon('cabs')} Cabs`);
            const rows = (S.vehicles || []).map((v) => `
                <div class="tb-row tx-cab${v.locked ? ' locked' : ''}">
                    <div><b>${esc(v.label)}</b><span class="s">${esc(v.model)}</span></div>
                    <span class="tb-tag ${v.locked ? '' : 'g-green'}">Tier ${v.tier}</span>
                    <span class="m">x${Number(v.rate).toFixed(2)}</span>
                    <span class="m">${v.locked ? 'Locked' : 'Unlocked'}</span>
                </div>`).join('');
            bodyEl.innerHTML = `
                <div class="tx-hint">Better cabs pay more per fare. Reputation unlocks them, and you earn it by driving well. Each depot can choose which cabs it rents.</div>
                <div class="tb-card c-fill"><div class="tb-ch">${icon('cabs')} Roster</div><div class="tb-scroll">${rows}</div></div>`;
        },

        board() {
            header('Top drivers', `${icon('board')} Leaderboard`);
            const rows = (S.leaderboard || []).map((r) => `
                <div class="tb-row tx-lead">
                    <span class="m">#${r.rank}</span>
                    <div><b>${esc(r.name || 'Driver')}</b><span class="s">${esc(r.tierLabel)}</span></div>
                    <span class="m">${r.reputation} rep</span>
                    <span class="m">${money(r.earned)}</span>
                    <span class="m">${Number(r.rating || 5).toFixed(1)}★</span>
                </div>`).join('');
            bodyEl.innerHTML = `<div class="tb-card c-fill"><div class="tb-ch">${icon('board')} By reputation</div><div class="tb-scroll">${rows || empty('board', 'Nobody yet', 'Finish a fare to get on the board.')}</div></div>`;
        },

        async drivers() {
            header('Live drivers', `${icon('drivers')} Drivers`, `<button class="tb-btn" data-refresh>Refresh</button>`);
            bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('drivers', 'Loading...', '')}</div>`;
            headEl.querySelector('[data-refresh]').onclick = () => render();

            const data = await window.post('adminState');
            if (page !== 'drivers') return;
            if (!data || data.ok === false) {
                bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('drivers', 'No access', (data && data.error) || '')}</div>`;
                return;
            }

            const t = data.totals || {};
            const rows = (data.drivers || []).map((d) => `
                <div class="tb-row tx-driver">
                    <div><b>${esc(d.name)}</b><span class="s">${esc(d.vehicle || 'No cab')}${d.personal ? ' (own car)' : ''} · ${esc(d.location || '')}</span></div>
                    <span class="d">${d.fare ? esc(d.fare.boarded ? 'Riding' : 'To pickup') : 'Free'}</span>
                    <span class="m">${money(d.earned)}</span>
                    <span class="m">${d.reputation} rep</span>
                    <span style="display:flex;gap:6px">
                        <button class="tb-btn b-sm" data-rep="${d.src}">Rep</button>
                        ${d.fare ? `<button class="tb-btn b-sm" data-clear="${d.src}">Clear fare</button>` : ''}
                        <button class="tb-btn b-sm b-red" data-end="${d.src}">End shift</button>
                        <button class="tb-btn b-sm b-ghost" data-wipe="${esc(d.citizenid)}" data-who="${esc(d.name)}">Wipe</button>
                    </span>
                </div>`).join('');

            bodyEl.innerHTML = `
                <div class="tb-stats">
                    <div class="tb-st"><div class="l">On shift</div><div class="v a">${t.onDuty || 0}</div></div>
                    <div class="tb-st"><div class="l">Earned this shift</div><div class="v">${money(t.earnedThisShift || 0)}</div></div>
                    <div class="tb-st"><div class="l">Fares this shift</div><div class="v">${t.faresThisShift || 0}</div></div>
                    <div class="tb-st"><div class="l">All time</div><div class="v g">${money((t.allTime || {}).earned || 0)}</div><div class="t">${(t.allTime || {}).fares || 0} fares</div></div>
                </div>
                <div class="tb-card c-fill"><div class="tb-ch">${icon('drivers')} Drivers</div><div class="tb-scroll">${rows || empty('drivers', 'Nobody is driving', 'Drivers on shift show up here.')}</div></div>`;

            bodyEl.querySelectorAll('[data-rep]').forEach((b) => {
                b.onclick = async () => {
                    const amount = await numberBox('Add or take reputation', 10);
                    if (amount === null || Number.isNaN(amount)) return;
                    if (await act('adminSetReputation', { src: Number(b.dataset.rep), amount }, 'Reputation changed.')) render();
                };
            });
            bodyEl.querySelectorAll('[data-clear]').forEach((b) => {
                b.onclick = async () => { if (await act('adminClearFare', { src: Number(b.dataset.clear) }, 'Fare cleared.')) render(); };
            });
            bodyEl.querySelectorAll('[data-wipe]').forEach((b) => {
                b.onclick = async () => {
                    if (!(await confirmBox(`Wipe ${b.dataset.who}'s record? Their reputation and fare history are deleted for good.`, 'Wipe record', true))) return;
                    if (await act('adminWipe', { citizenid: b.dataset.wipe }, 'Record wiped.')) render();
                };
            });
            bodyEl.querySelectorAll('[data-end]').forEach((b) => {
                b.onclick = async () => {
                    if (!(await confirmBox('End this driver\'s shift?', 'End shift', true))) return;
                    if (await act('adminEndShift', { src: Number(b.dataset.end) }, 'Shift ended.')) render();
                };
            });
        },

        async dispatch() {
            header('Live switches', `${icon('dispatch')} Dispatch`);
            const data = await window.post('adminState');
            if (page !== 'dispatch') return;
            if (!data || data.ok === false) {
                bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('dispatch', 'No access', (data && data.error) || '')}</div>`;
                return;
            }
            const set = data.settings || {};
            bodyEl.innerHTML = `
                <div class="tb-card"><div class="tb-ch">${icon('dispatch')} Switches</div><div class="tb-cb">
                    <div class="tx-switch${set.paused ? ' on' : ''}" data-setting="paused"><div class="t"><b>Pause dispatch</b><span>Nobody gets a fare from dispatch or a flag-down.</span></div><i></i></div>
                    <div class="tx-switch${set.hailEnabled !== false ? ' on' : ''}" data-setting="hailEnabled"><div class="t"><b>Take calls</b><span>Players can call a cab from the phone or with /taxi.</span></div><i></i></div>
                </div></div>
                <div class="tb-card"><div class="tb-ch">${icon('earnings')} Fare multiplier</div><div class="tb-cb" style="display:flex;gap:8px;align-items:center">
                    <input class="tb-input" style="width:120px" type="number" step="0.05" min="0.1" max="5" value="${Number(set.fareMultiplier || 1).toFixed(2)}" data-mult>
                    <button class="tb-btn b-go" data-mult-save>Apply</button>
                    <span class="m" style="color:var(--x-faint);font-size:12px">Applies to new fares. Resets when the script restarts.</span>
                </div></div>`;

            bodyEl.querySelectorAll('[data-setting]').forEach((el) => {
                el.onclick = async () => {
                    const on = !el.classList.contains('on');
                    if (await act('adminSetting', { key: el.dataset.setting, value: on })) el.classList.toggle('on', on);
                };
            });
            bodyEl.querySelector('[data-mult-save]').onclick = async () => {
                const value = Number(bodyEl.querySelector('[data-mult]').value);
                if (!(value > 0)) return toast('Pick a number above zero.', 'error');
                await act('adminSetting', { key: 'fareMultiplier', value }, 'Multiplier applied.');
            };
        },

        async pay() {
            header('Loading', `${icon('pay')} Pay & rates`);
            const data = await window.post('adminRates');
            if (page !== 'pay') return;
            if (!data || data.ok === false) {
                bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('pay', 'No access', (data && data.error) || '')}</div>`;
                return;
            }
            payPage(data.rates);
        },

        async depots() {
            if (draft) return depotEditor();

            header('Where drivers sign on', `${icon('depots')} Depots`, `<button class="tb-btn b-go" data-new>${icon('plus')} New depot</button>`);
            const rows = locs.map((l) => `
                <div class="tb-row tx-depot">
                    <div><b>${esc(l.name)}</b><span class="s">${(l.bays || []).length} cab bay${(l.bays || []).length === 1 ? '' : 's'}${l.personal ? ' · own cars allowed' : ''}${l.job ? ` · ${esc(l.job)} job only` : ''}</span></div>
                    <span class="m">${l.blip && l.blip.show === false ? 'No blip' : 'On map'}</span>
                    <button class="tb-btn b-sm" data-gps="${l.desk.x},${l.desk.y}">${icon('gps')} GPS</button>
                    <button class="tb-btn b-sm" data-edit="${l.id}">${icon('edit')} Edit</button>
                </div>`).join('');

            bodyEl.innerHTML = `
                <div class="tx-grid">
                    <div class="tx-col"><div class="tb-card c-fill"><div class="tb-ch">${icon('depots')} ${locs.length} depot${locs.length === 1 ? '' : 's'}</div><div class="tb-scroll">${rows || empty('depots', 'No depots', 'Add one to let drivers sign on.')}</div></div></div>
                    <div class="tx-col"><div class="tb-card c-fill"><div class="tb-ch">${icon('pin')} Map</div><div class="tx-map" data-map></div></div></div>
                </div>`;

            mountMap(bodyEl.querySelector('[data-map]'), (view) => {
                depotPins(view);
                view.fit(locs.map((l) => l.desk), 3);
            });

            wireCommon();
            headEl.querySelector('[data-new]').onclick = async () => {
                const result = await act('builderOpen', {});
                if (result) { draft = result.draft; render(); }
            };
            bodyEl.querySelectorAll('[data-edit]').forEach((b) => {
                b.onclick = async () => {
                    const result = await act('builderOpen', { id: Number(b.dataset.edit) });
                    if (result) { draft = result.draft; render(); }
                };
            });
        },
    };

    function rateInput(key, unit, value) {
        const sign = { cash: '$', x: 'x', pct: '%', bonus: '%' }[unit];
        const n = Number(value) || 0;
        const shown = unit === 'pct' ? n * 100 : unit === 'bonus' ? (n - 1) * 100 : n;
        return `<div class="tx-num${unit === 'cash' ? '' : ' u-r'}"><span>${sign}</span><input class="tb-input" type="number" step="any"${unit === 'bonus' ? '' : ' min="0"'} data-rate="${esc(key)}" data-unit="${unit}" value="${Math.round(shown * 100) / 100}"></div>`;
    }

    function payPage(r) {
        header(r.saved ? 'Saved in game · new rates start on the next fare' : 'From config.lua · new rates start on the next fare', `${icon('pay')} Pay & rates`, `
            ${r.saved ? '<button class="tb-btn" data-reset-rates>Use config.lua</button>' : ''}
            <button class="tb-btn b-go" data-save-rates>${icon('check')} Save rates</button>`);

        const hour = (h) => `${String(h).padStart(2, '0')}:00`;
        const field = (label, input) => `<div><label class="tb-label">${esc(label)}</label>${input}</div>`;
        const cabs = r.cabList || [];
        const tiers = r.tierList || [];

        const tipRows = [5, 4, 3, 2, 1].map((n) => `
            <div class="tb-row tx-rate"><div>${stars(n)}</div>${rateInput(`tips.${n}`, 'pct', (r.tips || {})[n])}</div>`).join('');
        const tierRows = tiers.map((t) => `
            <div class="tb-row tx-rate"><div><b>${esc(t.label)}</b><span class="s">From ${t.at} rep</span></div>${rateInput(`tiers.${t.tier}`, 'bonus', t.rate)}</div>`).join('');
        const cabRows = cabs.map((c) => `
            <div class="tb-row tx-rate"><div><b>${esc(c.label)}</b><span class="s">Tier ${c.tier}</span></div>${rateInput(`cabs.${c.model}`, 'x', c.rate)}</div>`).join('');

        bodyEl.innerHTML = `
            <div class="tx-grid tx-pay">
                <div class="tx-col">
                    <div class="tb-card"><div class="tb-ch">${icon('fare')} Meter</div><div class="tb-cb">
                        <div class="tb-form">
                            ${field('Flagfall', rateInput('flagfall', 'cash', r.flagfall))}
                            ${field('Per km', rateInput('perKm', 'cash', r.perKm))}
                            ${field('Per minute waiting', rateInput('perWaitingMinute', 'cash', r.perWaitingMinute))}
                            ${field('Minimum fare', rateInput('minimumFare', 'cash', r.minimumFare))}
                            ${field('Night rides', rateInput('night', 'x', r.night))}
                            ${field('Cross-town', rateInput('crossTown', 'x', r.crossTown))}
                        </div>
                        <div class="tx-note">Night is ${hour(r.nightFrom)} to ${hour(r.nightTo)}, game time. Cross-town is a ride from one area of the map to another.</div>
                    </div></div>
                    <div class="tb-card"><div class="tb-ch">${icon('cabs')} Deposit and extras</div><div class="tb-cb">
                        <div class="tb-form">
                            ${field('Cab deposit', rateInput('deposit', 'cash', r.deposit))}
                            ${field('Kept for a wreck', rateInput('damageFee', 'pct', r.damageFee))}
                            ${field('Player calls', rateInput('player', 'x', r.player))}
                            ${field('Own cars', rateInput('ownCar', 'x', r.ownCar))}
                        </div>
                        <div class="tx-note">A damaged cab keeps part of the deposit, up to the share above for a wreck. Player calls are paid by the passenger.</div>
                    </div></div>
                </div>
                <div class="tx-col">
                    <div class="tb-card"><div class="tb-ch">${icon('record')} Tip by rating</div>${tipRows}</div>
                    <div class="tb-card c-fill"><div class="tb-ch">${icon('board')} Tier bonus</div><div class="tb-scroll">${tierRows}</div></div>
                </div>
                <div class="tx-col">
                    <div class="tb-card c-fill"><div class="tb-ch">${icon('cabs')} Cab rates</div><div class="tb-scroll">${cabRows}</div></div>
                    <div class="tb-card"><div class="tb-ch">${icon('earnings')} Example: 3 km, 2 minutes waiting</div><div class="tb-cb tx-ex" data-example></div></div>
                </div>
            </div>`;

        const read = () => {
            const out = { tips: {}, cabs: {}, tiers: {} };
            bodyEl.querySelectorAll('[data-rate]').forEach((el) => {
                let v = el.value === '' ? NaN : Number(el.value);
                if (el.dataset.unit === 'pct') v /= 100;
                if (el.dataset.unit === 'bonus') v = 1 + v / 100;
                const [group, key] = el.dataset.rate.split('.');
                if (key) out[group][key] = Number.isFinite(v) ? v : null;
                else out[group] = Number.isFinite(v) ? v : null;
            });
            return out;
        };

        const example = () => {
            const v = read();
            const pick = (value, fallback) => (Number.isFinite(value) ? value : fallback);
            const base = pick(v.flagfall, r.flagfall) + 3 * pick(v.perKm, r.perKm) + 2 * pick(v.perWaitingMinute, r.perWaitingMinute);
            const price = (cab, tier, extra) => Math.max(pick(v.minimumFare, r.minimumFare),
                Math.round(base * pick(v.cabs[cab.model], cab.rate) * pick(v.tiers[tier.tier], tier.rate) * (extra || 1)));
            const lowCab = cabs[0];
            const topCab = cabs[cabs.length - 1];
            const lowTier = tiers[0];
            const topTier = tiers[tiers.length - 1];
            const box = bodyEl.querySelector('[data-example]');
            if (!lowCab || !lowTier) { box.innerHTML = ''; return; }
            const tip = pick(v.tips[5], (r.tips || {})[5]);
            box.innerHTML = `
                <div class="tb-info"><span class="k">${esc(lowTier.label)}, ${esc(lowCab.label)}</span><span class="v">${money(price(lowCab, lowTier))}</span></div>
                <div class="tb-info"><span class="k">${esc(topTier.label)}, ${esc(topCab.label)}</span><span class="v">${money(price(topCab, topTier))}</span></div>
                <div class="tb-info"><span class="k">${esc(lowTier.label)} at night</span><span class="v">${money(price(lowCab, lowTier, pick(v.night, r.night)))}</span></div>
                <div class="tb-info"><span class="k">A player's call</span><span class="v">${money(price(lowCab, lowTier, pick(v.player, r.player)))}</span></div>
                <div class="tx-note">A five-star ride adds a ${Math.round(tip * 100)}% tip on top.</div>`;
        };

        example();
        bodyEl.querySelectorAll('[data-rate]').forEach((el) => { el.oninput = example; });

        headEl.querySelector('[data-save-rates]').onclick = async () => {
            const result = await act('adminSaveRates', { rates: read() }, 'Rates saved. They start on the next fare.');
            if (result && page === 'pay') payPage(result.rates);
        };
        const reset = headEl.querySelector('[data-reset-rates]');
        if (reset) reset.onclick = async () => {
            if (!(await confirmBox('Go back to the rates in config.lua? The rates saved in game are deleted.', 'Use config.lua', true))) return;
            const result = await act('adminResetRates', {}, 'Back to the config.lua rates.');
            if (result && page === 'pay') payPage(result.rates);
        };
    }

    function shiftOff() {
        const at = S.at && locs.find((l) => l.id === S.at);
        header(at ? `At ${at.name}` : 'Not at a depot', `${icon('shift')} Sign on`);

        if (!at) {
            bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('depots', 'Not at a depot', 'Go to a taxi depot to sign on. Every depot is on the map.')}
                <div class="tx-map" data-map style="margin:0 14px 14px;border-radius:3px"></div></div>`;
            mountMap(bodyEl.querySelector('[data-map]'), (view) => {
                depotPins(view);
                view.fit([S.me, ...locs.map((l) => l.desk)], 3);
            });
            return;
        }

        if (S.jobOk === false) {
            bodyEl.innerHTML = `<div class="tb-card c-fill">${empty('shift', 'Hired drivers only', `${at.name} only signs on drivers with the ${at.job || 'taxi'} job.`)}</div>`;
            return;
        }

        const cabRows = (S.vehicles || []).filter((v) => v.offered).map((v) => `
            <div class="tb-row tx-cab${v.locked ? ' locked' : ''}">
                <div><b>${esc(v.label)}</b><span class="s">Pays x${Number(v.rate).toFixed(2)}</span></div>
                <span class="tb-tag ${v.locked ? '' : 'g-green'}">Tier ${v.tier}</span>
                <span class="m">${v.locked ? 'Locked' : money(S.deposit) + ' deposit'}</span>
                <button class="tb-btn b-sm b-go" data-rent="${esc(v.model)}" ${v.locked ? 'disabled' : ''}>Rent</button>
            </div>`).join('');

        const personal = S.personalAllowed ? `
            <div class="tb-card">
                <div class="tb-ch">${icon('cabs')} Drive your own car<span class="tb-ch-r">${S.carReady ? '<span class="tb-tag g-green">Ready</span>' : '<span class="tb-tag">Get in your car</span>'}</span></div>
                <div class="tb-cb" style="display:flex;gap:12px;align-items:center">
                    <span style="flex:1;color:var(--x-dim);font-size:12.5px">${esc(S.carReady ? 'No deposit. It has to be a car registered to you.' : (S.carProblem || 'Sit in the driver seat of your own car.'))}</span>
                    <button class="tb-btn b-go" data-own ${S.carReady ? '' : 'disabled'}>Sign on in my car</button>
                </div>
            </div>` : '';

        bodyEl.innerHTML = `
            ${personal}
            <div class="tb-card c-fill">
                <div class="tb-ch">${icon('cabs')} Rent a cab<span class="tb-ch-r"><span class="tb-tag">${(at.bays || []).length} bays</span></span></div>
                <div class="tb-scroll">${cabRows || empty('cabs', 'No cabs here', 'This depot does not rent cabs.')}</div>
            </div>
            <div class="tx-hint">Your deposit comes back when you park the cab in a bay at any depot and sign off. Press <span class="tx-kbd">${esc((S.keys || {}).tablet || '/cab')}</span> to open this tablet anywhere on shift.</div>`;

        bodyEl.querySelectorAll('[data-rent]').forEach((b) => {
            b.onclick = async () => {
                b.disabled = true;
                const result = await act('startShift', { location: at.id, model: b.dataset.rent });
                if (!result) b.disabled = false;
            };
        });
        const own = bodyEl.querySelector('[data-own]');
        if (own) own.onclick = async () => {
            own.disabled = true;
            const result = await act('startShift', { location: at.id, personal: true });
            if (!result) own.disabled = false;
        };
    }

    function shiftOn() {
        const v = S.vehicle || {};
        const t = S.totals || {};
        header('You are on shift', `${icon('shift')} Shift`, `<button class="tb-btn b-red" data-signoff>Sign off</button>`);

        bodyEl.innerHTML = `
            <div class="tb-stats">
                <div class="tb-st"><div class="l">Earned</div><div class="v a">${money(t.earned || 0)}</div></div>
                <div class="tb-st"><div class="l">Fares</div><div class="v">${t.fares || 0}</div></div>
                <div class="tb-st"><div class="l">Driven</div><div class="v">${dist(t.distance || 0)}</div></div>
                <div class="tb-st"><div class="l">Rating</div><div class="v">${Number((S.stats || {}).rating || 5).toFixed(1)}</div></div>
            </div>
            <div class="tx-grid">
                <div class="tx-col">
                    <div class="tb-card"><div class="tb-ch">${icon('cabs')} ${v.personal ? 'Your car' : 'Your cab'}</div><div class="tb-cb">
                        <div class="tb-info"><span class="k">Vehicle</span><span class="v">${esc(v.label || '-')}</span></div>
                        <div class="tb-info"><span class="k">Plate</span><span class="v">${esc(v.assignedPlate || v.plate || '-')}</span></div>
                        <div class="tb-info"><span class="k">Pays</span><span class="v">x${Number(v.rate || 1).toFixed(2)} per fare</span></div>
                        <div class="tb-info"><span class="k">Deposit</span><span class="v">${v.personal ? 'None, it is your car' : `${money(S.deposit)} back when it is parked in a depot bay`}</span></div>
                    </div></div>
                    <div class="tb-card"><div class="tb-ch">${icon('lamp')} Roof lamp</div><div class="tb-cb">
                        <div class="tx-switch${S.lamp ? ' on' : ''}" data-lampsw><div class="t"><b>For hire</b><span>On: people flag you down and calls reach you. Off: you are left alone.</span></div><i></i></div>
                    </div></div>
                </div>
                <div class="tx-col"><div class="tb-card c-fill"><div class="tb-ch">${icon('depots')} Depots<span class="tb-ch-r"><button class="tb-btn b-sm" data-nearest>${icon('gps')} Nearest depot</button></span></div><div class="tx-map" data-map></div></div></div>
            </div>`;

        mountMap(bodyEl.querySelector('[data-map]'), (view) => {
            depotPins(view);
            view.fit([S.me, ...locs.map((l) => l.desk)], 3);
        });

        bodyEl.querySelector('[data-lampsw]').onclick = async () => {
            await act('setLamp', { on: !S.lamp });
        };
        bodyEl.querySelector('[data-nearest]').onclick = () => {
            const me = S.me || {};
            let best = null;
            let bestAway = Infinity;
            locs.forEach((l) => {
                const away = Math.hypot(l.desk.x - me.x, l.desk.y - me.y);
                if (away < bestAway) { best = l; bestAway = away; }
            });
            if (best) {
                window.post('gps', { x: best.desk.x, y: best.desk.y });
                toast(`GPS set to ${best.name}.`, 'ok');
            }
        };
        headEl.querySelector('[data-signoff]').onclick = async () => {
            const text = v.personal
                ? 'Sign off now?'
                : `Sign off now? If the cab is not parked in a depot bay you lose the ${money(S.deposit)} deposit.`;
            if (!(await confirmBox(text, 'Sign off', true))) return;
            const result = await act('endShift');
            if (!result) return;
            hide(true);
            window.post('close');
            if (result.summary) window.showShiftSummary(result.summary);
        };
    }

    function depotEditor() {
        const d = draft;
        const isNew = !d.id;
        header(isNew ? 'New depot' : 'Editing depot', `${icon('depots')} ${esc(d.name || 'Untitled depot')}`, `
            ${isNew ? '' : `<button class="tb-btn b-red" data-del>${icon('trash')} Delete</button>`}
            <button class="tb-btn" data-cancel-edit>Cancel</button>
            <button class="tb-btn b-go" data-save>${icon('check')} Save depot</button>`);

        const colourOpts = BLIP_COLOURS.map(([id, name]) => `<option value="${id}" ${Number(d.blip.color) === id ? 'selected' : ''}>${name}</option>`).join('');
        const spriteOpts = BLIP_SPRITES.map(([id, name]) => `<option value="${id}" ${Number(d.blip.sprite) === id ? 'selected' : ''}>${name}</option>`).join('');
        const scaleOpts = BLIP_SCALES.map(([v, name]) => `<option value="${v}" ${Math.abs(Number(d.blip.scale) - v) < 0.01 ? 'selected' : ''}>${name}</option>`).join('');
        const cabs = admin.cabs || [];
        const allowed = d.cabs ? new Set(d.cabs) : null;
        const cabSwitches = cabs.map((c) => `
            <div class="tx-switch${!allowed || allowed.has(c.model) ? ' on' : ''}" data-cab="${esc(c.model)}"><div class="t"><b>${esc(c.label)}</b><span>Tier ${c.tier}</span></div><i></i></div>`).join('');
        const bays = (d.bays || []).map((b, i) => `
            <div class="tb-row tx-bayrow">
                <span class="tb-tag g-yellow">Bay ${i + 1}</span>
                <span class="m">${b.x.toFixed(1)}, ${b.y.toFixed(1)} · ${Math.round(b.w)}°</span>
                <span style="display:flex;gap:6px"><button class="tb-btn b-sm" data-gps="${b.x},${b.y}">${icon('gps')}</button><button class="tb-btn b-sm b-red" data-unbay="${i + 1}">${icon('trash')}</button></span>
            </div>`).join('');

        bodyEl.innerHTML = `
            <div class="tx-grid" style="grid-template-columns:minmax(0,1fr) minmax(0,1fr)">
                <div class="tx-col">
                    <div class="tb-card c-fill"><div class="tb-ch">${icon('edit')} Details</div><div class="tb-scroll"><div class="tb-cb">
                        <div class="tb-form">
                            <div class="f-wide"><label class="tb-label">Name</label><input class="tb-input" data-field="name" maxlength="48" value="${esc(d.name)}" placeholder="Downtown Cab Co."></div>
                            <div><label class="tb-label">Blip icon</label><select class="tb-input" data-field="blip.sprite">${spriteOpts}</select></div>
                            <div><label class="tb-label">Blip colour</label><select class="tb-input" data-field="blip.color">${colourOpts}</select></div>
                            <div><label class="tb-label">Blip size</label><select class="tb-input" data-field="blip.scale">${scaleOpts}</select></div>
                            <div><label class="tb-label">Job needed</label><input class="tb-input" data-field="job" maxlength="32" value="${esc(d.job || '')}" placeholder="Anyone"></div>
                            <div class="f-wide"><label class="tb-label">Dispatcher model</label><input class="tb-input" data-field="dispatcher.model" maxlength="40" value="${esc(d.dispatcher.model || '')}"></div>
                        </div>
                        <div style="margin-top:12px">
                            <div class="tx-switch${d.blip.show !== false ? ' on' : ''}" data-toggle="blip.show"><div class="t"><b>Show on the map</b><span>A blip everyone can see.</span></div><i></i></div>
                            <div class="tx-switch${d.dispatcher.ped !== false ? ' on' : ''}" data-toggle="dispatcher.ped"><div class="t"><b>Dispatcher</b><span>A person to talk to. Off: a terminal you use with your target key.</span></div><i></i></div>
                            <div class="tx-switch${d.personal ? ' on' : ''}" data-toggle="personal"><div class="t"><b>Own cars allowed</b><span>Drivers can sign on in a car registered to them. No deposit.</span></div><i></i></div>
                        </div>
                        <span class="tb-label" style="margin-top:14px">Cabs this depot rents</span>
                        ${cabSwitches}
                    </div></div></div>
                </div>
                <div class="tx-col">
                    <div class="tb-card">
                        <div class="tb-ch">${icon('pin')} Where things go</div>
                        <div class="tb-cb">
                            <div class="tx-hint" style="margin-bottom:10px">Close the tablet, go to the spot, open it again and press a button. <b>Your changes are kept.</b> Markers show where everything is while you edit.</div>
                            <div class="tb-info"><span class="k">Dispatcher</span><span class="v">${d.desk ? `${d.desk.x.toFixed(1)}, ${d.desk.y.toFixed(1)}` : 'Not set'}</span></div>
                            <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
                                <button class="tb-btn" data-desk>${icon('pin')} Dispatcher stands here</button>
                                <button class="tb-btn b-go" data-bay>${icon('plus')} Add a cab bay here</button>
                            </div>
                        </div>
                    </div>
                    <div class="tb-card" style="max-height:200px"><div class="tb-ch">${icon('cabs')} Cab bays<span class="tb-ch-r"><span class="tb-tag">${(d.bays || []).length}/16</span></span></div>
                        <div class="tb-scroll">${bays || empty('cabs', 'No bays yet', 'Park where a cab should appear and press Add a cab bay here.')}</div></div>
                    <div class="tb-card c-fill"><div class="tx-map" data-map></div></div>
                </div>
            </div>`;

        mountMap(bodyEl.querySelector('[data-map]'), (view) => {
            if (d.desk) view.pin(d.desk.x, d.desk.y, 'depot', { title: 'Dispatcher' });
            (d.bays || []).forEach((b, i) => view.pin(b.x, b.y, 'bay', { text: String(i + 1) }));
            view.fit([d.desk, ...(d.bays || [])], 5);
        });

        wireCommon();

        bodyEl.querySelectorAll('[data-field]').forEach((el) => {
            el.onchange = async () => {
                const result = await window.post('builderField', { key: el.dataset.field, value: el.value });
                if (result && result.draft) {
                    draft = result.draft;
                    if (el.dataset.field === 'name') headEl.querySelector('.tb-ph-title').innerHTML = `${icon('depots')} ${esc(draft.name || 'Untitled depot')}`;
                }
            };
        });
        bodyEl.querySelectorAll('[data-toggle]').forEach((el) => {
            el.onclick = async () => {
                const on = !el.classList.contains('on');
                const result = await window.post('builderField', { key: el.dataset.toggle, value: on });
                if (result && result.draft) { draft = result.draft; el.classList.toggle('on', on); }
            };
        });
        bodyEl.querySelectorAll('[data-cab]').forEach((el) => {
            el.onclick = async () => {
                el.classList.toggle('on');
                const picked = [...bodyEl.querySelectorAll('[data-cab].on')].map((n) => n.dataset.cab);
                const value = picked.length === cabs.length ? null : picked;
                const result = await window.post('builderField', { key: 'cabs', value });
                if (result && result.draft) draft = result.draft;
            };
        });
        bodyEl.querySelector('[data-desk]').onclick = async () => {
            const result = await act('builderDesk', {}, 'Dispatcher placed where you stand.');
            if (result) { draft = result.draft; render(); }
        };
        bodyEl.querySelector('[data-bay]').onclick = async () => {
            const result = await act('builderBay', {}, 'Bay added.');
            if (result) { draft = result.draft; render(); }
        };
        bodyEl.querySelectorAll('[data-unbay]').forEach((b) => {
            b.onclick = async () => {
                const result = await act('builderRemoveBay', { index: Number(b.dataset.unbay) });
                if (result) { draft = result.draft; render(); }
            };
        });
        headEl.querySelector('[data-save]').onclick = async () => {
            const name = bodyEl.querySelector('[data-field="name"]');
            if (name && name.value !== (draft.name || '')) await window.post('builderField', { key: 'name', value: name.value });
            const result = await act('builderSave', {}, 'Depot saved.');
            if (result) {
                draft = null;
                if (result.locations) locs = result.locations;
                render();
            }
        };
        headEl.querySelector('[data-cancel-edit]').onclick = async () => {
            await window.post('builderCancel');
            draft = null;
            render();
        };
        const del = headEl.querySelector('[data-del]');
        if (del) del.onclick = async () => {
            if (!(await confirmBox(`Delete ${d.name}? Drivers can no longer sign on there.`, 'Delete depot', true))) return;
            const result = await act('builderDelete', { id: d.id }, 'Depot deleted.');
            if (result) {
                draft = null;
                if (result.locations) locs = result.locations;
                render();
            }
        };
    }

    function wireCommon() {
        root.querySelectorAll('[data-gps]').forEach((b) => {
            b.onclick = () => {
                const [x, y] = b.dataset.gps.split(',').map(Number);
                window.post('gps', { x, y });
                toast('GPS set.', 'ok');
            };
        });
        root.querySelectorAll('[data-find]').forEach((b) => {
            b.onclick = async () => {
                b.disabled = true;
                const result = await act('requestFare', {}, 'Dispatch found you a fare.');
                b.disabled = false;
                if (result) {
                    hide(true);
                    window.post('close');
                }
            };
        });
        const lampBtn = headEl.querySelector('[data-lamp]');
        if (lampBtn) lampBtn.onclick = () => act('setLamp', { on: !S.lamp });
        const goFare = bodyEl.querySelector('[data-go-fare]');
        if (goFare) goFare.onclick = () => go('fare');
    }

    function setState(next) {
        if (!next) return;
        S = next;
        S.openedAt = Date.now();
        if (Array.isArray(next.locations)) locs = next.locations;
        if (Array.isArray(next.offers)) offers = next.offers.map((o) => ({ ...o, seenAt: Date.now() }));
        if ('builder' in next) draft = next.builder || null;
        if (open) render();
    }

    async function loadAdminCabs() {
        if (!S || !S.isAdmin || admin.cabs) return;
        const data = await window.post('adminLocations');
        if (data && data.ok) {
            admin.cabs = data.cabs || [];
            if (Array.isArray(data.locations)) locs = data.locations;
            if (open && page === 'depots') render();
        }
    }

    function show(state) {
        open = true;
        document.body.classList.add('tablet-open');
        root.classList.remove('hidden');
        fit();
        setState(state);
        page = state.page || (draft && state.isAdmin ? 'depots' : !state.onDuty ? 'shift' : hasFare() ? 'fare' : 'calls');
        render();
        loadAdminCabs();
    }

    function hide(silent) {
        open = false;
        document.body.classList.remove('tablet-open');
        dropMap();
        root.classList.add('hidden');
        if (modalResolve) modalResolve(false);
        if (!silent) window.post('close');
    }

    function meter(data) {
        if (!data) return;
        const before = hasFare();
        live = data.onDuty ? data : null;
        if (S && data.onDuty !== undefined) S.onDuty = !!data.onDuty;
        if (S && typeof data.lamp === 'boolean') S.lamp = data.lamp;
        if (data.totals && S) S.totals = data.totals;
        if (!open) return;

        if (before !== hasFare() && (page === 'fare' || page === 'calls')) {
            render();
            return;
        }

        if (page === 'fare' && live && live.hasFare) {
            const set = (key, value) => {
                const el = bodyEl.querySelector(`[data-live="${key}"]`);
                if (el) el.innerHTML = value;
            };
            set('amount', money(live.amount || 0));
            set('distance', dist(live.distance || 0));
            set('elapsed', window.fmt.duration(live.elapsed || 0));
            set('rating', stars(live.rating || 5));
            set('away', live.away != null ? dist(live.away) : '-');
            set('stage', esc({ toPickup: 'Heading to the pickup', boarding: 'Waiting for them to get in', riding: 'Passenger aboard' }[live.stage] || 'On the way'));
            if (mapView && live.me) mapView.setMe(live.me.x, live.me.y);
        }
        renderRail();
    }

    function rideOffer(offer) {
        if (!offer) return;
        offers = offers.filter((o) => o.id !== offer.id);
        offers.unshift({ ...offer, seenAt: Date.now() });
        if (open) {
            if (page === 'calls') render();
            else renderRail();
        }
    }

    function rideGone(id) {
        offers = offers.filter((o) => o.id !== id);
        if (open) {
            if (page === 'calls') render();
            else renderRail();
        }
    }

    function lamp(on) {
        if (!S) return;
        S.lamp = !!on;
        if (open && (page === 'calls' || page === 'shift')) render();
    }

    function locations(list) {
        locs = Array.isArray(list) ? list : [];
        if (open && (page === 'depots' || page === 'shift')) render();
    }

    function builder(next) {
        draft = next || null;
        if (open && page === 'depots') render();
    }

    function me(pos) {
        if (!S || !pos) return;
        S.me = pos;
        if (mapView) mapView.setMe(pos.x, pos.y);
    }

    function fareComplete() {
        live = null;
        if (open) refresh();
    }

    root.querySelector('[data-close]').onclick = () => hide();

    document.addEventListener('keyup', (event) => {
        if (event.key !== 'Escape' || !open) return;
        if (modalResolve) {
            modalResolve(false);
            return;
        }
        if (window.summaryIsOpen && window.summaryIsOpen()) return;
        hide();
    });

    return {
        show, hide, setState, meter, rideOffer, rideGone, lamp, locations, builder, me, fareComplete, refresh,
        isOpen: () => open,
    };
})();
