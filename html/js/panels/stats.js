window.Panels.stats = {
    render(state) {
        const stats = state.stats || {};
        const recent = state.recent || [];

        return `
            <div class="grid tiles" style="margin-bottom:16px">
                <div class="tile amber"><div class="v">${window.fmt.money(stats.totalEarned || 0)}</div><div class="l">Lifetime earnings</div></div>
                <div class="tile"><div class="v">${stats.totalFares || 0}</div><div class="l">Fares</div></div>
                <div class="tile"><div class="v">${window.fmt.distance(stats.totalDistance || 0)}</div><div class="l">Distance</div></div>
                <div class="tile"><div class="v">${(Number(stats.rating) || 5).toFixed(2)}</div><div class="l">Average rating</div></div>
            </div>

            <div class="card">
                <h3>Recent fares</h3>
                <div class="sub">Your last ${recent.length} trips.</div>
                ${recent.length ? `
                    <table>
                        <thead>
                            <tr><th>Route</th><th>Distance</th><th>Rating</th><th style="text-align:right">Paid</th></tr>
                        </thead>
                        <tbody>
                            ${recent.map((fare) => `
                                <tr>
                                    <td>
                                        ${window.fmt.escape(fare.pickup_label)} &rarr; ${window.fmt.escape(fare.dropoff_label)}
                                        ${fare.kind === 'player' ? '<span class="pill amber" style="margin-left:6px">hailed</span>' : ''}
                                    </td>
                                    <td style="color:var(--muted)">${window.fmt.distance(fare.distance)}</td>
                                    <td style="color:var(--amber)">${window.fmt.stars(fare.rating)}</td>
                                    <td style="text-align:right">${window.fmt.money((fare.fare || 0) + (fare.tip || 0))}</td>
                                </tr>`).join('')}
                        </tbody>
                    </table>` : '<div class="empty">No fares yet. Sign on and find one.</div>'}
            </div>`;
    },
};
