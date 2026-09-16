@extends('admin.layouts.app')
@php
    $title = $heading = 'Aktifitas Karyawan';
    $subheading = 'Ringkasan pekerjaan per karyawan per tanggal. Buka detail untuk melihat seluruh update dan foto.';
@endphp
@section('content')
    <div class="panel pad">
        <div class="toolbar">
            <x-admin.filter-panel>
<form method="GET" class="filters">
                <input name="search" placeholder="Cari nama / NIK karyawan" value="{{ $filters['search'] ?? '' }}">
                <label>Dari <input type="date" name="from" value="{{ $filters['from'] ?? '' }}"></label>
                <label>Sampai <input type="date" name="to" value="{{ $filters['to'] ?? '' }}"></label>
                <select name="status">
                    <option value="">Semua status</option>
                    <option value="active" @selected(($filters['status'] ?? '') === 'active')>Berjalan</option>
                    <option value="completed" @selected(($filters['status'] ?? '') === 'completed')>Selesai</option>
                </select>
                <button class="btn secondary">Filter</button>
            </form>
</x-admin.filter-panel>
            <a class="btn warn" href="{{ route('admin.employee-activities.index', array_merge(request()->query(), ['export' => 'csv'])) }}">Export CSV</a>
        </div>
        <p class="muted">{{ $days->total() }} ringkasan harian · Zona waktu {{ config('app.timezone') }}.</p>
        <p class="muted">Durasi dijumlahkan dari setiap sesi mulai sampai selesai; jeda antarsesi tidak dihitung. Sesi berjalan dihitung sampai halaman dimuat. Pekerjaan lintas tengah malam masuk tanggal mulai.</p>
        <div class="table-wrap"><table>
            <thead><tr><th>Karyawan</th><th>Tanggal</th><th>Mulai kerja</th><th>Update terakhir</th><th>Selesai</th><th>Total durasi kerja</th><th>Status</th><th>Riwayat</th></tr></thead>
            <tbody>
            @forelse($days as $day)
                <tr>
                    <td><strong>{{ $day->full_name }}</strong><br><span class="muted">{{ $day->employee_code }} · {{ \App\Support\Workflow\UserRole::label($day->role) }}</span></td>
                    <td>{{ \Illuminate\Support\Carbon::parse($day->work_date)->format('d/m/Y') }}</td>
                    <td style="white-space:nowrap">{{ \Illuminate\Support\Carbon::parse($day->started_at)->format('d/m/Y H:i:s') }}</td>
                    <td style="white-space:nowrap">{{ \Illuminate\Support\Carbon::parse($day->last_update)->format('d/m/Y H:i:s') }}</td>
                    <td style="white-space:nowrap">{{ $day->finished_at ? \Illuminate\Support\Carbon::parse($day->finished_at)->format('d/m/Y H:i:s') : 'Belum selesai' }}</td>
                    <td><strong>{{ $day->duration_label }}</strong><br><span class="muted">{{ $day->session_count }} sesi · jam:menit:detik</span></td>
                    <td><span class="pill {{ $day->active_sessions ? 'warning' : 'success' }}">{{ $day->active_sessions ? 'Berjalan' : 'Selesai' }}</span></td>
                    <td><a class="btn secondary" href="{{ route('admin.employee-activities.show', [$day->user_id, $day->work_date]) }}">Detail</a><br><span class="muted">{{ $day->update_count }} update</span></td>
                </tr>
            @empty
                <tr><td colspan="8" class="muted">Belum ada aktifitas karyawan pada periode ini.</td></tr>
            @endforelse
            </tbody>
        </table></div>
        <div class="pagination">{{ $days->links() }}</div>
    </div>
@endsection
