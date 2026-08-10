@extends('admin.layouts.app')

@php
    $title = 'Detail Karyawan';
    $heading = $employee->full_name;
    $subheading = 'Ringkasan profil karyawan, saldo cuti, total jam kerja, histori absensi, WFA, dan approval trail.';
@endphp

@section('content')
    @php
        $performanceMetrics = collect($performanceTargetSummary['metrics'] ?? [])->keyBy('key');
        $hasPerformanceTargets = !empty($performanceTargetDefinitions);
        $officeAttendanceSetting = app(\App\Services\OfficeAttendanceSettingService::class)->current();
    @endphp

    <div class="grid cols-4">
        <div class="card-kpi">
            <div class="label">Saldo Cuti</div>
            <div class="value">{{ number_format((float) $metrics['leave_balance_days'], 1) }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Hari Absensi</div>
            <div class="value">{{ $metrics['attendance_days'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Total Jam Kerja</div>
            <div class="value" style="font-size:24px;">{{ $formattedWorkHours }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Total Pengajuan</div>
            <div class="value">{{ $metrics['leave_requests_count'] + $metrics['wfa_requests_count'] }}</div>
        </div>
    </div>

    @if($hasPerformanceTargets)
        <div class="grid cols-2" style="margin-top:18px;">
            <div class="panel pad">
                <div class="toolbar">
                    <div>
                        <h3 style="margin:0;">Target Aktif dan Realisasi {{ $performanceTargetSummary['period_label'] }}</h3>
                        <div class="muted">Target tetap aktif sampai HR mengubahnya. Progress realisasi selalu dihitung dari bulan berjalan.</div>
                    </div>
                </div>
                <div class="grid cols-3">
                    @foreach($performanceTargetDefinitions as $definition)
                        @php
                            $metric = $performanceMetrics->get($definition['key']);
                        @endphp
                        <div class="card-kpi">
                            <div class="label">{{ $definition['label'] }}</div>
                            <div class="value" style="font-size:26px;">{{ $metric['display_value'] ?? '0/0' }}</div>
                            <div class="muted" style="margin-top:8px;">{{ $definition['description'] }}</div>
                        </div>
                    @endforeach
                </div>
            </div>
            <div class="panel pad">
                <h3 style="margin-top:0;">Ubah Target Aktif</h3>
                <form method="POST" action="{{ route('admin.employees.targets.update', $employee) }}" class="stack">
                    @csrf
                    <div class="form-grid">
                        <div class="full note-callout">
                            Isi target yang ingin aktif sekarang. Nilai ini akan terus dipakai sampai HR mengubahnya lagi, dan langsung berlaku pada bulan aktif.
                        </div>
                        @foreach($performanceTargetDefinitions as $definition)
                            <div>
                                <label for="metric_{{ $definition['key'] }}">{{ $definition['label'] }}</label>
                                <input
                                    id="metric_{{ $definition['key'] }}"
                                    type="number"
                                    min="0"
                                    name="targets[{{ $definition['key'] }}]"
                                    value="{{ old('targets.' . $definition['key'], $performanceTargetValues[$definition['key']] ?? '') }}"
                                    placeholder="Contoh: 50"
                                >
                                <div class="muted" style="margin-top:8px;">{{ $definition['description'] }}</div>
                            </div>
                        @endforeach
                    </div>
                    <div class="actions">
                        <button type="submit" class="btn primary">Simpan Target</button>
                    </div>
                </form>
            </div>
        </div>
    @endif

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <div class="toolbar">
                <h3 style="margin:0;">Profil Perusahaan</h3>
                <a href="{{ route('admin.employees.edit', $employee) }}" class="btn secondary">Edit</a>
            </div>
            <div class="detail-list">
                <div class="detail-item"><strong>Kode</strong><span>{{ $employee->employee_code }}</span></div>
                <div class="detail-item"><strong>Role</strong><span>{{ \App\Support\Workflow\UserRole::label($employee->role) }}</span></div>
                <div class="detail-item"><strong>Jabatan</strong><span>{{ $employee->job_title ?: '-' }}</span></div>
                <div class="detail-item"><strong>Lokasi Kerja</strong><span>{{ $employee->work_location ?: '-' }}</span></div>
                <div class="detail-item"><strong>Titik Kantor Global</strong><span>{{ number_format((float) $officeAttendanceSetting['latitude'], 6, '.', '') . ', ' . number_format((float) $officeAttendanceSetting['longitude'], 6, '.', '') }}</span></div>
                <div class="detail-item"><strong>Radius Absensi Global</strong><span>{{ $officeAttendanceSetting['radius_meters'] . ' meter' }}</span></div>
                <div class="detail-item"><strong>Area</strong><span>{{ $employee->area_name ?: '-' }}</span></div>
                <div class="detail-item"><strong>SPV</strong><span>{{ $employee->spv?->full_name ?: '-' }}</span></div>
                <div class="detail-item"><strong>Management</strong><span>{{ $employee->management?->full_name ?: '-' }}</span></div>
                <div class="detail-item"><strong>Status Akun</strong><span>{{ $employee->is_active ? 'Aktif' : 'Nonaktif' }}</span></div>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Data Diri</h3>
            <div class="detail-list">
                <div class="detail-item"><strong>Email</strong><span>{{ $employee->email ?: '-' }}</span></div>
                <div class="detail-item"><strong>No. HP</strong><span>{{ $employee->phone_number ?: '-' }}</span></div>
                <div class="detail-item"><strong>Tanggal Bergabung</strong><span>{{ optional($employee->joined_at)->format('d M Y') ?: '-' }}</span></div>
                <div class="detail-item"><strong>Alamat</strong><span>{{ $employee->address ?: '-' }}</span></div>
                <div class="detail-item"><strong>Kontak Darurat</strong><span>{{ $employee->emergency_contact_name ?: '-' }}</span></div>
                <div class="detail-item"><strong>No. Kontak Darurat</strong><span>{{ $employee->emergency_contact_phone ?: '-' }}</span></div>
            </div>
        </div>
    </div>

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <h3 style="margin-top:0;">Pengajuan Cuti Terbaru</h3>
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Jenis</th><th>Tanggal</th><th>Status</th></tr></thead>
                    <tbody>
                    @forelse($recentLeaves as $leave)
                        <tr>
                            <td>{{ $leave->category }}</td>
                            <td>{{ $leave->start_at?->format('d M Y') }} - {{ $leave->end_at?->format('d M Y') }}</td>
                            <td><span class="pill">{{ $leave->status }}</span></td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Belum ada histori cuti.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">WFA Terbaru</h3>
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Mode</th><th>Jadwal</th><th>Status</th></tr></thead>
                    <tbody>
                    @forelse($recentWfas as $wfa)
                        <tr>
                            <td>{{ strtoupper($wfa->mode) }}<br><span class="muted">{{ $wfa->reason ?: '-' }}</span></td>
                            <td>{{ $wfa->work_date?->format('d M Y') }}<br><span class="muted">{{ $wfa->start_time }} - {{ $wfa->end_time }}</span></td>
                            <td><span class="pill">{{ $wfa->status }}</span></td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Belum ada histori WFA.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <h3 style="margin-top:0;">Absensi Terbaru</h3>
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Aksi</th><th>Waktu</th><th>Lokasi</th><th>Catatan</th></tr></thead>
                    <tbody>
                    @forelse($recentAttendance as $record)
                        @php
                            $locationLatitude = $record->location['latitude'] ?? null;
                            $locationLongitude = $record->location['longitude'] ?? null;
                            $hasCoordinates = is_numeric($locationLatitude) && is_numeric($locationLongitude);
                            $googleMapsUrl = $hasCoordinates
                                ? 'https://www.google.com/maps?q=' . $locationLatitude . ',' . $locationLongitude
                                : null;
                            $faceCaptureUrl = data_get($record->verification, 'capture.thumbnail_url')
                                ?: data_get($record->verification, 'capture.url');
                            $recordSummaryKey = $record->user_id . '|' . $record->work_date?->toDateString();
                            $recordSummary = $recentAttendanceSummaries[$recordSummaryKey] ?? null;
                            $outsideOfficeMode = ($record->metadata['attendance_mode'] ?? null) === 'outside_office';
                            $actionLabel = match ($record->action) {
                                'checkIn' => 'Checkin',
                                'checkOut' => 'Checkout',
                                'outsideOfficeStart' => 'Checkin Outside',
                                'outsideOfficeFinish' => 'Checkout Outside',
                                default => $record->action,
                            };
                            $outsideOfficePlace = $outsideOfficeMode
                                ? trim((string) ($record->metadata['place_description'] ?? ''))
                                : '';
                            $businessLabel = $outsideOfficeMode
                                ? ($outsideOfficePlace !== '' ? $outsideOfficePlace : 'Absensi luar kantor')
                                : ($record->action === 'checkIn'
                                    ? ($recordSummary['arrival_label'] ?? null)
                                    : ($recordSummary['departure_label'] ?? null));
                            $businessNote = $outsideOfficeMode
                                ? collect([
                                    $record->metadata['ukm_name'] ?? null,
                                    isset($record->metadata['report_type'])
                                        ? match ($record->metadata['report_type']) {
                                            'survey' => 'Survey',
                                            'follow_up' => 'Follow up',
                                            default => 'Kunjungan',
                                        }
                                        : null,
                                    $record->metadata['report_text'] ?? null,
                                ])->filter()->implode(' · ')
                                : ($record->action === 'checkIn'
                                    ? ($recordSummary['arrival_note'] ?? null)
                                    : ($recordSummary['departure_note'] ?? null));
                        @endphp
                        <tr>
                            <td>{{ $actionLabel }}</td>
                            <td>{{ $record->recorded_at?->format('d M Y H:i') }}</td>
                            <td>
                                <div class="stack">
                                    <span>{{ $record->location['address_label'] ?? '-' }}</span>
                                    @if($hasCoordinates)
                                        <span class="muted">{{ number_format((float) $locationLatitude, 6, '.', '') }}, {{ number_format((float) $locationLongitude, 6, '.', '') }}</span>
                                        @if(!empty($record->location['work_area_name'] ?? null))
                                            <span class="muted">
                                                Area {{ $record->location['work_area_name'] }}
                                                @if(isset($record->location['distance_meters']))
                                                    &middot; {{ number_format((float) $record->location['distance_meters'], 0, ',', '.') }}m
                                                @endif
                                            </span>
                                        @endif
                                        <a class="attachment-link" href="{{ $googleMapsUrl }}" target="_blank" rel="noreferrer">Buka di Google Maps</a>
                                    @endif
                                </div>
                            </td>
                            <td>
                                <div class="stack">
                                    @if($businessLabel)
                                        <span><strong>{{ $businessLabel }}</strong></span>
                                    @endif
                                    @if($businessNote)
                                        <span class="muted">{{ $businessNote }}</span>
                                    @endif
                                    @if($outsideOfficeMode && !empty($record->metadata['evidence_attachment']['url'] ?? null))
                                        <a class="attachment-link" href="{{ $record->metadata['evidence_attachment']['url'] }}" target="_blank" rel="noreferrer">Buka foto kunjungan</a>
                                    @endif
                                    @if($record->verification['note'] ?? null)
                                        <span class="muted">Audit wajah: {{ $record->verification['note'] }}</span>
                                    @endif
                                    @if($faceCaptureUrl)
                                        <a class="attachment-link" href="{{ $faceCaptureUrl }}" target="_blank" rel="noreferrer">Lihat foto Face ID</a>
                                    @endif
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="4" class="muted">Belum ada histori absensi.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Approval Trail</h3>
            <div class="table-wrap">
                <table>
                    <thead><tr><th>Module</th><th>Approver</th><th>Status</th></tr></thead>
                    <tbody>
                    @forelse($recentApprovals as $approval)
                        <tr>
                            <td>{{ strtoupper($approval->module) }}<br><span class="muted">{{ $approval->reference_id }}</span></td>
                            <td>{{ $approval->approver_name }}<br><span class="muted">{{ \App\Support\Workflow\UserRole::label($approval->approver_role) }}</span></td>
                            <td><span class="pill">{{ $approval->status }}</span></td>
                        </tr>
                    @empty
                        <tr><td colspan="3" class="muted">Belum ada approval trail.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </div>
    </div>
@endsection
