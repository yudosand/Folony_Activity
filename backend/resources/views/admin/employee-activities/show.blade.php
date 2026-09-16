@extends('admin.layouts.app')
@php
    $title = $heading = 'Detail Aktifitas Karyawan';
    $subheading = $employee->full_name . ' · ' . \Illuminate\Support\Carbon::parse($day->work_date)->format('d/m/Y') . ' · ' . config('app.timezone');
@endphp
@section('content')
    <a class="btn secondary" href="{{ route('admin.employee-activities.index', ['search' => $employee->employee_code]) }}" style="margin-bottom:18px">Kembali ke ringkasan</a>
    <div class="grid cols-4" style="margin-bottom:18px">
        <div class="card-kpi"><div class="label">Mulai kerja</div><strong>{{ \Illuminate\Support\Carbon::parse($day->started_at)->format('d/m/Y H:i:s') }}</strong></div>
        <div class="card-kpi"><div class="label">Update terakhir</div><strong>{{ \Illuminate\Support\Carbon::parse($day->last_update)->format('d/m/Y H:i:s') }}</strong></div>
        <div class="card-kpi"><div class="label">Selesai</div><strong>{{ $day->finished_at ? \Illuminate\Support\Carbon::parse($day->finished_at)->format('d/m/Y H:i:s') : 'Masih berjalan' }}</strong></div>
        <div class="card-kpi"><div class="label">Total durasi kerja</div><div class="value">{{ $day->duration_label }}</div><span class="muted">{{ $day->session_count }} sesi · jam:menit:detik</span></div>
    </div>
    <div class="panel pad">
        <h3>Riwayat pekerjaan · {{ $updates->total() }} update</h3>
        <p class="muted">Urutan dari awal hingga selesai. Durasi tidak mencakup jeda antarsesi; sesi berjalan dihitung sampai halaman dimuat.</p>
        <div class="table-wrap"><table>
            <thead><tr><th>Waktu update</th><th>Sesi dimulai</th><th>Pekerjaan</th><th>Status update</th><th>Foto</th></tr></thead>
            <tbody>@foreach($updates as $update)
                <tr>
                    <td style="white-space:nowrap">{{ $update->created_at->format('d/m/Y H:i:s') }}</td>
                    <td style="white-space:nowrap">{{ $update->started_at->format('d/m/Y H:i:s') }}</td>
                    <td style="white-space:pre-wrap;min-width:240px">{{ $update->note }}</td>
                    <td><span class="pill {{ $update->is_finished ? 'success' : '' }}">{{ $update->is_finished ? 'Pekerjaan selesai' : 'Update pekerjaan' }}</span></td>
                    <td>@if($update->photo_url)<a href="{{ $update->photo_url }}" target="_blank" rel="noopener"><img src="{{ $update->photo_url }}" alt="Dokumentasi pekerjaan" loading="lazy" style="width:120px;height:90px;object-fit:cover;border-radius:8px"></a>@else — @endif</td>
                </tr>
            @endforeach</tbody>
        </table></div>
        <div class="pagination">{{ $updates->links() }}</div>
    </div>
@endsection
