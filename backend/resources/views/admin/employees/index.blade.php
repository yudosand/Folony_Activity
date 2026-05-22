@extends('admin.layouts.app')

@php
    $title = 'Master Karyawan';
    $heading = 'Master Karyawan';
    $subheading = 'HR mendaftarkan akun mobile, mengelola role, lokasi kerja, dan profil perusahaan karyawan.';
@endphp

@section('content')
    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input name="search" placeholder="Cari nama / kode / no HP" value="{{ $filters['search'] ?? '' }}">
                <select name="role">
                    <option value="">Semua role</option>
                    @foreach($roles as $role)
                        <option value="{{ $role }}" @selected(($filters['role'] ?? '') === $role)>{{ $role }}</option>
                    @endforeach
                </select>
                <select name="status">
                    <option value="">Semua status</option>
                    <option value="active" @selected(($filters['status'] ?? '') === 'active')>Aktif</option>
                    <option value="inactive" @selected(($filters['status'] ?? '') === 'inactive')>Nonaktif</option>
                </select>
                <button class="btn secondary" type="submit">Filter</button>
            </form>
            <div class="actions">
                <a href="{{ route('admin.reports.index') }}" class="btn secondary">Laporan HR</a>
                <a href="{{ route('admin.employees.create') }}" class="btn primary">Tambah Karyawan</a>
            </div>
        </div>

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Karyawan</th>
                    <th>Role / Jabatan</th>
                    <th>Lokasi</th>
                    <th>Saldo Cuti</th>
                    <th>Total Jam Kerja</th>
                    <th>Aksi</th>
                </tr>
                </thead>
                <tbody>
                @forelse($employees as $employee)
                    @php($metrics = $employeeMetrics[$employee->id])
                    <tr>
                        <td>
                            <strong>{{ $employee->full_name }}</strong><br>
                            <span class="muted">{{ $employee->employee_code }} &middot; {{ $employee->phone_number ?: 'No HP belum diisi' }}</span>
                        </td>
                        <td>
                            <div>{{ strtoupper($employee->role) }}</div>
                            <div class="muted">{{ $employee->job_title ?: 'Jabatan belum diisi' }}</div>
                        </td>
                        <td>
                            <div>{{ $employee->work_location ?: '-' }}</div>
                            <div class="muted">{{ $employee->area_name ?: 'Area belum diisi' }}</div>
                        </td>
                        <td>{{ number_format((float) $metrics['leave_balance_days'], 1) }} hari</td>
                        <td>{{ app(\App\Services\Admin\AdminMetricsService::class)->formatMinutes($metrics['total_work_minutes']) }}</td>
                        <td class="actions">
                            <a class="btn secondary" href="{{ route('admin.employees.show', $employee) }}">Detail</a>
                            <a class="btn secondary" href="{{ route('admin.employees.edit', $employee) }}">Edit</a>
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="muted">Belum ada data karyawan.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $employees->links() }}</div>
    </div>
@endsection
