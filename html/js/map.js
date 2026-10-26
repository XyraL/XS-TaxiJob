window.TaxiMap = (() => {
    const MAP = {
        imageW: 4096,
        imageH: 6144,
        tile: 512,
        native: 4,
        world: { minX: -4140, maxX: 4860, minY: -5100, maxY: 8400 },
    };
    const W = MAP.world;

    const GLYPH = {
        call: '<svg viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM5 21a7 7 0 0 1 14 0"/></svg>',
        pick: '<svg viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM5 21a7 7 0 0 1 14 0"/></svg>',
        drop: '<svg viewBox="0 0 24 24"><path d="M5 21V4h11l-2 4 2 4H5"/></svg>',
        depot: '<svg viewBox="0 0 24 24"><path d="M3 21h18M5 21V8l7-5 7 5v13M9 21v-6h6v6"/></svg>',
    };

    function create(el) {
        const map = L.map(el, {
            crs: L.CRS.Simple,
            minZoom: 1,
            maxZoom: 6,
            zoomControl: false,
            attributionControl: false,
            zoomSnap: 0.25,
            wheelPxPerZoomLevel: 90,
        });

        const ll = (x, y) => map.unproject([
            ((x - W.minX) / (W.maxX - W.minX)) * MAP.imageW,
            ((W.maxY - y) / (W.maxY - W.minY)) * MAP.imageH,
        ], MAP.native);

        const sw = map.unproject([0, MAP.imageH], MAP.native);
        const ne = map.unproject([MAP.imageW, 0], MAP.native);
        const bounds = L.latLngBounds(sw, ne);

        L.tileLayer('assets/maps/tiles/{z}_{x}_{y}.webp', {
            tileSize: MAP.tile,
            minZoom: 0,
            maxZoom: 6,
            maxNativeZoom: MAP.native,
            noWrap: true,
            bounds,
        }).addTo(map);

        map.setMaxBounds(bounds.pad(0.1));
        map.setView(ll(200, -900), 3);

        const layer = L.layerGroup().addTo(map);
        let me = null;

        function pin(x, y, kind, opts = {}) {
            const html = kind === 'bay'
                ? `<div class="tx-pin p-bay"><span>${opts.text || ''}</span></div>`
                : `<div class="tx-pin p-${kind}">${GLYPH[kind] || GLYPH.pick}</div>`;
            const size = kind === 'bay' ? 20 : 26;
            const marker = L.marker(ll(x, y), {
                icon: L.divIcon({ className: '', html, iconSize: [size, size], iconAnchor: [size / 2, size + 4] }),
                interactive: !!opts.onClick,
                zIndexOffset: opts.z || 0,
            }).addTo(layer);
            if (opts.title) marker.bindTooltip(opts.title, { direction: 'top', offset: [0, -size] });
            if (opts.onClick) marker.on('click', opts.onClick);
            return marker;
        }

        function setMe(x, y) {
            if (typeof x !== 'number' || typeof y !== 'number') return;
            if (!me) {
                me = L.marker(ll(x, y), {
                    icon: L.divIcon({ className: '', html: '<div class="tx-me"></div>', iconSize: [16, 16], iconAnchor: [8, 8] }),
                    interactive: false,
                    zIndexOffset: 1000,
                }).addTo(map);
            } else {
                me.setLatLng(ll(x, y));
            }
        }

        function fit(points, zoom) {
            const usable = points.filter((p) => p && typeof p.x === 'number' && typeof p.y === 'number');
            if (usable.length === 0) return;
            if (usable.length === 1) {
                map.setView(ll(usable[0].x, usable[0].y), zoom || 4, { animate: false });
                return;
            }
            map.fitBounds(L.latLngBounds(usable.map((p) => ll(p.x, p.y))).pad(0.3), { animate: false, maxZoom: Math.min(zoom || 4, MAP.native) });
        }

        function clear() { layer.clearLayers(); }

        let removed = false;

        function destroy() {
            removed = true;
            map.remove();
        }

        setTimeout(() => { if (!removed) map.invalidateSize(); }, 0);

        return { map, pin, setMe, fit, clear, destroy };
    }

    return { create, MAP };
})();
