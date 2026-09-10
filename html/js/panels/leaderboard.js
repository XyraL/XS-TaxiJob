window.Panels.leaderboard = {
    render(state) {
        const rows = state.leaderboard || [];

        return `
            <div class="card">
                <h3>Company board</h3>
                <div class="sub">Ranked on reputation, then on takings.</div>
                ${rows.length ? `
                    <table>
                        <thead>
                            <tr><th style="width:44px">#</th><th>Driver</th><th>Tier</th><th>Fares</th><th>Rating</th><th style="text-align:right">Earned</th></tr>
                        </thead>
                        <tbody>
                            ${rows.map((row) => `
                                <tr>
                                    <td style="color:${row.rank <= 3 ? 'var(--amber)' : 'var(--faint)'};font-weight:600">${row.rank}</td>
                                    <td>${window.fmt.escape(row.name)}</td>
                                    <td><span class="pill">${window.fmt.escape(row.tierLabel)}</span></td>
                                    <td style="color:var(--muted)">${row.fares}</td>
                                    <td style="color:var(--amber)">${window.fmt.stars(row.rating)}</td>
                                    <td style="text-align:right">${window.fmt.money(row.earned)}</td>
                                </tr>`).join('')}
                        </tbody>
                    </table>` : '<div class="empty">Nobody has driven a fare yet.</div>'}
            </div>`;
    },
};
