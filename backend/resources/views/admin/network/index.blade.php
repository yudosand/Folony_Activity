@extends('admin.layouts.app')

@php
    $title = 'Monitoring Jaringan';
    $heading = 'Monitoring Jaringan';
    $subheading = 'HR memonitor data UKM, Mitra, owner lapangan, status follow-up, dan histori kunjungan.';
@endphp

@section('content')
    <div class="grid cols-4" style="margin-bottom:18px;">
        <div class="card-kpi">
            <div class="label">Total Profil</div>
            <div class="value">{{ $summary['total'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">UKM / Mitra</div>
            <div class="value">{{ $summary['ukm'] }} / {{ $summary['mitra'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Butuh Follow-up</div>
            <div class="value">{{ $summary['needs_follow_up'] }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Owner FGG / Area</div>
            <div class="value">{{ $summary['fgg_owned'] }} / {{ $summary['area_owned'] }}</div>
        </div>
    </div>

    <div class="panel pad" style="margin-bottom:18px;">
        <details>
            <summary style="cursor:pointer; font-weight:800; font-size:18px;">Input Jaringan Manual HR</summary>
            <p class="muted" style="margin-top:8px;">Gunakan form ini jika HR perlu menambahkan data UKM/Mitra langsung dari web admin.</p>
            <form method="POST" action="{{ route('admin.network.manual.store') }}" class="grid cols-2" style="margin-top:14px;">
                @csrf
                <div>
                    <label for="manual_type">Tipe</label>
                    <select id="manual_type" name="type" required>
                        @foreach($types as $type => $label)
                            <option value="{{ $type }}" @selected(old('type') === $type)>{{ $label }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label for="manual_status">Status</label>
                    <select id="manual_status" name="status" required>
                        @foreach($statuses as $status)
                            <option value="{{ $status }}" @selected(old('status', 'draft') === $status)>{{ $status }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label for="manual_name">Nama UKM/Mitra</label>
                    <input id="manual_name" name="name" value="{{ old('name') }}" required>
                </div>
                <div>
                    <label for="manual_business_type">Jenis Usaha</label>
                    <input id="manual_business_type" name="business_type" value="{{ old('business_type') }}" required>
                </div>
                <div>
                    <label for="manual_phone_number">Nomor HP</label>
                    <input id="manual_phone_number" name="phone_number" value="{{ old('phone_number') }}" required>
                </div>
                <div>
                    <label for="manual_address">Alamat</label>
                    <input id="manual_address" name="address" value="{{ old('address') }}" required>
                </div>
                <div>
                    <label for="manual_province">Provinsi</label>
                    <input id="manual_province" name="territory_province" value="{{ old('territory_province') }}" required>
                </div>
                <div>
                    <label for="manual_city">Kota/Kabupaten</label>
                    <input id="manual_city" name="territory_city" value="{{ old('territory_city') }}" required>
                </div>
                <div>
                    <label for="manual_district">Kecamatan</label>
                    <input id="manual_district" name="territory_district" value="{{ old('territory_district') }}" required>
                </div>
                <div>
                    <label for="manual_subdistrict">Kelurahan</label>
                    <input id="manual_subdistrict" name="territory_subdistrict" value="{{ old('territory_subdistrict') }}" required>
                </div>
                <div>
                    <label for="manual_latitude">Latitude (opsional)</label>
                    <input id="manual_latitude" name="latitude" type="number" step="any" inputmode="decimal" value="{{ old('latitude') }}">
                </div>
                <div>
                    <label for="manual_longitude">Longitude (opsional)</label>
                    <input id="manual_longitude" name="longitude" type="number" step="any" inputmode="decimal" value="{{ old('longitude') }}">
                </div>
                <div style="grid-column:1 / -1;">
                    <label for="manual_note">Catatan</label>
                    <textarea id="manual_note" name="note" rows="3">{{ old('note') }}</textarea>
                </div>
                <div style="grid-column:1 / -1;">
                    <button class="btn primary" type="submit">Simpan Data Manual</button>
                </div>
            </form>
        </details>

        <hr style="border:0; border-top:1px solid var(--line); margin:22px 0;">

        <details>
            <summary style="cursor:pointer; font-weight:800; font-size:18px;">Import Spreadsheet Jaringan HR</summary>
            <p class="muted" style="margin-top:8px;">
                Import data dari Google Sheet atau CSV. Baris yang memiliki latitude dan longitude valid akan langsung masuk ke heatmap satelit.
            </p>

            @if($errors->has('sheet_url') || $errors->has('csv_file'))
                <div style="margin:14px 0; padding:12px 14px; border-radius:14px; background:#fde9e3; color:var(--danger); border:1px solid rgba(184,75,50,0.18);">
                    {{ $errors->first('sheet_url') ?: $errors->first('csv_file') }}
                </div>
            @endif

            <form method="POST" action="{{ route('admin.network.import') }}" enctype="multipart/form-data" class="grid cols-2" style="margin-top:14px;">
                @csrf
                <div>
                    <label for="import_sheet_url">Link Google Sheet / CSV publik</label>
                    <input id="import_sheet_url" name="sheet_url" value="{{ old('sheet_url') }}" placeholder="https://docs.google.com/spreadsheets/d/...">
                    <div class="muted" style="font-size:12px; margin-top:6px;">Jika link Google tidak bisa dibaca server, download sebagai CSV lalu upload di bawah.</div>
                </div>
                <div>
                    <label for="import_csv_file">Upload CSV</label>
                    <input id="import_csv_file" name="csv_file" type="file" accept=".csv,text/csv,text/plain">
                    <div class="muted" style="font-size:12px; margin-top:6px;">CSV maksimal 5 MB. Upload CSV akan dipakai lebih dulu jika link juga diisi.</div>
                </div>
                <div>
                    <label for="import_default_type">Tipe Default</label>
                    <select id="import_default_type" name="default_type" required>
                        @foreach($types as $type => $label)
                            <option value="{{ $type }}" @selected(old('default_type', 'ukm') === $type)>{{ $label }}</option>
                        @endforeach
                    </select>
                </div>
                <div>
                    <label for="import_default_status">Status Default</label>
                    <select id="import_default_status" name="default_status" required>
                        @foreach($statuses as $status)
                            <option value="{{ $status }}" @selected(old('default_status', 'draft') === $status)>{{ $status }}</option>
                        @endforeach
                    </select>
                </div>
                <div style="grid-column:1 / -1;">
                    <div class="muted" style="font-size:13px; line-height:1.55;">
                        Header yang dikenali: <strong>type/tipe</strong>, <strong>nama</strong>, <strong>alamat</strong>,
                        <strong>jenis_usaha</strong>, <strong>nomor_hp</strong>, <strong>provinsi</strong>,
                        <strong>kota</strong>, <strong>kecamatan</strong>, <strong>kelurahan</strong>,
                        <strong>latitude</strong>, <strong>longitude</strong>, <strong>status</strong>, dan <strong>catatan</strong>.
                    </div>
                </div>
                <div style="grid-column:1 / -1;">
                    <button class="btn primary" type="submit">Import ke Heatmap</button>
                </div>
            </form>
        </details>
    </div>

    <div class="panel pad">
        <div class="toolbar">
            <form method="GET" class="filters">
                <input name="search" placeholder="Cari nama / owner / alamat" value="{{ $filters['search'] ?? '' }}">
                <select name="owner_role">
                    <option value="">Semua owner role</option>
                    @foreach($ownerRoles as $role => $label)
                        <option value="{{ $role }}" @selected(($filters['owner_role'] ?? '') === $role)>{{ $label }}</option>
                    @endforeach
                </select>
                <select name="type">
                    <option value="">Semua tipe</option>
                    @foreach($types as $type => $label)
                        <option value="{{ $type }}" @selected(($filters['type'] ?? '') === $type)>{{ $label }}</option>
                    @endforeach
                </select>
                <select name="status">
                    <option value="">Semua status</option>
                    @foreach($statuses as $status)
                        <option value="{{ $status }}" @selected(($filters['status'] ?? '') === $status)>{{ $status }}</option>
                    @endforeach
                </select>
                <input name="area_name" placeholder="Area" value="{{ $filters['area_name'] ?? '' }}">
                @php
                    $hasDateRange = !empty($filters['date_from']) && !empty($filters['date_until']);
                    $dateRangeLabel = $hasDateRange
                        ? \Illuminate\Support\Carbon::parse($filters['date_from'])->format('d/m/Y') . ' - ' . \Illuminate\Support\Carbon::parse($filters['date_until'])->format('d/m/Y')
                        : '';
                @endphp
                <div style="position:relative; min-width:280px; flex:1 1 280px;">
                    <label for="network_date_range" style="margin-bottom:6px;">Periode</label>
                    <input
                        id="network_date_range"
                        type="text"
                        value="{{ $dateRangeLabel }}"
                        placeholder="Pilih periode tanggal"
                        readonly
                        style="cursor:pointer;"
                    >
                    <input id="network_date_from" name="date_from" type="date" value="{{ $filters['date_from'] ?? '' }}" style="position:absolute; opacity:0; pointer-events:none; width:1px; height:1px; padding:0; border:0;">
                    <input id="network_date_until" name="date_until" type="date" value="{{ $filters['date_until'] ?? '' }}" style="position:absolute; opacity:0; pointer-events:none; width:1px; height:1px; padding:0; border:0;">
                </div>
                <button class="btn secondary" type="submit">Filter</button>
            </form>
            <div class="actions">
                <a href="{{ route('admin.reports.index') }}" class="btn secondary">Laporan HR</a>
                <a href="{{ route('admin.network.index', array_merge(request()->query(), ['export' => 'csv'])) }}" class="btn warn">Export CSV</a>
            </div>
        </div>

        @if($activityRecap)
            <div class="panel pad" style="margin-bottom:18px; background: rgba(255,255,255,0.72);">
                <div class="toolbar">
                    <div>
                        <h3 style="margin:0;">Rekap Aktivitas {{ $activityRecap['owner']->full_name }}</h3>
                        <div class="muted">
                            Periode {{ $activityRecap['date_from']->format('d M Y') }} - {{ $activityRecap['date_until']->format('d M Y') }}
                        </div>
                    </div>
                </div>

                <div class="grid cols-4" style="margin-bottom:16px;">
                    <div class="card-kpi">
                        <div class="label">UKM Baru</div>
                        <div class="value">{{ $activityRecap['summary']['new_ukm'] }}</div>
                    </div>
                    <div class="card-kpi">
                        <div class="label">Mitra Baru</div>
                        <div class="value">{{ $activityRecap['summary']['new_mitra'] }}</div>
                    </div>
                    <div class="card-kpi">
                        <div class="label">Kunjungan</div>
                        <div class="value">{{ $activityRecap['summary']['follow_up_count'] }}</div>
                    </div>
                    <div class="card-kpi">
                        <div class="label">Total Aktivitas</div>
                        <div class="value">{{ $activityRecap['summary']['total_activities'] }}</div>
                    </div>
                </div>

                <div class="table-wrap">
                    <table>
                        <thead>
                        <tr>
                            <th>Waktu</th>
                            <th>Aktivitas</th>
                            <th>Profil</th>
                            <th>Status</th>
                            <th>Area</th>
                            <th>Detail</th>
                        </tr>
                        </thead>
                        <tbody>
                        @forelse($activityRecap['entries'] as $entry)
                            <tr>
                                <td>{{ $entry['date_label'] }}</td>
                                <td>{{ $entry['activity_label'] }}</td>
                                <td>
                                    <div class="stack">
                                        <span>{{ $entry['profile_name'] }}</span>
                                        <span class="muted">{{ $entry['profile_type'] }}</span>
                                    </div>
                                </td>
                                <td><span class="pill">{{ $entry['status'] }}</span></td>
                                <td>{{ $entry['area_name'] ?: '-' }}</td>
                                <td class="muted" style="max-width:340px;">{{ $entry['detail'] }}</td>
                            </tr>
                        @empty
                            <tr><td colspan="6" class="muted">Belum ada aktivitas jaringan pada periode ini.</td></tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        @endif

        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Profil</th>
                    <th>Owner</th>
                    <th>Status</th>
                    <th>Lokasi</th>
                    <th>Follow-up</th>
                </tr>
                </thead>
                <tbody>
                @forelse($profiles as $profile)
                    @php($latestFollowUp = $profile->followUps->sortByDesc('created_at')->first())
                    @php($hasCoordinates = $profile->latitude !== null && $profile->longitude !== null)
                    @php($coordinateLabel = $hasCoordinates
                        ? number_format((float) $profile->latitude, 6, '.', '') . ', ' . number_format((float) $profile->longitude, 6, '.', '')
                        : 'Koordinat belum ada')
                    @php($googleMapsUrl = $hasCoordinates
                        ? 'https://www.google.com/maps?q=' . $profile->latitude . ',' . $profile->longitude
                        : null)
                    <tr>
                        <td>
                            <div class="stack">
                                <strong>{{ $profile->name }}</strong>
                                <span class="muted">{{ strtoupper($profile->type) }} &middot; {{ $profile->business_type }}</span>
                                <span class="eyebrow">ID {{ $profile->id }}</span>
                                <a href="{{ route('admin.network.show', $profile) }}" class="muted">Lihat detail</a>
                            </div>
                        </td>
                        <td>
                            <div class="stack">
                                <span>{{ $profile->owner_name }}</span>
                                <span class="muted">{{ \App\Support\Workflow\UserRole::label($profile->owner_role) }} &middot; {{ $profile->area_name }}</span>
                            </div>
                        </td>
                        <td><span class="pill">{{ $profile->status }}</span></td>
                        <td>
                            <div class="stack">
                                <span>{{ $profile->address }}</span>
                                <span class="muted">{{ $coordinateLabel }}</span>
                                @if($googleMapsUrl)
                                    <a class="muted" href="{{ $googleMapsUrl }}" target="_blank" rel="noreferrer">Buka di Google Maps</a>
                                @endif
                            </div>
                        </td>
                        <td>
                            @if($latestFollowUp)
                                <div class="stack">
                                    <span>{{ $latestFollowUp->title }}</span>
                                    <span class="muted">{{ $latestFollowUp->actor_name }} &middot; {{ optional($latestFollowUp->created_at)->format('d M Y H:i') }}</span>
                                </div>
                            @else
                                <span class="muted">Belum ada follow-up</span>
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="muted">Belum ada data jaringan.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $profiles->links() }}</div>
    </div>
    <script>
        (function () {
            const display = document.getElementById('network_date_range');
            const startInput = document.getElementById('network_date_from');
            const endInput = document.getElementById('network_date_until');
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
