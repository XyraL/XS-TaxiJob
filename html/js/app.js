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

window.resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'XS-TaxiJob';

window.post = window.post || ((name, data = {}) =>
    fetch(`https://${window.resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    })
        .then((r) => r.json())
        .catch(() => ({ ok: false, error: 'The script did not answer.' })));

window.keys = { tablet: '/cab' };

const summary = document.getElementById('summary');
let shiftSummaryOpen = false;

window.summaryIsOpen = () => shiftSummaryOpen;

function closeShiftSummary() {
    summary.classList.add('hidden');
    if (!shiftSummaryOpen) return;
    shiftSummaryOpen = false;
    window.post('summaryClosed');
}

document.getElementById('summary-close').addEventListener('click', closeShiftSummary);

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && shiftSummaryOpen) closeShiftSummary();
});

function rowsHtml(rows) {
    return rows.map(([label, value]) => `<div class="r"><span>${label}</span><span>${value}</span></div>`).join('');
}

function showFareReceipt(result) {
    document.querySelector('#summary h2').textContent = 'Fare complete';
    summary.classList.add('dock');
    summary.classList.remove('full');

    if (window.Meter && window.Meter.showPaid) window.Meter.showPaid(result || {});

    document.getElementById('summary-rows').innerHTML = `
        ${rowsHtml([
            ['Fare', window.fmt.money(result.fare)],
            ['Tip', window.fmt.money(result.tip)],
            ['Rating', window.fmt.stars(result.rating)],
            ['Reputation', `+${result.reputation || 0}`],
        ])}
        <div class="r total"><span>Paid</span><span>${window.fmt.money((result.fare || 0) + (result.tip || 0))}</span></div>`;

    summary.classList.remove('hidden');
    setTimeout(() => { if (!shiftSummaryOpen) summary.classList.add('hidden'); }, 6000);
}

window.showShiftSummary = (shift) => {
    const rows = [
        ['Fares', shift.fares || 0],
        ['Time on shift', `${shift.minutes || 0} min`],
        ['Driven', window.fmt.distance(shift.distance || 0)],
    ];

    if (!shift.personal) rows.push(['Deposit back', window.fmt.money(shift.refund || 0)]);
    if (shift.damageFee) rows.push(['Damage', `-${window.fmt.money(shift.damageFee)}`]);
    if (shift.abandoned) rows.push(['Abandoned a fare', 'yes']);

    summary.classList.remove('dock');
    summary.classList.add('full');
    document.querySelector('#summary h2').textContent = 'Shift over';
    document.getElementById('summary-rows').innerHTML = `
        ${rowsHtml(rows)}
        <div class="r total"><span>Earned</span><span>${window.fmt.money(shift.earned || 0)}</span></div>`;

    summary.classList.remove('hidden');
    shiftSummaryOpen = true;
    window.post('summaryShown');
};

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'open':
            if (message.state && message.state.keys) window.keys = message.state.keys;
            window.Tablet.show(message.state || {});
            break;
        case 'close':
            if (window.Tablet.isOpen()) window.Tablet.hide(true);
            break;
        case 'state':
            window.Tablet.setState(message.state);
            break;
        case 'meter':
            window.Meter.update(message.data);
            window.Tablet.meter(message.data);
            break;
        case 'fareComplete':
            showFareReceipt(message.data || {});
            window.Meter.clearRoute();
            window.Tablet.fareComplete(message.data);
            break;
        case 'rideOffer':
            window.Meter.addHail(message.data);
            window.Tablet.rideOffer(message.data);
            break;
        case 'rideGone':
            window.Meter.removeHail(message.data && message.data.id);
            window.Tablet.rideGone(message.data && message.data.id);
            break;
        case 'lamp':
            window.Tablet.lamp(message.data && message.data.on);
            break;
        case 'locations':
            window.Tablet.locations(message.data);
            break;
        case 'builder':
            window.Tablet.builder(message.data);
            break;
        case 'me':
            window.Tablet.me(message.data);
            break;
        default:
            break;
    }
});
