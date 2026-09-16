@extends('admin.layouts.app')
@php
    $title = 'Detail Aktivitas Lapangan';
    $heading = 'Aktivitas Lapangan — '.$day['actor_name'];
    $subheading = \Illuminate\Support\Carbon::parse($day['date'])->format('d M Y').' · '.$day['actor_role'].' · '.config('app.timezone');
@endphp
@section('content')
<link rel="stylesheet" href="{{ asset('vendor/leaflet/leaflet.css') }}">
<style>
    .field-route-grid { display:grid; grid-template-columns:minmax(0,1.2fr) minmax(0,1fr); gap:20px; }
    #field-route-map { height:580px; border-radius:14px; z-index:0; background:#e4e9e7; }
    .field-event-list { max-height:580px; overflow:auto; }
    .field-event { border:1px solid #ddd; border-radius:12px; padding:16px; margin-bottom:12px; scroll-margin:10px; }
    .field-event p { margin:8px 0; overflow-wrap:anywhere; }
    .field-route-number { background:#078a69; color:white; border:2px solid white; border-radius:50%; font-weight:bold; text-align:center; line-height:28px; box-shadow:0 2px 6px #0006; }
    @media(max-width:900px) { .field-route-grid { grid-template-columns:1fr; } #field-route-map { height:380px; } .field-event-list { max-height:none; } }
</style>
<div class="toolbar"><a class="btn secondary" href="{{ route('admin.network.activities', ['date_from' => $day['date'], 'date_until' => $day['date']]) }}">Kembali ke laporan harian</a></div>
<div class="grid cols-3" style="margin-bottom:18px">
    <div class="card-kpi"><div class="label">Aktivitas</div><div class="value">{{ $day['count'] }}</div></div>
    <div class="card-kpi"><div class="label">Total waktu kerja tercatat</div><div class="value">{{ $day['duration_label'] ?? 'Belum tercatat' }}</div></div>
    <div class="card-kpi"><div class="label">Aktivitas dengan koordinat</div><div class="value">{{ $day['located'] }} / {{ $day['count'] }}</div></div>
</div>
<div class="panel pad">
    <h3>Rute aktivitas harian</h3>
    <p class="muted">Urutan berdasarkan jam mulai kunjungan atau waktu pencatatan aktivitas. Garis menghubungkan titik secara lurus, bukan jalur jalan atau rekaman GPS perjalanan. Aktivitas tanpa koordinat tetap ada di daftar dan memutus garis rute.</p>
    <p class="muted">Total waktu memakai interval kunjungan dan perjalanan tercatat tanpa menghitung tumpang tindih dua kali. Durasi tanpa jam mulai/selesai dijumlahkan terpisah. Kunjungan lintas tengah malam masuk pada tanggal pencatatannya. Terima DST dan tambah profil tidak memiliki durasi kerja. Durasi kirim pesanan dihitung dari mulai perjalanan sampai tiba di tujuan.</p>
    <p id="field-route-status" class="muted" role="status">{{ $day['located'] }} titik tersedia. {{ $day['count'] - $day['located'] }} aktivitas tanpa koordinat.</p>
    <div class="field-route-grid">
        <div><div id="field-route-map" aria-label="Peta urutan aktivitas harian"></div><button type="button" id="field-route-fit" class="btn secondary" style="margin-top:10px">Lihat semua titik</button></div>
        <div class="field-event-list">
        @foreach($events as $event)
            @php($number = $loop->iteration)
            @php($hasCoordinates = $event['latitude'] !== null && $event['longitude'] !== null)
            @php($photoUrl = is_array($event['photo']) ? ($event['photo']['url'] ?? null) : null)
            <article class="field-event" id="field-event-{{ $number }}" data-number="{{ $number }}" data-latitude="{{ $event['latitude'] }}" data-longitude="{{ $event['longitude'] }}" data-title="{{ $event['profile_name'] }}" data-time="{{ $event['occurred_at']->format('d M Y H:i:s') }}">
                <strong>{{ $number }}. {{ $event['profile_name'] }}</strong>
                <p>{{ $event['activity_label'] }} · {{ $event['profile_type'] }}</p>
                <p class="muted">Dicatat {{ $event['occurred_at']->format('d M Y H:i:s') }}</p>
                @if($event['source'] === 'visits' || $event['started_at'])
                    @if($event['source'] === 'shipping')<strong>Perjalanan pengiriman</strong>@endif
                    <p>Mulai: {{ $event['started_at']?->format('d M Y H:i:s') ?? 'Belum tercatat' }}<br>Selesai: {{ $event['finished_at']?->format('d M Y H:i:s') ?? 'Belum tercatat' }}<br>Durasi {{ $event['duration_label'] ?? 'belum tercatat' }}</p>
                @endif
                <p>{{ $event['detail'] }}@if($event['note'])<br>{{ $event['note'] }}@endif</p>
                <p>{{ $event['address'] ?: 'Alamat belum tercatat' }}</p>
                @if($hasCoordinates)
                    <p class="muted">{{ $event['location_source'] }} · {{ $event['latitude'] }}, {{ $event['longitude'] }}
                    @if($event['accuracy_meters'] !== null)<br>Akurasi ±{{ $event['accuracy_meters'] }} m @endif
                    @if($event['captured_at'])<br>GPS direkam {{ $event['captured_at']->format('d M Y H:i:s') }}@endif</p>
                    <div class="actions"><button type="button" class="btn secondary field-locate">Lihat titik</button><a href="https://www.google.com/maps?q={{ $event['latitude'] }},{{ $event['longitude'] }}" target="_blank" rel="noreferrer">Buka di Google Maps</a></div>
                @else
                    <p class="muted">Koordinat tidak tersedia</p>
                @endif
                <p class="field-distance muted"></p>
                @if($photoUrl && preg_match('~^(https?://|/)~i', $photoUrl))
                    <a href="{{ $photoUrl }}" target="_blank" rel="noreferrer"><img src="{{ $photoUrl }}" alt="{{ $event['source'] === 'shipping' ? 'Foto bukti pengiriman' : 'Foto aktivitas '.$number }}" loading="lazy" style="width:100px;height:100px;object-fit:cover;border-radius:8px"><br>{{ $event['source'] === 'shipping' ? 'Buka foto bukti pengiriman' : 'Buka foto' }}</a>
                @elseif($event['activity_label'] === 'Kirim Pesanan')
                    <p class="muted">Foto bukti belum tersedia.</p>
                @endif
            </article>
        @endforeach
        </div>
    </div>
</div>
<script src="{{ asset('vendor/leaflet/leaflet.js') }}"></script>
<script src="{{ asset('js/field-activity-route.js') }}?v=20260916-referrer-fix" defer></script>
@endsection
