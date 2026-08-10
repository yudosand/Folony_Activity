@extends('admin.layouts.app')

@php
    $title = 'Detail WFA';
    $heading = 'Detail WFA ' . $requestRecord->id;
    $subheading = 'Rincian pengajuan WFA, kompensasi, task update, lampiran, dan approval trail.';
@endphp

@section('content')
    @php
        $allAttachments = $requestRecord->taskUpdates
            ->flatMap(fn ($update) => $update->attachments->map(fn ($attachment) => [
                'id' => $attachment->id,
                'file_name' => $attachment->file_name,
                'mime_type' => $attachment->mime_type,
                'url' => $attachment->url,
                'thumbnail_url' => $attachment->thumbnail_url,
                'created_at' => $update->created_at,
            ]))
            ->values();
    @endphp

    <div class="grid cols-4">
        <div class="card-kpi">
            <div class="label">Status</div>
            <div class="value" style="font-size:24px;">{{ $requestRecord->status }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Mode</div>
            <div class="value">{{ strtoupper($requestRecord->mode) }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Task Update</div>
            <div class="value">{{ $requestRecord->taskUpdates->count() }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Lampiran</div>
            <div class="value">{{ $requestRecord->taskUpdates->sum(fn($item) => $item->attachments->count()) }}</div>
        </div>
    </div>

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <h3 style="margin-top:0;">Informasi Pengajuan</h3>
            <div class="detail-list">
                <div class="detail-item"><strong>Karyawan</strong><span>{{ $requestRecord->requester_name }} ({{ \App\Support\Workflow\UserRole::label($requestRecord->requester_role) }})</span></div>
                <div class="detail-item"><strong>Tanggal</strong><span>{{ $requestRecord->work_date?->format('d M Y') ?: '-' }}</span></div>
                <div class="detail-item"><strong>Jadwal</strong><span>{{ $requestRecord->start_time }} - {{ $requestRecord->end_time }}</span></div>
                <div class="detail-item"><strong>Lokasi</strong><span>{{ $requestRecord->location_label ?: '-' }}</span></div>
                <div class="detail-item"><strong>Kompensasi</strong><span>{{ $requestRecord->compensation_mode ?: '-' }}</span></div>
                <div class="detail-item"><strong>Alasan</strong><span>{{ $requestRecord->reason ?: '-' }}</span></div>
                <div class="detail-item"><strong>Task Awal</strong><span>{{ $requestRecord->initial_task ?: '-' }}</span></div>
                <div class="detail-item"><strong>Catatan</strong><span>{{ $requestRecord->note ?: '-' }}</span></div>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Ringkasan Requester</h3>
            @if($requesterMetrics)
                <div class="detail-list">
                    <div class="detail-item"><strong>Saldo Cuti</strong><span>{{ number_format((float) $requesterMetrics['leave_balance_days'], 1) }}</span></div>
                    <div class="detail-item"><strong>Hari Absensi</strong><span>{{ $requesterMetrics['attendance_days'] }}</span></div>
                    <div class="detail-item"><strong>Total Jam Kerja</strong><span>{{ sprintf('%dj %02dm', intdiv($requesterMetrics['total_work_minutes'], 60), $requesterMetrics['total_work_minutes'] % 60) }}</span></div>
                    <div class="detail-item"><strong>Total Cuti</strong><span>{{ $requesterMetrics['leave_requests_count'] }}</span></div>
                    <div class="detail-item"><strong>Total WFA</strong><span>{{ $requesterMetrics['wfa_requests_count'] }}</span></div>
                </div>
            @else
                <span class="muted">Data requester tidak ditemukan.</span>
            @endif
        </div>
    </div>

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <h3 style="margin-top:0;">Approval Trail</h3>
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Approver</th><th>Status</th><th>Catatan</th></tr></thead>
                    <tbody>
                    @forelse($requestRecord->approvalSteps as $step)
                        <tr>
                            <td>{{ $step->approver_name }}<br><span class="muted">{{ \App\Support\Workflow\UserRole::label($step->approver_role) }}</span></td>
                            <td><span class="pill">{{ $step->status }}</span></td>
                            <td>{{ $step->note ?: '-' }}</td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Tidak ada approval trail.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Task Update</h3>
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Waktu</th><th>Update</th><th>Lampiran</th></tr></thead>
                    <tbody>
                    @forelse($requestRecord->taskUpdates as $update)
                        <tr>
                            <td>{{ $update->created_at?->format('d M Y H:i') ?: '-' }}</td>
                            <td>{{ $update->message }}</td>
                            <td>
                                @if($update->attachments->isEmpty())
                                    <span class="muted">-</span>
                                @else
                                    <div class="stack">
                                        @foreach($update->attachments as $attachment)
                                            <span>{{ $attachment->file_name }}</span>
                                        @endforeach
                                    </div>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Belum ada task update.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="panel pad" style="margin-top:18px;">
        <div class="toolbar">
            <h3 style="margin:0;">Preview Lampiran</h3>
            <span class="muted">Lampiran task update yang dikirim dari aplikasi mobile.</span>
        </div>
        @if($allAttachments->isEmpty())
            <div class="note-callout muted">Belum ada lampiran yang bisa dipreview.</div>
        @else
            <div class="attachment-gallery">
                @foreach($allAttachments as $attachment)
                    <div class="attachment-card">
                        @if(!empty($attachment['thumbnail_url']))
                            <a href="{{ $attachment['url'] ?: $attachment['thumbnail_url'] }}" target="_blank" rel="noreferrer">
                                <img src="{{ $attachment['thumbnail_url'] }}" alt="{{ $attachment['file_name'] }}">
                            </a>
                        @else
                            <div class="note-callout muted">Preview tidak tersedia</div>
                        @endif
                        <div class="attachment-meta">
                            <div class="attachment-name">{{ $attachment['file_name'] ?: 'Lampiran WFA' }}</div>
                            <div class="muted">{{ $attachment['mime_type'] ?: '-' }}</div>
                            <div class="muted">{{ $attachment['created_at']?->format('d M Y H:i') ?: '-' }}</div>
                            @if(!empty($attachment['url']))
                                <a class="attachment-link" href="{{ $attachment['url'] }}" target="_blank" rel="noreferrer">Buka file</a>
                            @endif
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </div>
@endsection
