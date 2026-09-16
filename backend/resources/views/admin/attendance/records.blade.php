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
                        <td>
                            <strong>{{ $record->user?->full_name ?? $record->user_id }}</strong><br>
                            <span class="muted">{{ $record->user?->employee_code ?? '-' }} &middot; {{ \App\Support\Workflow\UserRole::label($record->user?->role) }}</span>
                        </td>
                        <td>{{ $actionLabel }}</td>
                        <td>{{ $record->recorded_at?->format('d M Y H:i:s') }}</td>
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
