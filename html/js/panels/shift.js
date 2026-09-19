window.Panels.shift = {
    render(state) {
        const stats = state.stats || {};
        const totals = state.totals || {};

        if (!state.onDuty) {
            return `
                <div class="grid tiles" style="margin-bottom:16px">
                    <div class="tile amber"><div class="v">${window.fmt.escape(stats.tierLabel || 'Trainee')}</div><div class="l">Tier ${stats.tier || 1}</div></div>
                    <div class="tile"><div class="v">${stats.reputation || 0}</div><div class="l">Reputation</div></div>
                    <div class="tile"><div class="v">${window.fmt.stars(stats.rating)}</div><div class="l">Rating</div></div>
                    <div class="tile"><div class="v">${stats.totalFares || 0}</div><div class="l">Fares driven</div></div>
                </div>

                <div class="card">
                    <h3>Sign on</h3>
                    <div class="sub">Take a cab from the roster and the meter is yours. A ${window.fmt.money(state.deposit)} deposit is held until you bring it back.</div>
                    ${this.tierBar(stats)}
                    <div class="row" style="margin-top:16px">
                        <button class="btn" data-go="vehicles">Pick a cab</button>
                        ${state.hailEnabled ? '<span class="pill">Players can call you with /taxi</span>' : ''}
                    </div>
                </div>`;
        }

        return `
            <div class="grid tiles" style="margin-bottom:16px">
                <div class="tile amber"><div class="v">${window.fmt.money(totals.earned || 0)}</div><div class="l">Earned this shift</div></div>
                <div class="tile"><div class="v">${totals.fares || 0}</div><div class="l">Fares</div></div>
                <div class="tile"><div class="v">${window.fmt.distance(totals.distance || 0)}</div><div class="l">Driven</div></div>
                <div class="tile"><div class="v">${window.fmt.escape(state.vehicle ? state.vehicle.label : '-')}</div><div class="l">Your cab</div></div>
            </div>

            <div class="grid two">
                <div class="card">
                    <h3>Work</h3>
                    <div class="sub">${state.openEnded
                        ? 'Someone hailed you. Drive them where they ask, then end the ride to take the fare.'
                        : state.hasFare
                            ? 'You have a fare running. Finish it before picking up another.'
                            : 'Call the dispatcher for the nearest passenger, or wait for someone to hail you.'}</div>
                    <div class="row wrap">
                        ${state.openEnded
                            ? '<button class="btn good" data-act="endRide">End the ride</button>'
                            : `<button class="btn" data-act="requestFare" ${state.hasFare ? 'disabled' : ''}>Find a fare</button>`}
                        <button class="btn quiet" data-act="cancelFare" ${state.hasFare ? '' : 'disabled'}>Drop the fare</button>
                    </div>
                </div>

                <div class="card">
                    <h3>Sign off</h3>
                    <div class="sub">Park in a depot bay to get the deposit back. Damage comes off it.</div>
                    <button class="btn bad" data-act="endShift">End shift</button>
                </div>
            </div>

            <div class="card" style="margin-top:12px">
                <h3>Standing</h3>
                <div class="sub">${window.fmt.escape(stats.tierLabel || 'Trainee')} - every fare pays ${Math.round(((stats.fareMultiplier || 1) - 1) * 100)}% over base.</div>
                ${this.tierBar(stats)}
            </div>`;
    },

    tierBar(stats) {
        if (!stats.nextTier) {
            return '<div class="pill ok">Top tier reached</div>';
        }
        const pct = Math.round((stats.progress || 0) * 100);
        return `
            <div style="font-size:12px;color:var(--muted)">${stats.reputation || 0} / ${stats.nextTier.at} rep to ${window.fmt.escape(stats.nextTier.label)}</div>
            <div class="bar"><span style="width:${pct}%"></span></div>`;
    },

    wire(host) {
        host.querySelectorAll('[data-go]').forEach((button) => {
            button.addEventListener('click', () => {
                const tab = document.querySelector(`.tab[data-tab="${button.dataset.go}"]`);
                if (tab) tab.click();
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
