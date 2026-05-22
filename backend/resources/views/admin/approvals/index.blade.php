@extends('admin.layouts.app')

@php
    $title = 'Approval Center';
    $heading = 'Approval Center';
    $subheading = 'HR memonitor seluruh approval cuti dan WFA lintas role, termasuk catatan keputusan dan waktu aksi.';
@endphp

@section('content')
    <div class="grid cols-4" style="margin-bottom:18px;">
        <div class="card-kpi">
            <div class="label">Total Step Approval</div>
            <div class="value">{{ $summary['total'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Pending</div>
            <div class="value">{{ $summary['pending'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Approved / Rejected</div>
            <div class="value">{{ $summary['approved'] }} / {{ $summary['rejected'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Leave / WFA</div>
            <div class="value">{{ $summary['leave'] }} / {{ $summary['wfa'] }}</div>
        </div>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input name="search" placeholder="Cari approver / reference ID" value="{{ $filters['search'] ?? '' }}">
                <select name="module">
                    <option value="">Semua module</option>
                    @foreach($modules as $module => $label)
                        <option value="{{ $module }}" @selected(($filters['module'] ?? '') === $module)>{{ $label }}</option>
                    @endforeach
                </select>
                <select name="status">
                    <option value="">Semua status</option>
                    @foreach($statuses as $status)
                        <option value="{{ $status }}" @selected(($filters['status'] ?? '') === $status)>{{ $status }}</option>
                    @endforeach
                </select>
                <select name="approver_role">
                    <option value="">Semua approver role</option>
                    @foreach($approverRoles as $role => $label)
                        <option value="{{ $role }}" @selected(($filters['approver_role'] ?? '') === $role)>{{ $label }}</option>
                    @endforeach
                </select>
                <button class="btn secondary" type="submit">Filter</button>
            </form>
            <a href="{{ route('admin.approvals.index', array_merge(request()->query(), ['export' => 'csv'])) }}" class="btn warn">Export CSV</a>
        </div>

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Module</th>
                    <th>Requester</th>
                    <th>Approver</th>
                    <th>Status</th>
                    <th>Waktu</th>
                    <th>Catatan</th>
                </tr>
                </thead>
                <tbody>
                @forelse($steps as $step)
                    @php($reference = $step->module === 'leave' ? $step->leaveRequest : $step->wfaRequest)
                    <tr>
                        <td>
                            <div class="stack">
                                <strong>{{ strtoupper($step->module) }}</strong>
                                <span class="muted">{{ $step->reference_id }}</span>
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <span>{{ $reference?->requester_name ?? '-' }}</span>
                                <span class="muted">{{ strtoupper($reference?->requester_role ?? '-') }}</span>
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <span>{{ $step->approver_name }}</span>
                                <span class="muted">{{ strtoupper($step->approver_role) }}</span>
                            </div>
                        </td>
                        <td><span class="pill {{ $step->status === 'approved' ? 'success' : ($step->status === 'rejected' ? 'danger' : 'warning') }}">{{ $step->status }}</span></td>
                        <td>{{ optional($step->acted_at)->format('d M Y H:i') ?: '-' }}</td>
                        <td>{{ $step->note ?: '-' }}</td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="muted">Belum ada data approval.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $steps->links() }}</div>
    </div>
@endsection
