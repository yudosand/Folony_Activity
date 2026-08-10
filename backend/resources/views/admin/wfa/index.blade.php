@extends('admin.layouts.app')

@php
    $title = 'Monitoring WFA';
    $heading = 'Monitoring WFA';
    $subheading = 'HR memonitor WFA reguler, overtime, kompensasi, task update, dan status approval.';
@endphp

@section('content')
    <div class="grid cols-4" style="margin-bottom:18px;">
        <div class="card-kpi">
            <div class="label">Total WFA</div>
            <div class="value">{{ $summary['total'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Pending</div>
            <div class="value">{{ $summary['pending'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Overtime</div>
            <div class="value">{{ $summary['overtime'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Active / Completed</div>
            <div class="value">{{ $summary['active'] }} / {{ $summary['completed'] }}</div>
        </div>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input name="search" placeholder="Cari nama / ID / lokasi" value="{{ $filters['search'] ?? '' }}">
                <select name="role">
                    <option value="">Semua role</option>
                    @foreach($roles as $role => $label)
                        <option value="{{ $role }}" @selected(($filters['role'] ?? '') === $role)>{{ $label }}</option>
                    @endforeach
                </select>
                <select name="status">
                    <option value="">Semua status</option>
                    @foreach($statuses as $status)
                        <option value="{{ $status }}" @selected(($filters['status'] ?? '') === $status)>{{ $status }}</option>
                    @endforeach
                </select>
                <select name="mode">
                    <option value="">Semua mode</option>
                    @foreach($modes as $mode => $label)
                        <option value="{{ $mode }}" @selected(($filters['mode'] ?? '') === $mode)>{{ $label }}</option>
                    @endforeach
                </select>
                <button class="btn secondary" type="submit">Filter</button>
            </form>
            <div class="actions">
                <a href="{{ route('admin.reports.index') }}" class="btn secondary">Laporan HR</a>
                <a href="{{ route('admin.wfa.index', array_merge(request()->query(), ['export' => 'csv'])) }}" class="btn warn">Export CSV</a>
            </div>
        </div>

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Pengajuan</th>
                    <th>Jadwal</th>
                    <th>Kompensasi</th>
                    <th>Status</th>
                    <th>Task Update</th>
                    <th>Approval</th>
                </tr>
                </thead>
                <tbody>
                @forelse($requests as $request)
                    <tr>
                        <td>
                            <div class="stack">
                                <strong>{{ $request->requester_name }}</strong>
                                <span class="muted">{{ \App\Support\Workflow\UserRole::label($request->requester_role) }} &middot; {{ strtoupper($request->mode) }}</span>
                                <span class="muted">{{ $request->location_label }}</span>
                                <span class="muted">{{ $request->reason }}</span>
                                <span class="eyebrow">ID {{ $request->id }}</span>
                                <a href="{{ route('admin.wfa.show', $request) }}" class="muted">Lihat detail</a>
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <span>{{ $request->work_date?->format('d M Y') }}</span>
                                <span class="muted">{{ $request->start_time }} - {{ $request->end_time }}</span>
                            </div>
                        </td>
                        <td>{{ $request->compensation_mode ?: '-' }}</td>
                        <td><span class="pill">{{ $request->status }}</span></td>
                        <td>
                            <div class="stack">
                                <span>{{ $request->taskUpdates->count() }} update</span>
                                <span class="muted">{{ $request->taskUpdates->sum(fn($item) => $item->attachments->count()) }} lampiran</span>
                            </div>
                        </td>
                        <td>
                            <div class="grid" style="gap:8px;">
                                @forelse($request->approvalSteps as $step)
                                    <span class="pill {{ $step->status === 'approved' ? 'success' : ($step->status === 'rejected' ? 'danger' : 'warning') }}">
                                        {{ \App\Support\Workflow\UserRole::label($step->approver_role) }} &middot; {{ $step->status }}
                                    </span>
                                @empty
                                    <span class="muted">Tidak perlu approval</span>
                                @endforelse
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="muted">Belum ada data WFA.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $requests->links() }}</div>
    </div>
@endsection
