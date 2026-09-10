window.Panels = {};

window.fmt = {
    money(amount) {
        const value = Math.round(Number(amount) || 0);
        return `$${value.toLocaleString('en-US')}`;
    },

    distance(metres) {
        const value = Number(metres) || 0;
        return value < 1000 ? `${Math.round(value)}m` : `${(value / 1000).toFixed(1)}km`;
    },

    duration(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(total / 60);
        if (minutes < 60) return `${minutes}:${String(total % 60).padStart(2, '0')}`;
        return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
    },

    stars(rating) {
        const value = Math.max(1, Math.min(5, Math.round(Number(rating) || 5)));
        return '★'.repeat(value) + '☆'.repeat(5 - value);
    },

    escape(value) {
        return String(value ?? '')
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    },
};

window.post = (name, data = {}) =>
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    })
        .then((r) => r.json())
        .catch(() => ({ ok: false, error: 'The resource did not answer.' }));

const terminal = document.getElementById('terminal');
const panelHost = document.getElementById('panel');
const driverLine = document.getElementById('driver-line');

let state = null;
let activeTab = 'shift';

function renderPanel() {
    const panel = window.Panels[activeTab];
    panelHost.innerHTML = panel && state ? panel.render(state) : '<div class="empty">Nothing to show.</div>';
    if (panel && panel.wire && state) panel.wire(panelHost, state);
}

function setState(next) {
    if (!next) return;
    state = next;

    const stats = state.stats || {};
    driverLine.textContent = state.onDuty
        ? `On duty - ${state.vehicle ? state.vehicle.label : 'cab out'}`
        : `${stats.tierLabel || 'Trainee'} - ${stats.reputation || 0} rep`;

    renderPanel();
}

// Panels ask for a refresh after anything that changes the driver's standing,
// so the tiles and the cab roster never drift from the server.
window.refresh = async () => {
    const next = await window.post('getState');
    if (next) setState(next);
};

window.openTerminal = (next) => {
    setState(next);
    terminal.classList.remove('hidden');
};

function closeTerminal() {
    terminal.classList.add('hidden');
    window.post('close');
}

document.getElementById('close').addEventListener('click', closeTerminal);

document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
        activeTab = tab.dataset.tab;
        document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t === tab));
        renderPanel();
    });
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !terminal.classList.contains('hidden')) closeTerminal();
});

/* ------------------------------------------------------------- summary */

const summary = document.getElementById('summary');
document.getElementById('summary-close').addEventListener('click', () => summary.classList.add('hidden'));

function showSummary(result) {
    const rows = [
        ['Fare', window.fmt.money(result.fare)],
        ['Tip', window.fmt.money(result.tip)],
        ['Rating', window.fmt.stars(result.rating)],
        ['Reputation', `+${result.reputation || 0}`],
    ];

    document.getElementById('summary-rows').innerHTML = `
        ${rows.map(([label, value]) => `<div class="r"><span>${label}</span><span>${value}</span></div>`).join('')}
        <div class="r big"><span>Paid</span><span>${window.fmt.money((result.fare || 0) + (result.tip || 0))}</span></div>`;

    summary.classList.remove('hidden');
    setTimeout(() => summary.classList.add('hidden'), 6000);
}

window.showShiftSummary = (shift) => {
    const rows = [
        ['Fares', shift.fares || 0],
        ['Time on shift', `${shift.minutes || 0} min`],
        ['Driven', window.fmt.distance(shift.distance || 0)],
        ['Deposit back', window.fmt.money(shift.refund || 0)],
    ];

    if (shift.damageFee) rows.push(['Damage', `-${window.fmt.money(shift.damageFee)}`]);
    if (shift.abandoned) rows.push(['Abandoned a fare', 'yes']);

    document.querySelector('#summary h2').textContent = 'Shift over';
    document.getElementById('summary-rows').innerHTML = `
        ${rows.map(([label, value]) => `<div class="r"><span>${label}</span><span>${value}</span></div>`).join('')}
        <div class="r big"><span>Earned</span><span>${window.fmt.money(shift.earned || 0)}</span></div>`;

    summary.classList.remove('hidden');
};

/* -------------------------------------------------------------- bridge */

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'open':
            window.openTerminal(message.state);
            break;
        case 'close':
            terminal.classList.add('hidden');
            break;
        case 'meter':
            window.Meter.update(message.data);
            break;
        case 'fareComplete':
            showSummary(message.data);
            window.Meter.clearRoute();
            break;
        case 'hailOffer':
            window.Meter.addHail(message.data);
            break;
        case 'hailDismiss':
            window.Meter.removeHail(message.data.id);
            break;
        default:
            break;
    }
});
