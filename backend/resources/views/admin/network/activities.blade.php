@extends('admin.layouts.app')

@php
    $title = 'Aktivitas Lapangan';
    $heading = 'Aktivitas Lapangan';
    $subheading = 'HR melihat timeline aktivitas FGG dan Area Manager: tambah UKM/Mitra, kunjungan, durasi, foto, dan lokasi.';
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
            <div class="label">Kunjungan</div>
            <div class="value">{{ $summary['visits'] }}</div>
        </div>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input name="search" placeholder="Cari FGG / Area Manager / nama UKM / alamat" value="{{ $filters['search'] ?? '' }}">
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
            <div class="actions">
                <a href="{{ route('admin.network.index') }}" class="btn secondary">Monitoring Jaringan</a>
            </div>
        </div>

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Waktu</th>
                    <th>Owner</th>
                    <th>Aktivitas</th>
                    <th>Profil</th>
                    <th>Lokasi</th>
                    <th>Detail</th>
                    <th>Foto</th>
                </tr>
                </thead>
                <tbody>
                @forelse($activities as $activity)
                    @php($hasCoordinates = $activity['latitude'] !== null && $activity['longitude'] !== null)
                    @php($mapsUrl = $hasCoordinates ? 'https://www.google.com/maps?q=' . $activity['latitude'] . ',' . $activity['longitude'] : null)
                    @php($photoUrl = is_array($activity['photo'] ?? null) ? ($activity['photo']['url'] ?? null) : null)
                    <tr>
                        <td>{{ optional($activity['occurred_at'])->format('d M Y H:i') }}</td>
                        <td>
                            <div class="stack">
                                <strong>{{ $activity['actor_name'] ?: '-' }}</strong>
                                <span class="muted">{{ $activity['actor_role'] }}</span>
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <span>{{ $activity['activity_label'] }}</span>
                                @if($activity['duration_label'])
                                    <span class="pill">Durasi {{ $activity['duration_label'] }}</span>
                                @endif
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <strong>{{ $activity['profile_name'] }}</strong>
                                <span class="muted">{{ $activity['profile_type'] }}</span>
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <span>{{ $activity['address'] ?: '-' }}</span>
                                @if($mapsUrl)
                                    <a class="muted" href="{{ $mapsUrl }}" target="_blank" rel="noreferrer">Buka di Google Maps</a>
                                @endif
                            </div>
                        </td>
                        <td class="muted" style="max-width:340px;">{{ $activity['detail'] ?: '-' }}</td>
                        <td>
                            @if($photoUrl)
                                <a class="attachment-link" href="{{ $photoUrl }}" target="_blank" rel="noreferrer">Buka foto</a>
                            @else
                                <span class="muted">-</span>
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="7" class="muted">Belum ada aktivitas lapangan sesuai filter.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $activities->links() }}</div>
    </div>
@endsection
