(() => {
    'use strict';
    const element = document.getElementById('network-satellite-map');
    if (!element) return;
    const status = document.getElementById('network-map-status');
    const retry = document.getElementById('network-map-retry');
    if (!window.L || !L.markerClusterGroup) {
        status.textContent = 'Peta belum dapat dibuka. Muat ulang halaman untuk mencoba lagi.';
        return;
    }
    const map = L.map(element, { scrollWheelZoom: false }).setView([-2.5, 118], 5);
    const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19, attribution: 'Tiles &copy; Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community'
    });
    const streets = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        // OSM requires a Referer. Send only the actual site origin across domains.
        referrerPolicy: 'strict-origin-when-cross-origin',
        maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map);
    const labels = L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19, maxNativeZoom: 18, zIndex: 350, attribution: 'Labels & boundaries &copy; Esri'
    });
    L.control.layers({ 'Peta jalan': streets, 'Satelit': L.layerGroup([satellite, labels]) }).addTo(map);
    L.control.scale({ imperial: false }).addTo(map);
    streets.on('tileerror', () => { document.getElementById('network-map-tile-error').hidden = false; });
    satellite.on('tileerror', () => { document.getElementById('network-map-tile-error').hidden = false; });
    const cluster = L.markerClusterGroup({ chunkedLoading: true, showCoverageOnHover: false, maxClusterRadius: 45 }).addTo(map);
    let bounds = L.latLngBounds();
    let busy = false;
    const fit = () => { if (bounds.isValid()) map.fitBounds(bounds, { padding: [35, 35], maxZoom: 16 }); };
    document.getElementById('network-map-fit').addEventListener('click', fit);
    const fullscreen = document.getElementById('network-map-fullscreen');
    if (!document.fullscreenEnabled) fullscreen.hidden = true;
    fullscreen.addEventListener('click', async () => {
        try {
            if (document.fullscreenElement) await document.exitFullscreen();
            else await document.getElementById('network-map-panel').requestFullscreen();
        } catch (_) { status.textContent = 'Mode layar penuh belum tersedia di browser ini.'; }
    });
    document.addEventListener('fullscreenchange', () => {
        fullscreen.textContent = document.fullscreenElement ? 'Keluar layar penuh' : 'Layar penuh';
        map.invalidateSize();
    });
    const popup = point => {
        const container = document.createElement('div');
        container.className = 'network-map-popup';
        const name = document.createElement('strong');
        name.textContent = point.name;
        container.append(name);
        for (const text of [point.type.toUpperCase() + ' · ' + point.status, point.owner, point.area, point.address,
            point.latitude.toFixed(6) + ', ' + point.longitude.toFixed(6)]) {
            const line = document.createElement('p');
            line.textContent = text || '—';
            container.append(line);
        }
        const detail = document.createElement('a');
        detail.href = point.detail_url;
        detail.textContent = 'Lihat detail jaringan';
        container.append(detail);
        return container;
    };
    async function load() {
        if (busy) return;
        busy = true;
        retry.hidden = true;
        cluster.clearLayers();
        bounds = L.latLngBounds();
        const seen = new Set();
        let cursor = null;
        try {
            do {
                const url = new URL(element.dataset.pointsUrl, location.href);
                if (cursor) url.searchParams.set('after', cursor);
                const controller = new AbortController();
                const timeout = setTimeout(() => controller.abort(), 30000);
                let response, payload;
                try {
                    response = await fetch(url, { headers: { Accept: 'application/json' }, credentials: 'same-origin', signal: controller.signal });
                    if (!response.ok || response.redirected) throw new Error('session');
                    payload = await response.json();
                } finally { clearTimeout(timeout); }
                const markers = [];
                for (const point of payload.data) {
                    if (seen.has(point.id)) continue;
                    seen.add(point.id);
                    const coordinates = [point.latitude, point.longitude];
                    bounds.extend(coordinates);
                    const marker = L.marker(coordinates, {
                        title: point.name,
                        icon: L.divIcon({ className: 'network-map-dot network-map-' + (point.type === 'mitra' ? 'mitra' : 'ukm'), iconSize: [18, 18] })
                    }).bindPopup(() => popup(point));
                    markers.push(marker);
                }
                cluster.addLayers(markers);
                status.textContent = `${seen.size} dari ${payload.meta.mapped} titik termuat · ${payload.meta.unmapped} data tanpa koordinat valid`;
                if (!cursor && seen.size) fit();
                const next = payload.meta.next_cursor;
                if (next && next === cursor) throw new Error('cursor');
                cursor = next;
                if (!cursor && !seen.size) status.textContent = `Tidak ada titik sesuai filter. ${payload.meta.unmapped} data belum memiliki koordinat valid.`;
            } while (cursor);
            fit();
        } catch (_) {
            status.textContent = `${seen.size} titik termuat. Pengambilan data belum selesai; periksa koneksi atau sesi login, lalu coba lagi.`;
            retry.hidden = false;
        } finally { busy = false; }
    }
    retry.addEventListener('click', load);
    load();
})();
