window.Meter = (() => {
    const root = document.getElementById('meter');
    const title = document.getElementById('meter-title');
    const vehicle = document.getElementById('meter-vehicle');
    const amount = document.getElementById('meter-amount');
    const distance = document.getElementById('meter-distance');
    const time = document.getElementById('meter-time');
    const rating = document.getElementById('meter-rating');
    const route = document.getElementById('meter-route');
    const totals = document.getElementById('meter-totals');
    const hails = document.getElementById('hails');

    const STAGE_TEXT = {
        toPickup: 'Heading to pickup',
        boarding: 'Passenger boarding',
        riding: 'Meter running',
    };

    function update(data) {
        if (!data || !data.onDuty) {
            root.classList.add('hidden');
            return;
        }

        root.classList.remove('hidden');
        root.classList.toggle('live', Boolean(data.running));
        root.classList.toggle('idle', !data.running);

        title.textContent = data.hasFare
            ? (STAGE_TEXT[data.stage] || 'On a fare')
            : 'Waiting for a fare';
        vehicle.textContent = data.vehicle || '';

        amount.textContent = window.fmt.money(data.amount || 0);
        distance.textContent = window.fmt.distance(data.distance || 0);
        time.textContent = window.fmt.duration(data.elapsed || 0);
        rating.textContent = (Number(data.rating) || 5).toFixed(1);

        if (data.hasFare && data.openEnded && data.stage === 'riding') {
            route.innerHTML = 'Hailed ride &mdash; end it where they ask.<br><span style="color:var(--amber)">/endride</span>';
        } else if (data.hasFare && data.stage === 'riding') {
            route.innerHTML = `To <strong>${window.fmt.escape(data.dropoff || '')}</strong>`;
        } else if (data.hasFare) {
            route.innerHTML = `Pickup at <strong>${window.fmt.escape(data.pickup || '')}</strong>`;
        } else {
            route.innerHTML = 'Open the terminal or drive to find work.';
        }

        const t = data.totals || {};
        totals.textContent = `Shift: ${t.fares || 0} fares - ${window.fmt.money(t.earned || 0)}`;
    }

    function clearRoute() {
        route.textContent = 'Fare complete.';
    }

    function addHail(offer) {
        if (!offer || document.getElementById(`hail-${offer.id}`)) return;

        const node = document.createElement('div');
        node.className = 'hail';
        node.id = `hail-${offer.id}`;
        node.innerHTML = `
            <div class="who">${window.fmt.escape(offer.passenger || 'Someone')}</div>
            <div class="meta">${window.fmt.distance(offer.distance || 0)} away &middot; ${window.fmt.escape(offer.label || 'Street pickup')}</div>
            <div class="hint">/accepthail ${offer.id}</div>`;

        node.addEventListener('click', async () => {
            const result = await window.post('acceptHail', { id: offer.id });
            if (result && result.ok) removeHail(offer.id);
        });

        hails.appendChild(node);
    }

    function removeHail(id) {
        const node = document.getElementById(`hail-${id}`);
        if (node) node.remove();
    }

    return { update, clearRoute, addHail, removeHail };
})();
