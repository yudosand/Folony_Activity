(() => {
    'use strict';
    const element = document.getElementById('field-route-map');
    if (!element) return;
    const status = document.getElementById('field-route-status');
    if (!window.L) { status.textContent = 'Peta gagal dimuat. Daftar aktivitas tetap tersedia.'; return; }
    const map = L.map(element, { scrollWheelZoom: false }).setView([-2.5, 118], 5);
    const streets = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        // OSM requires a Referer. Override the host's same-origin policy for tiles only;
        // send the actual site origin, never the employee/date URL.
        referrerPolicy: 'strict-origin-when-cross-origin',
        maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(map);
    const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19, attribution: 'Tiles &copy; Esri, Maxar, Earthstar Geographics, GIS User Community'
    });
    const labels = L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19, maxNativeZoom: 18, attribution: 'Labels &copy; Esri'
    });
    L.control.layers({ 'Peta jalan': streets, 'Satelit': L.layerGroup([satellite, labels]) }).addTo(map);
    L.control.scale({ imperial: false }).addTo(map);
    for (const layer of [streets, satellite]) layer.on('tileerror', () => { status.textContent = 'Latar peta belum dapat dimuat. Coba pilihan peta lain atau muat ulang; daftar aktivitas tetap tersedia.'; });
    const bounds = L.latLngBounds();
    let segment = [];
    let previous = null;
    const draw = () => { if (segment.length > 1) L.polyline(segment, { color: '#078a69', weight: 3, dashArray: '7 6' }).addTo(map); segment = []; };
    for (const card of document.querySelectorAll('.field-event')) {
        const { latitude, longitude, number, title, time } = card.dataset;
        if (!latitude || !longitude) { draw(); previous = null; continue; }
        const point = L.latLng(Number(latitude), Number(longitude));
        if (!Number.isFinite(point.lat) || !Number.isFinite(point.lng) || Math.abs(point.lat) > 90 || Math.abs(point.lng) > 180) { draw(); previous = null; continue; }
        bounds.extend(point);
        segment.push(point);
        const popup = document.createElement('div');
        popup.textContent = `${number}. ${title} · ${time}`;
        const marker = L.marker(point, { icon: L.divIcon({ className: 'field-route-number', html: String(Number(number)), iconSize: [32, 32], iconAnchor: [16, 16] }) }).addTo(map).bindPopup(popup);
        marker.on('click', () => card.scrollIntoView({ behavior: 'smooth', block: 'nearest' }));
        card.querySelector('.field-locate')?.addEventListener('click', () => { map.setView(point, 17); marker.openPopup(); });
        if (previous) {
            const meters = previous.point.distanceTo(point);
            const distance = meters >= 1000 ? `${(meters / 1000).toLocaleString('id-ID', { maximumFractionDigits: 2 })} km` : `${Math.round(meters)} m`;
            previous.card.querySelector('.field-distance').textContent = `Jarak lurus ke aktivitas berikutnya: ${distance}`;
        }
        previous = { point, card };
    }
    draw();
    const fit = () => { if (bounds.isValid()) map.fitBounds(bounds, { padding: [35, 35], maxZoom: 16 }); };
    document.getElementById('field-route-fit').addEventListener('click', fit);
    fit();
})();
