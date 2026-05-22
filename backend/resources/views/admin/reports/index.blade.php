@extends('admin.layouts.app')

@php
    $title = 'Laporan HR';
    $heading = 'Laporan HR';
    $subheading = 'Rekap formal untuk karyawan, absensi, cuti, WFA, dan jaringan dengan filter periode dan role.';
@endphp

@section('content')
    <div class="grid cols-4" style="margin-bottom:18px;">
        <div class="card-kpi">
            <div class="label">Karyawan Aktif</div>
            <div class="value">{{ $summary['activeEmployees'] }} / {{ $summary['employees'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Cuti / Approved</div>
            <div class="value">{{ $summary['leaveRequests'] }} / {{ $summary['approvedLeaves'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">WFA / Overtime</div>
            <div class="value">{{ $summary['wfaRequests'] }} / {{ $summary['overtimeWfa'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Absensi / Jaringan</div>
            <div class="value">{{ $summary['attendanceRecords'] }} / {{ $summary['networkProfiles'] }}</div>
        </div>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input type="date" name="date_from" value="{{ $filters['date_from'] ?? '' }}">
                <input type="date" name="date_until" value="{{ $filters['date_until'] ?? '' }}">
                <select name="role">
                    <option value="">Semua role</option>
                    @foreach($roles as $role)
                        <option value="{{ $role }}" @selected(($filters['role'] ?? '') === $role)>{{ $role }}</option>
                    @endforeach
                </select>
                <button class="btn secondary" type="submit">Filter</button>
            </form>
            <a href="{{ route('admin.reports.index', array_merge(request()->query(), ['export' => 'csv'])) }}" class="btn warn">Export CSV</a>
        </div>

        <div class="grid cols-2">
            <div class="panel pad">
                <h3 style="margin-top:0;">Rekap Karyawan Teratas</h3>
                <div class="table-wrap">
                    <table>
                        <thead><tr><th>Karyawan</th><th>Role</th><th>Jam Kerja</th><th>Cuti / WFA</th></tr></thead>
                        <tbody>
                        @forelse($topEmployees as $row)
                            <tr>
                                <td>{{ $row['employee']->full_name }}<br><span class="muted">{{ $row['employee']->employee_code }}</span></td>
                                <td>{{ strtoupper($row['employee']->role) }}</td>
                                <td>{{ sprintf('%dj %02dm', intdiv($row['metrics']['total_work_minutes'], 60), $row['metrics']['total_work_minutes'] % 60) }}</td>
                                <td>{{ $row['metrics']['leave_requests_count'] }} / {{ $row['metrics']['wfa_requests_count'] }}</td>
                            </tr>
                        @empty
                            <tr><td colspan="4" class="muted">Belum ada data karyawan.</td></tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="panel pad">
                <h3 style="margin-top:0;">Aktivitas Pengajuan Terbaru</h3>
                <div class="table-wrap">
                    <table>
                        <thead><tr><th>Module</th><th>Karyawan</th><th>Status</th><th>Waktu</th></tr></thead>
                        <tbody>
                        @forelse($recentApprovals as $item)
                            <tr>
                                <td>{{ strtoupper($item['module']) }}</td>
                                <td>{{ $item['record']->requester_name }}</td>
                                <td>{{ $item['record']->status }}</td>
                                <td>{{ optional($item['record']->submitted_at ?? $item['record']->work_date)->format('d M Y H:i') ?: optional($item['record']->work_date)->format('d M Y') ?: '-' }}</td>
                            </tr>
                        @empty
                            <tr><td colspan="4" class="muted">Belum ada aktivitas.</td></tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
@endsection
