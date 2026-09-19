window.Panels.shift = {
    render(state) {
        const stats = state.stats || {};
        const totals = state.totals || {};

        return state.onDuty ? this.onDuty(state, stats, totals) : this.offDuty(state, stats);
    },

    //[[ Off duty, the question is "how do I start?"
    //
    //   It used to be a card whose only action bounced you to another tab to
    //   do the actual thing. The cabs you can take out right now belong here;
    //   the Cabs screen keeps the full roster and what unlocks the rest. ]]
    offDuty(state, stats) {
        const open = (state.vehicles || []).filter((v) => !v.locked);
        const next = (state.vehicles || []).find((v) => v.locked);

        return `
            <div class="grid tiles" style="margin-bottom:18px">
                <div class="tile amber">
                    <div class="v">${window.fmt.escape(stats.tierLabel || 'Trainee')}</div>
                    <div class="l">${stats.nextTier
                        ? `${stats.reputation || 0} / ${stats.nextTier.at} rep to ${window.fmt.escape(stats.nextTier.label)}`
                        : `Tier ${stats.tier || 1} — top of the ladder`}</div>
                    ${this.tierBar(stats)}
                </div>
                <div class="tile"><div class="v">${window.fmt.stars(stats.rating)}</div><div class="l">Average rating</div></div>
                <div class="tile"><div class="v">${stats.totalFares || 0}</div><div class="l">Fares driven</div></div>
                <div class="tile"><div class="v">${window.fmt.money(stats.totalEarned || 0)}</div><div class="l">Lifetime</div></div>
            </div>

            <div class="section-title">Take a cab out</div>
            <div class="sub" style="margin-bottom:12px">A ${window.fmt.money(state.deposit)} deposit is held while the cab is out. You get it back when you bring the cab back.</div>

            ${open.length ? open.map((v) => `
                <div class="cab">
                    <div class="grow">
                        <div class="name">${window.fmt.escape(v.label)}</div>
                        <div class="meta">${this.rateLabel(v.rate)}</div>
                    </div>
                    <button class="btn amber" data-model="${window.fmt.escape(v.model)}">Take it</button>
                </div>`).join('') : '<div class="empty">No cab on the roster is open to you yet.</div>'}

            <div class="row wrap" style="margin-top:14px">
                <button class="btn quiet" data-go="vehicles">See the whole roster</button>
                ${next ? `<span class="pill off">Tier ${next.tier} for the ${window.fmt.escape(next.label)}</span>` : ''}
            </div>`;
    },

    //[[ On duty, the question is "how do I get work, and how do I stop?" ]]
    onDuty(state, stats, totals) {
        return `
            <div class="grid tiles" style="margin-bottom:18px">
                <div class="tile amber"><div class="v">${window.fmt.money(totals.earned || 0)}</div><div class="l">Earned this shift</div></div>
                <div class="tile"><div class="v">${totals.fares || 0}</div><div class="l">Fares</div></div>
                <div class="tile"><div class="v">${window.fmt.distance(totals.distance || 0)}</div><div class="l">Driven</div></div>
                <div class="tile"><div class="v">${window.fmt.escape(state.vehicle ? state.vehicle.label : '-')}</div><div class="l">Your cab</div></div>
            </div>

            <div class="section-title">Work</div>
            ${state.hasFare ? this.onAFare(state) : this.lookingForWork(state)}

            <div class="section-title" style="margin-top:18px">Sign off</div>
            <div class="card">
                <div class="sub">Park in a depot bay to get the deposit back. Damage comes off it.</div>
                <div class="row wrap" style="margin-top:12px">
                    <button class="btn bad" data-act="endShift">End shift</button>
                    <span class="meta">Deposit held: ${window.fmt.money(state.deposit)}</span>
                </div>
            </div>

            <div class="card" style="margin-top:12px">
                <h3>Standing</h3>
                <div class="sub">${window.fmt.escape(stats.tierLabel || 'Trainee')} — every fare pays ${Math.round(((stats.fareMultiplier || 1) - 1) * 100)}% over base.</div>
                ${this.tierBar(stats)}
            </div>`;
    },

    // Two ways in, side by side: one you ask for, one that comes to you.
    lookingForWork(state) {
        const lamp = state.lamp !== false;

        return `
            <div class="grid two">
                <div class="card">
                    <h3>Call dispatch</h3>
                    <div class="sub">They find the nearest passenger and put it on your map.</div>
                    <div class="row wrap" style="margin-top:12px">
                        <button class="btn amber" data-act="requestFare">Find a fare</button>
                    </div>
                </div>

                <div class="card">
                    <h3>Street work</h3>
                    <div class="sub">Lamp on, people flag you down as you pass${state.hailEnabled ? ' and players can call you with /taxi' : ''}.</div>
                    <div class="row wrap" style="margin-top:12px">
                        <button class="btn ${lamp ? 'amber' : 'quiet'}" data-lamp="${lamp ? 'off' : 'on'}">${lamp ? 'Lamp on' : 'Lamp off'}</button>
                        <span class="meta">${lamp ? 'Anyone can flag you down.' : 'Nobody will stop you.'}</span>
                    </div>
                </div>
            </div>`;
    },

    onAFare(state) {
        return `
            <div class="card">
                <h3>On a fare</h3>
                <div class="sub">${state.openEnded
                    ? 'Someone hailed you. Drive them where they ask, then end the ride to take the fare.'
                    : 'The meter is running. Finish this one before picking up another.'}</div>
                <div class="row wrap" style="margin-top:12px">
                    ${state.openEnded
                        ? '<button class="btn amber" data-act="endRide">End the ride</button>'
                        : ''}
                    <button class="btn bad" data-act="cancelFare">Drop the fare</button>
                </div>
            </div>`;
    },

    rateLabel(rate) {
        const bonus = Math.round(((Number(rate) || 1) - 1) * 100);
        return bonus > 0 ? `+${bonus}% on every fare` : 'base fare rate';
    },

    tierBar(stats) {
        if (!stats.nextTier) return '<div class="pill ok">Top tier reached</div>';

        const percent = Math.round((stats.progress || 0) * 100);

        return `<div class="bar" title="${stats.reputation || 0} / ${stats.nextTier.at} rep to ${window.fmt.escape(stats.nextTier.label)}"><span style="width:${percent}%"></span></div>`;
    },

    wire(host) {
        host.querySelectorAll('[data-go]').forEach((button) => {
            button.addEventListener('click', () => {
                const tab = document.querySelector(`.tab[data-tab="${button.dataset.go}"]`);
                if (tab) tab.click();
            });
        });

        // Taking a cab out from this screen, rather than being sent to another
        // one to do it.
        host.querySelectorAll('[data-model]').forEach((button) => {
            button.addEventListener('click', async () => {
                button.disabled = true;

                const result = await window.post('startShift', { model: button.dataset.model });

                if (result && result.ok === false && result.error) {
                    button.disabled = false;
                    window.Panels.shift.flash(host, result.error);
                    return;
                }

                await window.refresh();
            });
        });

        host.querySelectorAll('[data-lamp]').forEach((button) => {
            button.addEventListener('click', async () => {
                await window.post('setLamp', { on: button.dataset.lamp === 'on' });
                await window.refresh();
            });
        });

        host.querySelectorAll('[data-act]').forEach((button) => {
            button.addEventListener('click', async () => {
                button.disabled = true;
                const result = await window.post(button.dataset.act);
                if (result && result.ok === false && result.error) {
                    button.disabled = false;
                    window.Panels.shift.flash(host, result.error);
                    return;
                }

                if (button.dataset.act === 'endShift' && result && result.summary) {
                    window.showShiftSummary(result.summary);
                }

                await window.refresh();
            });
        });
    },

    flash(host, message) {
        let banner = host.querySelector('.flash');
        if (!banner) {
            banner = document.createElement('div');
            banner.className = 'flash pill';
            banner.style.cssText = 'display:block;margin-top:12px;color:#ff9d95;border-color:rgba(229,87,77,.35)';
            host.appendChild(banner);
        }
        banner.textContent = message;
    },
};
