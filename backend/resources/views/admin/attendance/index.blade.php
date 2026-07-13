@extends('admin.layouts.app')

@php
    $title = 'Monitoring Absensi';
    $heading = 'Monitoring Absensi';
    $subheading = 'HR bisa melihat jam check-in/check-out, lokasi, status verifikasi wajah, dan total jam kerja dari aplikasi mobile.';
@endphp

@section('content')
    <div class="panel pad" style="margin-bottom:18px;">
        <div class="toolbar">
            <div>
                <h3 style="margin:0;">Area Kerja Absensi</h3>
                <div class="muted">HR bisa mengatur titik lokasi dan radius per kantor/cabang. User hanya bisa absensi normal saat berada di radius area yang dipilih pada data karyawan.</div>
            </div>
        </div>

        <form method="POST" action="{{ route('admin.attendance.work-areas.store') }}" class="filters" style="margin-bottom:16px;">
            @csrf
            <div>
                <label for="work_area_name">Nama Area</label>
                <input id="work_area_name" name="name" value="{{ old('name') }}" placeholder="Contoh: Kantor Pusat / Cabang Serpong" required>
            </div>
            <div>
                <label for="work_area_latitude">Latitude</label>
                <input id="work_area_latitude" name="latitude" type="number" step="0.000000000000001" value="{{ old('latitude', '-6.159692890088879') }}" required>
            </div>
            <div>
                <label for="work_area_longitude">Longitude</label>
                <input id="work_area_longitude" name="longitude" type="number" step="0.000000000000001" value="{{ old('longitude', '106.81804453790896') }}" required>
            </div>
            <div>
                <label for="work_area_radius">Radius (meter)</label>
                <input id="work_area_radius" name="radius_meters" type="number" min="1" step="1" value="{{ old('radius_meters', 1000) }}" required>
            </div>
            <button class="btn primary" type="submit">Tambah Area</button>
        </form>

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Area</th>
                    <th>Latitude</th>
                    <th>Longitude</th>
                    <th>Radius</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
                </thead>
                <tbody>
                @forelse($attendanceWorkAreas as $workArea)
                    <tr>
                        @php
                            $workAreaFormId = 'work_area_form_' . $workArea->id;
                        @endphp
                        <td>
                            <form id="{{ $workAreaFormId }}" method="POST" action="{{ route('admin.attendance.work-areas.update', $workArea) }}">
                                @csrf
                                @method('PUT')
                            </form>
                            <input form="{{ $workAreaFormId }}" name="name" value="{{ old('name', $workArea->name) }}" required>
                        </td>
                        <td><input form="{{ $workAreaFormId }}" name="latitude" type="number" step="0.000000000000001" value="{{ old('latitude', $workArea->latitude) }}" required></td>
                        <td><input form="{{ $workAreaFormId }}" name="longitude" type="number" step="0.000000000000001" value="{{ old('longitude', $workArea->longitude) }}" required></td>
                        <td><input form="{{ $workAreaFormId }}" name="radius_meters" type="number" min="1" step="1" value="{{ old('radius_meters', $workArea->radius_meters) }}" required></td>
                        <td>
                            <select form="{{ $workAreaFormId }}" name="is_active">
                                <option value="1" @selected($workArea->is_active)>Aktif</option>
                                <option value="0" @selected(! $workArea->is_active)>Nonaktif</option>
                            </select>
                        </td>
                        <td>
                            <div class="stack">
                                <button form="{{ $workAreaFormId }}" class="btn secondary" type="submit">Simpan</button>
                                <a class="muted" href="https://www.google.com/maps?q={{ $workArea->latitude }},{{ $workArea->longitude }}" target="_blank" rel="noreferrer">Buka di Google Maps</a>
                            </div>
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="muted">Belum ada area absensi.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <div class="grid cols-4" style="margin-bottom:18px;">
        <div class="card-kpi">
            <div class="label">Total Record</div>
            <div class="value">{{ $summary['records'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Check-in / Check-out</div>
            <div class="value">{{ $summary['check_ins'] }} / {{ $summary['check_outs'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Terverifikasi / Telat</div>
            <div class="value">{{ $summary['verified'] }} / {{ $summary['late'] }}</div>
            <div class="muted" style="margin-top:8px;">Retry {{ $summary['retry'] }} &middot; Ditolak {{ $summary['rejected'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Total Jam Kerja</div>
            <div class="value" style="font-size:24px;">{{ sprintf('%dj %02dm', intdiv($summary['work_minutes'], 60), $summary['work_minutes'] % 60) }}</div>
            <div class="muted" style="margin-top:8px;">Audit wajah {{ $summary['audited'] }}</div>
        </div>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input name="search" placeholder="Cari nama / kode karyawan" value="{{ $filters['search'] ?? '' }}">
                <select name="role">
                    <option value="">Semua role</option>
                    @foreach($roles as $role)
                        <option value="{{ $role }}" @selected(($filters['role'] ?? '') === $role)>{{ $role }}</option>
                    @endforeach
                </select>
                <select name="decision">
                    <option value="">Semua hasil verifikasi</option>
                    @foreach($decisions as $decision)
                        <option value="{{ $decision }}" @selected(($filters['decision'] ?? '') === $decision)>{{ strtoupper($decision) }}</option>
                    @endforeach
                </select>
                @php
                    $hasDateRange = !empty($filters['date_from']) && !empty($filters['date_until']);
                    $dateRangeLabel = $hasDateRange
                        ? \Illuminate\Support\Carbon::parse($filters['date_from'])->format('d/m/Y') . ' - ' . \Illuminate\Support\Carbon::parse($filters['date_until'])->format('d/m/Y')
                        : '';
                @endphp
                <div style="position:relative; min-width:280px; flex:1 1 280px;">
                    <label for="attendance_date_range" style="margin-bottom:6px;">Periode</label>
                    <input
                        id="attendance_date_range"
                        type="text"
                        value="{{ $dateRangeLabel }}"
                        placeholder="Pilih periode tanggal"
                        readonly
                        style="cursor:pointer;"
                    >
                    <input id="attendance_date_from" name="date_from" type="date" value="{{ $filters['date_from'] ?? '' }}" style="position:absolute; opacity:0; pointer-events:none; width:1px; height:1px; padding:0; border:0;">
                    <input id="attendance_date_until" name="date_until" type="date" value="{{ $filters['date_until'] ?? '' }}" style="position:absolute; opacity:0; pointer-events:none; width:1px; height:1px; padding:0; border:0;">
                </div>
                <button class="btn secondary" type="submit">Filter</button>
            </form>
            <div class="actions">
                <a href="{{ route('admin.reports.index') }}" class="btn secondary">Laporan HR</a>
                <a href="{{ route('admin.attendance.index', array_merge(request()->query(), ['export' => 'csv'])) }}" class="btn warn">Export CSV</a>
            </div>
        </div>

        @if($attendanceRecap)
            <div class="panel pad" style="margin-bottom:18px; background: rgba(255,255,255,0.72);">
                <div class="toolbar">
                    <div>
                        <h3 style="margin:0;">Rekap Harian {{ $attendanceRecap['employee']->full_name }}</h3>
                        <div class="muted">
                            Periode {{ $attendanceRecap['date_from']->format('d M Y') }} - {{ $attendanceRecap['date_until']->format('d M Y') }}
                        </div>
                    </div>
                </div>

                <div class="grid cols-4" style="margin-bottom:16px;">
                    <div class="card-kpi">
                        <div class="label">Hadir</div>
                        <div class="value">{{ $attendanceRecap['summary']['present_days'] }}</div>
                    </div>
                    <div class="card-kpi">
                        <div class="label">Cuti</div>
                        <div class="value">{{ $attendanceRecap['summary']['leave_days'] }}</div>
                    </div>
                    <div class="card-kpi">
                        <div class="label">WFA</div>
                        <div class="value">{{ $attendanceRecap['summary']['wfa_days'] }}</div>
                    </div>
                    <div class="card-kpi">
                        <div class="label">Tidak Ada Absensi</div>
                        <div class="value">{{ $attendanceRecap['summary']['absent_days'] }}</div>
                    </div>
                </div>

                <div class="table-wrap">
                    <table>
                        <thead>
                        <tr>
                            <th>Tanggal</th>
                            <th>Status</th>
                            <th>Check-in</th>
                            <th>Check-out</th>
                            <th>Rule Hari Itu</th>
                            <th>Keterangan</th>
                        </tr>
                        </thead>
                        <tbody>
                        @foreach($attendanceRecap['days'] as $day)
                            <tr>
                                <td>{{ $day['date']->format('d M Y') }}</td>
                                <td><span class="pill">{{ $day['status_label'] }}</span></td>
                                <td>{{ $day['check_in'] }}</td>
                                <td>{{ $day['check_out'] }}</td>
                                <td>{{ $day['rule_label'] }}</td>
                                <td class="muted" style="max-width:340px;">{{ $day['note'] }}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </div>
            </div>
        @endif

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Karyawan</th>
                    <th>Aksi</th>
                    <th>Jam</th>
                    <th>Lokasi</th>
                    <th>Verifikasi Wajah</th>
                    <th>Catatan</th>
                    <th>Status</th>
                </tr>
                </thead>
                <tbody>
                @forelse($records as $record)
                    @php
                        $decision = $record->verification['decision'] ?? null;
                        $decisionLabel = match ($decision) {
                            'verified' => 'Terverifikasi',
                            'retry' => 'Perlu Ulangi Scan',
                            'rejected' => 'Ditolak',
                            default => 'Belum Ada Audit',
                        };
                        $decisionClass = match ($decision) {
                            'verified' => 'success',
                            'retry' => 'warn',
                            'rejected' => 'danger',
                            default => '',
                        };
                        $locationLatitude = $record->location['latitude'] ?? null;
                        $locationLongitude = $record->location['longitude'] ?? null;
                        $hasCoordinates = is_numeric($locationLatitude) && is_numeric($locationLongitude);
                        $coordinateLabel = $hasCoordinates
                            ? number_format((float) $locationLatitude, 6, '.', '') . ', ' . number_format((float) $locationLongitude, 6, '.', '')
                            : null;
                        $googleMapsUrl = $hasCoordinates
                            ? 'https://www.google.com/maps?q=' . $locationLatitude . ',' . $locationLongitude
                            : null;
                        $faceCaptureUrl = data_get($record->verification, 'capture.thumbnail_url')
                            ?: data_get($record->verification, 'capture.url');
                        $recordSummaryKey = $record->user_id . '|' . $record->work_date?->toDateString();
                        $recordSummary = $recordSummaries[$recordSummaryKey] ?? null;
                        $outsideOfficeMode = ($record->metadata['attendance_mode'] ?? null) === 'outside_office';
                        $businessLabel = $outsideOfficeMode
                            ? ($record->action === 'outsideOfficeStart' ? 'Absensi luar kantor dimulai' : 'Absensi luar kantor selesai')
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
                        <td>
                            <strong>{{ $record->user?->full_name ?? $record->user_id }}</strong><br>
                            <span class="muted">{{ $record->user?->employee_code ?? '-' }} &middot; {{ strtoupper($record->user?->role ?? '-') }}</span>
                        </td>
                        <td>{{ $record->action }}</td>
                        <td>{{ $record->recorded_at?->format('d M Y H:i') }}</td>
                        <td>
                            <div class="stack">
                                <span>{{ $record->location['address_label'] ?? '-' }}</span>
                                @if($coordinateLabel)
                                    <span class="muted">{{ $coordinateLabel }}</span>
                                @endif
                                @if(!empty($record->location['work_area_name'] ?? null))
                                    <span class="muted">
                                        Area {{ $record->location['work_area_name'] }}
                                        @if(isset($record->location['distance_meters']))
                                            &middot; {{ number_format((float) $record->location['distance_meters'], 0, ',', '.') }}m dari titik area
                                        @endif
                                    </span>
                                @endif
                                @if($googleMapsUrl)
                                    <a class="muted" href="{{ $googleMapsUrl }}" target="_blank" rel="noreferrer">Buka di Google Maps</a>
                                @endif
                            </div>
                        </td>
                        <td>
                            @if($decision !== null)
                                <span class="pill {{ $decisionClass }}">{{ $decisionLabel }}</span>
                                <div class="muted">Match {{ $record->verification['match_score'] ?? '-' }}</div>
                                <div class="muted">Liveness {{ $record->verification['liveness_score'] ?? '-' }}</div>
                                @if($faceCaptureUrl)
                                    <div style="margin-top:6px;">
                                        <a class="attachment-link" href="{{ $faceCaptureUrl }}" target="_blank" rel="noreferrer">Lihat foto Face ID</a>
                                    </div>
                                @endif
                            @else
                                <span class="pill">Belum valid</span>
                            @endif
                        </td>
                        <td style="max-width:320px;">
                            @if($businessLabel || $businessNote)
                                @if($businessLabel)
                                    <div><strong>{{ $businessLabel }}</strong></div>
                                @endif
                                @if($businessNote)
                                    <div class="muted">{{ $businessNote }}</div>
                                @endif
                                @if($outsideOfficeMode && !empty($record->metadata['evidence_attachment']['url'] ?? null))
                                    <div style="margin-top:6px;">
                                        <a class="attachment-link" href="{{ $record->metadata['evidence_attachment']['url'] }}" target="_blank" rel="noreferrer">Buka foto kunjungan</a>
                                    </div>
                                @endif
                                @if($record->verification['note'] ?? null)
                                    <div class="muted" style="margin-top:6px;">Audit wajah: {{ $record->verification['note'] }}</div>
                                @endif
                            @elseif($record->verification['note'] ?? null)
                                <span class="muted">Audit wajah: {{ $record->verification['note'] }}</span>
                            @else
                                <span class="muted">Belum ada catatan absensi.</span>
                            @endif
                        </td>
                        <td><span class="pill">{{ $record->status }}</span></td>
                    </tr>
                @empty
                    <tr><td colspan="7" class="muted">Belum ada data absensi.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $records->links() }}</div>
    </div>
    <script>
        (function () {
            const display = document.getElementById('attendance_date_range');
            const startInput = document.getElementById('attendance_date_from');
            const endInput = document.getElementById('attendance_date_until');
            if (!display || !startInput || !endInput) {
                return;
            }

            const formatDate = (value) => {
                if (!value) {
                    return '';
                }
                const [year, month, day] = value.split('-');
                if (!year || !month || !day) {
                    return value;
                }
                return `${day}/${month}/${year}`;
            };

            const refreshLabel = () => {
                if (startInput.value && endInput.value) {
                    display.value = `${formatDate(startInput.value)} - ${formatDate(endInput.value)}`;
                    return;
                }
                if (startInput.value) {
                    display.value = formatDate(startInput.value);
                    return;
                }
                display.value = '';
            };

            const openPicker = (input) => {
                if (typeof input.showPicker === 'function') {
                    input.showPicker();
                    return;
                }
                input.focus();
            };

            display.addEventListener('click', () => {
                openPicker(startInput);
            });

            startInput.addEventListener('change', () => {
                if (!endInput.value || endInput.value < startInput.value) {
                    endInput.value = startInput.value;
                }
                refreshLabel();
                openPicker(endInput);
            });

            endInput.addEventListener('change', refreshLabel);
            refreshLabel();
        })();
    </script>
@endsection
