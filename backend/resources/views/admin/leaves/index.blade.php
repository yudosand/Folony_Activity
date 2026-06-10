@extends('admin.layouts.app')

@php
    $title = 'Monitoring Cuti / Izin';
    $heading = 'Monitoring Cuti / Izin';
    $subheading = 'HR memonitor pengajuan, saldo cuti, approval trail, dan status keputusan dari mobile.';
@endphp

@section('content')
    <div class="panel pad">
        <form method="GET" class="filters" style="margin-bottom:18px;">
            <input name="search" placeholder="Cari nama / ID pengajuan" value="{{ $filters['search'] ?? '' }}">
            <select name="role">
                <option value="">Semua role</option>
                @foreach($roles as $role)
                    <option value="{{ $role }}" @selected(($filters['role'] ?? '') === $role)>{{ $role }}</option>
                @endforeach
            </select>
            <select name="status">
                <option value="">Semua status</option>
                @foreach($statuses as $status)
                    <option value="{{ $status }}" @selected(($filters['status'] ?? '') === $status)>{{ $status }}</option>
                @endforeach
            </select>
            <select name="category">
                <option value="">Semua jenis</option>
                @foreach($categories as $category)
                    <option value="{{ $category }}" @selected(($filters['category'] ?? '') === $category)>{{ $category }}</option>
                @endforeach
            </select>
            <button class="btn secondary" type="submit">Filter</button>
        </form>

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Pengajuan</th>
                    <th>Periode</th>
                    <th>Durasi</th>
                    <th>Status</th>
                    <th>Bukti</th>
                    <th>Alur Approval</th>
                </tr>
                </thead>
                <tbody>
                @forelse($requests as $request)
                    <tr>
                        <td>
                            <strong>{{ $request->requester_name }}</strong><br>
                            <span class="muted">{{ strtoupper($request->requester_role) }} &middot; {{ $request->category }}</span><br>
                            <span class="muted">{{ $request->reason }}</span>
                        </td>
                        <td>{{ $request->start_at?->format('d M Y') }} - {{ $request->end_at?->format('d M Y') }}</td>
                        <td>{{ number_format((float) $request->duration_value, 1) }} hari</td>
                        <td><span class="pill">{{ $request->status }}</span></td>
                        <td>
                            <div class="grid" style="gap:8px;">
                                @forelse($request->attachments as $attachment)
                                    <a class="attachment-link" href="{{ $attachment->url }}" target="_blank" rel="noreferrer">
                                        {{ $attachment->file_name }}
                                    </a>
                                @empty
                                    <span class="muted">Belum ada bukti</span>
                                @endforelse
                            </div>
                        </td>
                        <td>
                            <div class="grid" style="gap:8px;">
                                @forelse($request->approvalSteps as $step)
                                    <span class="pill {{ $step->status === 'approved' ? 'success' : ($step->status === 'rejected' ? 'danger' : 'warning') }}">
                                        {{ strtoupper($step->approver_role) }} &middot; {{ $step->status }}
                                    </span>
                                @empty
                                    <span class="muted">Tidak memerlukan approval</span>
                                @endforelse
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="muted">Belum ada data pengajuan cuti.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $requests->links() }}</div>
    </div>
@endsection
