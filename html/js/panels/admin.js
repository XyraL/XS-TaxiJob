const esc = (v) => window.fmt.escape(v);

let admin = null;

async function load() {
    admin = await window.post('adminState');
    const host = document.getElementById('panel');
    if (host && window.Panels.admin) {
        host.innerHTML = window.Panels.admin.render(window.__state || {});
        window.Panels.admin.wire(host);
    }
}

function driverRow(d) {
    const fare = d.fare
        ? `${esc(d.fare.pickup || '?')} &rarr; ${esc(d.fare.dropoff || '?')}${d.fare.boarded ? '' : ' <span class="pill warn">waiting</span>'}`
        : '<span class="pill off">idle</span>';

    return `
        <tr data-src="${d.src}">
            <td>
                <div>${esc(d.name)}</div>
                <div class="mono">${esc(d.citizenid)}</div>
            </td>
            <td><span class="pill ${d.onDuty ? 'on' : 'off'}">${d.onDuty ? 'On shift' : 'Off'}</span></td>
            <td>${esc(d.vehicle || '—')}</td>
            <td>${fare}</td>
            <td class="mono">${window.fmt.money(d.earned)}</td>
            <td class="mono">${d.fares}</td>
            <td class="mono">${d.reputation} <span style="color:var(--faint)">${esc(d.tier)}</span></td>
            <td style="text-align:right;white-space:nowrap">
                <button class="btn sm" data-act="rep">Rep +10</button>
                <button class="btn sm" data-act="rep-down">-10</button>
                <button class="btn sm" data-act="clear" ${d.fare ? '' : 'disabled'}>Clear fare</button>
                <button class="btn sm danger" data-act="end" ${d.onDuty ? '' : 'disabled'}>End</button>
            </td>
        </tr>`;
}

window.Panels.admin = {
    render() {
        if (!admin) {
            load();
            return '<div class="empty">Reading the depot…</div>';
        }

        if (!admin.ok) {
            return `<div class="empty">${esc(admin.error || 'You are not allowed in here.')}</div>`;
        }

        const t = admin.totals || {};
        const s = admin.settings || {};
        const all = t.allTime;

        return `
            <div class="tiles">
                <div class="tile"><b>${t.onDuty || 0}</b><label>Drivers on shift</label></div>
                <div class="tile"><b>${window.fmt.money(t.earnedThisShift)}</b><label>Earned this shift</label></div>
                <div class="tile"><b>${t.faresThisShift || 0}</b><label>Fares this shift</label></div>
                <div class="tile"><b>${all ? window.fmt.money(all.earned) : '—'}</b><label>Paid out all time</label></div>
            </div>

            <div class="section-title">Dispatch</div>
            <div class="cards">
                <div class="card">
                    <h3>Live switches</h3>
                    <p>These hold until the next restart, then config.lua takes over again. For handling a situation now, not for tuning the server.</p>

                    <div class="field">
                        <label class="toggle">
                            <input type="checkbox" id="set-paused" ${s.paused ? 'checked' : ''}>
                            <span class="toggle-track"></span>
                            <span>Pause dispatch — no new fares handed out</span>
                        </label>
                    </div>

                    <div class="field">
                        <label class="toggle">
                            <input type="checkbox" id="set-hail" ${s.hailEnabled ? 'checked' : ''}>
                            <span class="toggle-track"></span>
                            <span>Players can hail a cab</span>
                        </label>
                    </div>

                    <div class="field">
                        <label for="set-mult">Fare multiplier</label>
                        <input type="number" id="set-mult" value="${Number(s.fareMultiplier || 1).toFixed(2)}"
                               min="0.1" max="5" step="0.05">
                    </div>

                    <button class="btn primary" id="save-settings">Apply</button>
                </div>

                <div class="card">
                    <h3>Wipe a record</h3>
                    <p>Clears a driver's reputation, rating and fare history for good. They keep their money.</p>
                    <div class="field">
                        <label for="wipe-cid">Citizen id</label>
                        <input type="text" id="wipe-cid" placeholder="ABC12345">
                    </div>
                    <button class="btn danger" id="wipe">Wipe record</button>
                </div>
            </div>

            <div class="section-title">Drivers</div>
            ${(admin.drivers || []).length === 0
                ? '<div class="empty">Nobody is signed on.</div>'
                : `<table class="table">
                    <thead>
                        <tr><th>Driver</th><th>State</th><th>Cab</th><th>Fare</th>
                            <th>Earned</th><th>Fares</th><th>Standing</th><th></th></tr>
                    </thead>
                    <tbody>${admin.drivers.map(driverRow).join('')}</tbody>
                   </table>`}`;
    },

    wire(host) {
        if (!admin || !admin.ok) return;

        host.querySelector('#save-settings')?.addEventListener('click', async () => {
            await window.post('adminSetting', { key: 'paused', value: host.querySelector('#set-paused').checked });
            await window.post('adminSetting', { key: 'hailEnabled', value: host.querySelector('#set-hail').checked });
            await window.post('adminSetting', {
                key: 'fareMultiplier',
                value: parseFloat(host.querySelector('#set-mult').value) || 1,
            });
            load();
        });

        host.querySelector('#wipe')?.addEventListener('click', async () => {
            const citizenid = host.querySelector('#wipe-cid').value.trim();
            if (!citizenid) return;
            await window.post('adminWipe', { citizenid });
            host.querySelector('#wipe-cid').value = '';
            load();
        });

        host.querySelectorAll('tbody tr').forEach((row) => {
            const src = Number(row.dataset.src);

            row.addEventListener('click', async (e) => {
                const act = e.target.dataset.act;
                if (!act) return;

                if (act === 'end') {
                    await window.post('adminEndShift', { src });
                } else if (act === 'clear') {
                    await window.post('adminClearFare', { src });
                } else if (act === 'rep' || act === 'rep-down') {
                    // prompt() is inert in CEF — the button did nothing at all,
                    // with no dialog and no error, while End and Clear on the
                    // same row worked.
                    const amount = act === 'rep' ? 10 : -10;
                    await window.post('adminSetReputation', { src, amount });
                }

                load();
            });
        });
    },

    refresh: load,
};
