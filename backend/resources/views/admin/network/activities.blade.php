@extends('admin.layouts.app')

@php
    $title = 'Aktivitas Lapangan';
    $heading = 'Aktivitas Lapangan';
    $subheading = 'Laporan per karyawan per tanggal. Buka detail untuk urutan kegiatan dan peta kunjungan.';
@endphp

@section('content')
    <div class="grid cols-3" style="margin-bottom:18px;">
        <div class="card-kpi">
            <div class="label">Total Aktivitas</div>
            <div class="value">{{ $summary['total'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Tambah UKM/Mitra</div>
            <div class="value">{{ $summary['created'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Terima DST / Kirim Pesanan</div>
            <div class="value">{{ $summary['shipping'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Kunjungan</div>
            <div class="value">{{ $summary['visits'] }}</div>
        </div>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <x-admin.filter-panel>
<form method="GET" class="filters">
                <input name="search" placeholder="Cari karyawan / UKM / HUB / nomor DST atau pesanan" value="{{ $filters['search'] ?? '' }}">
                <select name="owner_role">
                    <option value="">Semua role lapangan</option>
                    @foreach($ownerRoles as $role => $label)
                        <option value="{{ $role }}" @selected(($filters['owner_role'] ?? '') === $role)>{{ $label }}</option>
                    @endforeach
                </select>
                <input name="date_from" type="date" value="{{ $filters['date_from'] ?? '' }}">
                <input name="date_until" type="date" value="{{ $filters['date_until'] ?? '' }}">
                <button class="btn secondary" type="submit">Filter</button>
            </form>
</x-admin.filter-panel>
            <div class="actions">
                <a href="{{ route('admin.network.index') }}" class="btn secondary">Monitoring Jaringan</a>
            </div>
        </div>

        <p class="muted">Total waktu kerja menghitung durasi kunjungan dan perjalanan pengiriman tercatat; interval tumpang tindih dihitung sekali. Durasi tanpa jam mulai/selesai dijumlahkan terpisah. Aktivitas tanpa durasi tidak dihitung. Pencarian menampilkan hari yang cocok beserta seluruh aktivitas hari itu.</p>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Nama</th><th>Tanggal</th><th>Aktivitas</th><th>Profil</th><th>Lokasi</th><th>Total waktu kerja</th><th>Detail</th></tr></thead>
                <tbody>
                @forelse($days as $day)
                    <tr>
                        <td><strong>{{ $day['actor_name'] }}</strong><div class="muted">{{ $day['actor_role'] }}</div></td>
                        <td>{{ \Illuminate\Support\Carbon::parse($day['date'])->format('d M Y') }}</td>
                        <td>@foreach($day['activities'] as $label => $count)<div>{{ $label }}: {{ $count }}</div>@endforeach</td>
                        <td>@foreach($day['profiles']->take(3) as $profile)<div>{{ $profile }}</div>@endforeach
                            @if($day['profiles']->count() > 3)<span class="muted">+{{ $day['profiles']->count() - 3 }} profil lainnya</span>@endif</td>
                        <td>@foreach($day['locations']->take(2) as $location)<div>{{ $location }}</div>@endforeach
                            <span class="muted">{{ $day['located'] }} dari {{ $day['count'] }} aktivitas memiliki koordinat</span></td>
                        <td><strong>{{ $day['duration_label'] ?? 'Belum tercatat' }}</strong><div class="muted">Durasi kunjungan & perjalanan</div></td>
                        <td><a class="btn secondary" href="{{ route('admin.network.activities.show', ['employee' => $day['actor_id'], 'date' => $day['date']]) }}">Detail</a></td>
                    </tr>
                @empty
                    <tr><td colspan="7" class="muted">Belum ada aktivitas lapangan sesuai filter.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
        <div class="pagination">{{ $days->links() }}</div>
    </div>
@endsection