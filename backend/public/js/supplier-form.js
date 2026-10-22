(() => {
    'use strict';
    const form = document.getElementById('supplier-form');
    if (!form) return;
    const fields = ['province', 'city', 'district'].map(level => document.getElementById('territory_' + level));
    const regionStatus = document.getElementById('supplier-region-status');
    const retry = document.getElementById('supplier-region-retry');
    let generation = 0;
    const reset = index => fields.slice(index).forEach(field => field.replaceChildren(new Option('Pilih wilayah', '')));
    async function load(index, initial = false) {
        const current = ++generation;
        reset(index);
        retry.hidden = true;
        regionStatus.textContent = 'Memuat wilayah…';
        try {
            for (let i = index; i < fields.length; i++) {
                const parent = i ? fields[i - 1].selectedOptions[0]?.dataset.code : null;
                if (i && !parent) break;
                const url = new URL('/api/territories/' + ['provinces', 'cities', 'districts'][i], location.origin);
                if (parent) url.searchParams.set(['', 'province_code', 'city_code'][i], parent);
                const response = await fetch(url, { headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(30000) });
                if (!response.ok) throw new Error('regions');
                const result = await response.json();
                if (current !== generation) return;
                if (!Array.isArray(result.data) || !result.data.length) throw new Error('empty');
                fields[i].replaceChildren(new Option('Pilih wilayah', ''));
                for (const row of result.data) {
                    const option = new Option(row.name, row.name);
                    option.dataset.code = row.code;
                    fields[i].append(option);
                }
                if (initial) fields[i].value = fields[i].dataset.old || '';
                if (!initial || !fields[i].value) break;
            }
            regionStatus.textContent = '';
        } catch (_) {
            if (current !== generation) return;
            regionStatus.textContent = 'Wilayah belum dapat dimuat. Periksa koneksi dan coba lagi.';
            retry.hidden = false;
        }
    }
    fields[0].addEventListener('change', () => load(1));
    fields[1].addEventListener('change', () => load(2));
    retry.addEventListener('click', () => load(0, true));
    load(0, true);

    const items = document.getElementById('supplier-items');
    const add = document.getElementById('supplier-add-item');
    const updateItems = () => {
        add.disabled = items.children.length >= 50;
        items.querySelectorAll('button').forEach(button => button.disabled = items.children.length <= 1);
    };
    add.addEventListener('click', () => {
        if (items.children.length >= 50) return;
        const row = items.firstElementChild.cloneNode(true);
        row.querySelector('input').value = '';
        items.append(row);
        updateItems();
        row.querySelector('input').focus();
    });
    items.addEventListener('click', event => {
        if (event.target.closest('.remove-item') && items.children.length > 1) {
            event.target.closest('.remove-item').parentElement.remove();
            updateItems();
        }
    });
    updateItems();
    form.addEventListener('submit', () => { document.getElementById('supplier-submit').disabled = true; });

    const status = document.getElementById('supplier-location-status');
    const lat = document.getElementById('latitude'), lng = document.getElementById('longitude');
    const source = document.getElementById('location_source');
    const panel = document.getElementById('location-panel');
    let map, marker;
    function choose(latitude, longitude, kind) {
        lat.value = latitude.toFixed(7); lng.value = longitude.toFixed(7); source.value = kind;
        status.textContent = 'Titik supplier: ' + lat.value + ', ' + lng.value + '. Pastikan titik sesuai lokasi supplier.';
        if (map) {
            if (marker) marker.setLatLng([latitude, longitude]);
            else marker = L.marker([latitude, longitude]).addTo(map);
        }
    }
    function initMap() {
        if (!panel.open) return;
        if (!window.L) { status.textContent = 'Peta belum tersedia. Lokasi GPS tetap dapat dipakai.'; return; }
        if (!map) {
            map = L.map('supplier-location-map').setView([-2.5, 118], 5);
            L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19, referrerPolicy: 'strict-origin-when-cross-origin',
                attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            }).addTo(map).on('tileerror', () => { status.textContent = 'Latar peta gagal dimuat. Gunakan GPS atau isi alamat manual.'; });
            map.on('click', event => choose(event.latlng.lat, event.latlng.lng, 'map'));
            if (lat.value !== '' && lng.value !== '') {
                choose(Number(lat.value), Number(lng.value), source.value);
                map.setView([Number(lat.value), Number(lng.value)], 16);
            }
        }
        requestAnimationFrame(() => map.invalidateSize());
    }
    panel.addEventListener('toggle', initMap);
    initMap();
    document.getElementById('supplier-gps').addEventListener('click', event => {
        if (!navigator.geolocation) { status.textContent = 'GPS tidak tersedia di browser ini. Pilih titik di peta atau isi alamat manual.'; return; }
        const button = event.currentTarget;
        button.disabled = true; status.textContent = 'Membaca lokasi perangkat…';
        navigator.geolocation.getCurrentPosition(position => {
            button.disabled = false;
            choose(position.coords.latitude, position.coords.longitude, 'gps');
            if (map) map.setView([position.coords.latitude, position.coords.longitude], 16);
        }, () => {
            button.disabled = false;
            status.textContent = 'Lokasi belum terbaca. Izinkan akses lokasi atau pilih titik di peta / isi alamat manual.';
        }, { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
    });
    document.getElementById('supplier-clear-location').addEventListener('click', () => {
        lat.value = ''; lng.value = ''; source.value = 'manual';
        if (marker) { marker.remove(); marker = null; }
        status.textContent = 'Alamat manual tanpa titik peta.';
    });
})();
