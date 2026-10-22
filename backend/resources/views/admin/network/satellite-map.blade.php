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
    .business-map-icon { border:2px solid #fff; border-radius:50%; box-shadow:0 2px 6px #0006; display:grid; place-items:center; font-size:19px; line-height:1; width:32px; height:32px; }
    .business-legend { display:flex; flex-wrap:wrap; gap:8px; margin:10px 0; }
    .business-legend a { border:1px solid var(--line); border-radius:20px; padding:9px 12px; font-size:13px; background:#fff; }
    .business-legend a[aria-current="true"] { outline:2px solid var(--primary); }
</style>
<section id="network-map-panel" aria-label="{{ $mapTitle ?? 'Peta jaringan' }}">
    <div class="toolbar">
        <div><h3 style="margin:0">{{ $mapTitle ?? 'Peta Jaringan' }}</h3><p class="muted" style="margin:6px 0">Semua titik sesuai filter di atas. Klik kelompok untuk memperbesar, lalu klik titik untuk melihat detail.</p></div>
        <div class="actions">
            <button id="network-map-fit" type="button" class="btn secondary">Lihat semua titik</button>
            <button id="network-map-fullscreen" type="button" class="btn secondary">Layar penuh</button>
            <button id="network-map-retry" type="button" class="btn secondary" hidden>Coba lagi</button>
        </div>
    </div>
    <div id="network-map-status" role="status" aria-live="polite" class="muted" style="margin-bottom:10px">Memuat titik jaringan…</div>
    @isset($businessOptions)
    <nav class="business-legend" aria-label="Legenda kategori usaha">
        <a href="{{ route('admin.network.index', array_merge($filters, ['business_category_id'=>null,'business_kind_id'=>null])) }}">Semua kategori</a>
        @foreach($businessOptions as $category)<a aria-current="{{ ($filters['business_category_id'] ?? '') === $category['id'] ? 'true' : 'false' }}" href="{{ route('admin.network.index', array_merge($filters, ['business_category_id'=>$category['id'],'business_kind_id'=>null])) }}"><span style="color:{{ $category['color'] }}">●</span> {{ $category['name'] }}</a>@endforeach
        <a href="{{ route('admin.network.index', array_merge($filters,['business_category_id'=>'unclassified','business_kind_id'=>null])) }}"><span style="color:#64748b">●</span> Perlu ditinjau</a>
    </nav>
    <p class="muted">Warna: kategori usaha · Ikon: jenis usaha · Angka kelompok: jumlah lokasi, dapat berisi beberapa kategori.</p>
    @endisset
    <div id="network-satellite-map" data-points-url="{{ $mapPointsUrl ?? route('admin.network.map-points', $filters) }}" data-detail-label="{{ $mapDetailLabel ?? 'Lihat detail jaringan' }}"></div>
    <p class="muted" style="margin:8px 0">@if(isset($mapTitle)) ● Supplier · @endif Data tanpa koordinat tetap tersedia di tabel. Citra satelit bukan tampilan langsung.</p>
    <p id="network-map-tile-error" role="status" hidden>Latar peta belum dapat dimuat. Titik tetap tersedia; coba pilihan peta lain atau muat ulang halaman.</p>
</section>
<script src="{{ asset('vendor/leaflet/leaflet.js') }}"></script>
<script src="{{ asset('vendor/leaflet/leaflet.markercluster.js') }}"></script>
<script src="{{ asset('js/network-satellite-map.js') }}?v=20261022-business" defer></script>
