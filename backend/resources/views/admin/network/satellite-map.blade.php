<link rel="stylesheet" href="{{ asset('vendor/leaflet/leaflet.css') }}">
<link rel="stylesheet" href="{{ asset('vendor/leaflet/MarkerCluster.css') }}">
<link rel="stylesheet" href="{{ asset('vendor/leaflet/MarkerCluster.Default.css') }}">
<style>
    #network-satellite-map { height:480px; min-height:320px; border-radius:16px; background:#e4e9e7; z-index:0; }
    #network-map-panel { margin-bottom:24px; }
    #network-map-panel:fullscreen { background:white; padding:24px; overflow:auto; }
    #network-map-panel:fullscreen #network-satellite-map { height:calc(100vh - 200px); }
    .network-map-dot { border:2px solid white; border-radius:50%; box-shadow:0 2px 8px #0008; }
    .network-map-ukm { background:#00897b; } .network-map-mitra { background:#ef8b1e; }
    .network-map-popup p { margin:6px 0; overflow-wrap:anywhere; }
    .network-map-popup a { color:#00796b; text-decoration:underline; }
</style>
<section id="network-map-panel" aria-label="Peta jaringan">
    <div class="toolbar">
        <div><h3 style="margin:0">Peta Jaringan</h3><p class="muted" style="margin:6px 0">Semua titik sesuai filter di atas. Klik kelompok untuk memperbesar, lalu klik titik untuk melihat detail.</p></div>
        <div class="actions">
            <button id="network-map-fit" type="button" class="btn secondary">Lihat semua titik</button>
            <button id="network-map-fullscreen" type="button" class="btn secondary">Layar penuh</button>
            <button id="network-map-retry" type="button" class="btn secondary" hidden>Coba lagi</button>
        </div>
    </div>
    <div id="network-map-status" role="status" aria-live="polite" class="muted" style="margin-bottom:10px">Memuat titik jaringan…</div>
    <div id="network-satellite-map" data-points-url="{{ route('admin.network.map-points', $filters) }}"></div>
    <p class="muted" style="margin:8px 0"><span style="color:#00897b">● UKM</span> · <span style="color:#ef8b1e">● Mitra</span> · Citra satelit bukan tampilan langsung. Data tanpa koordinat tetap tersedia di tabel.</p>
    <p id="network-map-tile-error" role="status" hidden>Latar peta belum dapat dimuat. Titik tetap tersedia; coba pilihan peta lain atau muat ulang halaman.</p>
</section>
<script src="{{ asset('vendor/leaflet/leaflet.js') }}"></script>
<script src="{{ asset('vendor/leaflet/leaflet.markercluster.js') }}"></script>
<script src="{{ asset('js/network-satellite-map.js') }}?v=20260916-referrer-fix" defer></script>
