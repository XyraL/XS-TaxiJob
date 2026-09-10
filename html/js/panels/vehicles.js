window.Panels.vehicles = {
    render(state) {
        const list = state.vehicles || [];

        return `
            <div class="card" style="margin-bottom:14px">
                <h3>The roster</h3>
                <div class="sub">${state.onDuty
                    ? 'You already have a cab out. Sign off before swapping.'
                    : `Every cab is rented against a ${window.fmt.money(state.deposit)} deposit. Better cabs pay a higher rate and unlock with reputation.`}</div>
            </div>

            ${list.map((vehicle) => `
                <div class="cab ${vehicle.locked ? 'locked' : ''}">
                    <div class="grow">
                        <div class="name">${window.fmt.escape(vehicle.label)}</div>
                        <div class="meta">${this.rateLabel(vehicle.rate)} &middot; tier ${vehicle.tier}</div>
                    </div>
                    ${vehicle.locked
                        ? `<span class="pill locked">Tier ${vehicle.tier}</span>`
                        : state.onDuty
                            ? '<span class="pill">Sign off first</span>'
                            : `<button class="btn" data-model="${window.fmt.escape(vehicle.model)}">Take it out</button>`}
                </div>`).join('')}`;
    },

    rateLabel(rate) {
        const bonus = Math.round(((Number(rate) || 1) - 1) * 100);
        return bonus > 0 ? `+${bonus}% on every fare` : 'base fare rate';
    },

    wire(host) {
        host.querySelectorAll('[data-model]').forEach((button) => {
            button.addEventListener('click', async () => {
                host.querySelectorAll('[data-model]').forEach((b) => { b.disabled = true; });

                const result = await window.post('startShift', { model: button.dataset.model });
                if (result && result.ok === false) {
                    host.querySelectorAll('[data-model]').forEach((b) => { b.disabled = false; });
                    window.Panels.shift.flash(host, result.error || 'The depot refused that.');
                    return;
                }
                // The terminal closes itself on a successful sign-on.
            });
        });
    },
};
