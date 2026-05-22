@extends('admin.layouts.app')

@php
    $title = 'Dashboard HR';
    $heading = 'Dashboard HR';
    $subheading = 'Ringkasan monitoring karyawan dan aktivitas mobile Folony Activity.';
@endphp

@section('content')
    <div class="grid cols-4">
        <div class="card-kpi">
            <div class="label">Total Karyawan</div>
            <div class="value">{{ $summary['total_employees'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Karyawan Aktif</div>
            <div class="value">{{ $summary['active_employees'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Pending Cuti</div>
            <div class="value">{{ $summary['pending_leave_requests'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Pending WFA</div>
            <div class="value">{{ $summary['pending_wfa_requests'] }}</div>
        </div>
    </div>

    <div class="grid cols-3" style="margin-top:18px;">
        <div class="panel pad">
            <h3 style="margin-top:0;">Source Data Mobile</h3>
            <div class="detail-list">
                <div class="detail-item"><strong>Environment</strong><span>{{ strtoupper($dataSource['environment']) }}</span></div>
                <div class="detail-item"><strong>APP URL</strong><span>{{ $dataSource['app_url'] ?: '-' }}</span></div>
                <div class="detail-item"><strong>DB Connection</strong><span>{{ $dataSource['connection'] }}</span></div>
                <div class="detail-item"><strong>Database</strong><span>{{ $dataSource['database'] }}</span></div>
            </div>
            <div style="margin-top:14px;">
                @if($dataSource['is_live_shared_source'])
                    <span class="pill success">Terhubung ke source data bersama</span>
                @else
                    <span class="pill warning">Masih memakai data lokal / sqlite</span>
                @endif
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Absensi Hari Ini</h3>
            <div class="metric-inline">
                <span>Check-in: <strong>{{ $summary['check_ins_today'] }}</strong></span>
                <span>Check-out: <strong>{{ $summary['check_outs_today'] }}</strong></span>
                <span>Terlambat: <strong>{{ $summary['late_check_ins_today'] }}</strong></span>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Role Aktif</h3>
            <div class="grid">
                @foreach($summary['role_breakdown'] as $roleRow)
                    <div class="pill">{{ strtoupper($roleRow->role) }} &middot; {{ $roleRow->total }}</div>
                @endforeach
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Aksi Cepat HR</h3>
            <div class="actions">
                <a class="btn primary" href="{{ route('admin.employees.create') }}">Tambah Karyawan</a>
                <a class="btn secondary" href="{{ route('admin.attendance.index') }}">Lihat Absensi</a>
                <a class="btn warn" href="{{ route('admin.leaves.index') }}">Lihat Cuti</a>
            </div>
        </div>
    </div>

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <div class="toolbar">
                <h3 style="margin:0;">Pengajuan Cuti Terbaru</h3>
                <a href="{{ route('admin.leaves.index') }}" class="muted">Lihat semua</a>
            </div>
            <div class="table-wrap">
                <table>
                    <thead>
                    <tr>
                        <th>Karyawan</th>
                        <th>Jenis</th>
                        <th>Status</th>
                    </tr>
                    </thead>
                    <tbody>
                    @forelse($summary['recent_leaves'] as $leave)
                        <tr>
                            <td>{{ $leave->requester_name }}</td>
                            <td>{{ $leave->category }}</td>
                            <td><span class="pill">{{ $leave->status }}</span></td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Belum ada data cuti.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
        <div class="panel pad">
            <div class="toolbar">
                <h3 style="margin:0;">Absensi Terbaru</h3>
                <a href="{{ route('admin.attendance.index') }}" class="muted">Lihat semua</a>
            </div>
            <div class="table-wrap">
                <table>
                    <thead>
                    <tr>
                        <th>Karyawan</th>
                        <th>Aksi</th>
                        <th>Jam</th>
                    </tr>
                    </thead>
                    <tbody>
                    @forelse($summary['recent_attendance'] as $record)
                        <tr>
                            <td>{{ $record->user_id }}</td>
                            <td>{{ $record->action }}</td>
                            <td>{{ $record->recorded_at?->format('d M Y H:i') }}</td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Belum ada data absensi.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
@endsection
