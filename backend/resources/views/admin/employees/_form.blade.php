@csrf
@if($method !== 'POST')
    @method($method)
@endif

@php
    $territoryRulesPayload = old('territory_rules_payload');
    $territoryRules = [];

    if (is_string($territoryRulesPayload) && trim($territoryRulesPayload) !== '') {
        try {
            $decodedRules = json_decode($territoryRulesPayload, true, 512, JSON_THROW_ON_ERROR);
            $territoryRules = is_array($decodedRules) ? $decodedRules : [];
        } catch (\JsonException) {
            $territoryRules = [];
        }
    }

    if ($territoryRules === []) {
        $territoryRules = \App\Support\Territory\TerritoryData::userAssignments($employee);
    }
@endphp

<div class="form-grid">
    <div>
        <label for="employee_code">Kode Karyawan</label>
        <input id="employee_code" name="employee_code" value="{{ old('employee_code', $employee->employee_code) }}" required>
    </div>
    <div>
        <label for="full_name">Nama Lengkap</label>
        <input id="full_name" name="full_name" value="{{ old('full_name', $employee->full_name) }}" required>
    </div>
    <div>
        <label for="email">Email</label>
        <input id="email" name="email" type="email" value="{{ old('email', $employee->email) }}">
    </div>
    <div>
        <label for="phone_number">Nomor HP</label>
        <input id="phone_number" name="phone_number" value="{{ old('phone_number', $employee->phone_number) }}">
    </div>
    <div>
        <label for="role">Role</label>
        <select id="role" name="role" required>
            @foreach($roles as $role)
                <option value="{{ $role }}" @selected(old('role', $employee->role) === $role)>{{ $role }}</option>
            @endforeach
        </select>
    </div>
    <div>
        <label for="job_title">Jabatan</label>
        <input id="job_title" name="job_title" value="{{ old('job_title', $employee->job_title) }}">
    </div>
    <div>
        <label for="area_name">Area</label>
        <input id="area_name" name="area_name" value="{{ old('area_name', $employee->area_name) }}" readonly>
    </div>
    <div>
        <label for="attendance_work_area_id">Area Absensi</label>
        <select id="attendance_work_area_id" name="attendance_work_area_id" required>
            <option value="">- Pilih Area Absensi -</option>
            @foreach(($attendanceWorkAreas ?? collect()) as $workArea)
                <option
                    value="{{ $workArea->id }}"
                    data-name="{{ $workArea->name }}"
                    @selected(old('attendance_work_area_id', $employee->attendance_work_area_id) === $workArea->id)
                >
                    {{ $workArea->name }} ({{ $workArea->radius_meters }}m)
                </option>
            @endforeach
        </select>
    </div>
    <div>
        <label for="work_location">Lokasi Kerja</label>
        <input id="work_location" name="work_location" value="{{ old('work_location', $employee->work_location) }}" readonly>
    </div>
    <input id="territory_scope" name="territory_scope" type="hidden" value="{{ old('territory_scope', $employee->territory_scope) }}">
    <input id="territory_rules_payload" name="territory_rules_payload" type="hidden" value="{{ old('territory_rules_payload', json_encode($territoryRules, JSON_UNESCAPED_UNICODE)) }}">
    <div class="full">
        <label>Wilayah Kerja Bertingkat</label>
        <p class="muted" style="margin:6px 0 0;">
            Susun rule area kerja dengan mode <strong>include</strong> dan <strong>exclude</strong>. Anda bisa memberi cakupan beberapa provinsi/kota/kecamatan/kelurahan sekaligus, lalu mengecualikan wilayah kecil tertentu bila dibutuhkan.
        </p>
    </div>
    <div>
        <label for="territory_rule_type">Mode Rule</label>
        <select id="territory_rule_type">
            <option value="include">Include</option>
            <option value="exclude">Exclude</option>
        </select>
    </div>
    <div>
        <label for="territory_province">Provinsi Area Kerja</label>
        <select id="territory_province" name="territory_province">
            <option value="">- Pilih Provinsi -</option>
        </select>
    </div>
    <div>
        <label for="territory_city">Kota/Kabupaten Area Kerja</label>
        <select id="territory_city" name="territory_city">
            <option value="">- Semua Kota/Kabupaten dalam Provinsi -</option>
        </select>
    </div>
    <div>
        <label for="territory_district">Kecamatan Area Kerja</label>
        <select id="territory_district" name="territory_district">
            <option value="">- Semua Kecamatan dalam Kota -</option>
        </select>
    </div>
    <div>
        <label for="territory_subdistrict">Kelurahan Area Kerja</label>
        <select id="territory_subdistrict" name="territory_subdistrict">
            <option value="">- Semua Kelurahan dalam Kecamatan -</option>
        </select>
    </div>
    <div class="full">
        <button id="territory_add_rule" class="btn secondary" type="button">Tambah Rule Wilayah</button>
        <p class="muted" style="margin:8px 0 0;">Contoh: include `DKI Jakarta`, include `Banten`, exclude `DKI Jakarta > Jakarta Barat > Taman Sari > Mangga Besar`.</p>
    </div>
    <div class="full">
        <label>Rule Wilayah Aktif</label>
        <div id="territory_rule_list" class="rule-list"></div>
    </div>
    <div>
        <label for="spv_id">SPV</label>
        <select id="spv_id" name="spv_id">
            <option value="">- Pilih SPV -</option>
            @foreach($spvs as $spv)
                <option value="{{ $spv->id }}" @selected(old('spv_id', $employee->spv_id) === $spv->id)>{{ $spv->full_name }}</option>
            @endforeach
        </select>
    </div>
    <div>
        <label for="management_id">Management</label>
        <select id="management_id" name="management_id">
            <option value="">- Pilih Management -</option>
            @foreach($managements as $management)
                <option value="{{ $management->id }}" @selected(old('management_id', $employee->management_id) === $management->id)>{{ $management->full_name }}</option>
            @endforeach
        </select>
    </div>
    <div>
        <label for="leave_balance_days">Saldo Cuti</label>
        <input id="leave_balance_days" name="leave_balance_days" type="number" step="0.5" min="0" value="{{ old('leave_balance_days', $employee->leave_balance_days ?? 12) }}" required>
    </div>
    <div>
        <label for="joined_at">Tanggal Bergabung</label>
        <input id="joined_at" name="joined_at" type="date" value="{{ old('joined_at', optional($employee->joined_at)->format('Y-m-d')) }}">
    </div>
    <div>
        <label for="emergency_contact_name">Kontak Darurat</label>
        <input id="emergency_contact_name" name="emergency_contact_name" value="{{ old('emergency_contact_name', $employee->emergency_contact_name) }}">
    </div>
    <div>
        <label for="emergency_contact_phone">No. Kontak Darurat</label>
        <input id="emergency_contact_phone" name="emergency_contact_phone" value="{{ old('emergency_contact_phone', $employee->emergency_contact_phone) }}">
    </div>
    <div class="full">
        <label for="address">Alamat</label>
        <textarea id="address" name="address" rows="3">{{ old('address', $employee->address) }}</textarea>
    </div>
    <div>
        <label for="password">{{ $method === 'POST' ? 'Password Awal' : 'Password Baru (opsional)' }}</label>
        <input id="password" name="password" type="password">
    </div>
    <div>
        <label for="is_active">Status</label>
        <select id="is_active" name="is_active">
            <option value="1" @selected(old('is_active', $employee->is_active ? '1' : '0') === '1')>Aktif</option>
            <option value="0" @selected(old('is_active', $employee->is_active ? '1' : '0') === '0')>Nonaktif</option>
        </select>
    </div>
</div>
<div class="actions" style="margin-top:20px;">
    <button type="submit" class="btn primary">Simpan Data Karyawan</button>
    <a href="{{ route('admin.employees.index') }}" class="btn secondary">Kembali</a>
</div>

<script>
    (() => {
        const scopeInput = document.getElementById('territory_scope');
        const areaInput = document.getElementById('area_name');
        const attendanceWorkAreaInput = document.getElementById('attendance_work_area_id');
        const workLocationInput = document.getElementById('work_location');
        const payloadInput = document.getElementById('territory_rules_payload');
        const ruleTypeInput = document.getElementById('territory_rule_type');
        const provinceInput = document.getElementById('territory_province');
        const cityInput = document.getElementById('territory_city');
        const districtInput = document.getElementById('territory_district');
        const subdistrictInput = document.getElementById('territory_subdistrict');
        const addRuleButton = document.getElementById('territory_add_rule');
        const ruleList = document.getElementById('territory_rule_list');
        const initialRules = Array.isArray(@json($territoryRules)) ? @json($territoryRules) : [];
        const normalizeValue = (value) => (value || '').trim().toLowerCase().replace(/\s+/g, ' ');
        let rules = initialRules
            .filter((item) => item && typeof item === 'object')
            .map((item) => ({
                rule_type: item.rule_type || 'include',
                territory_scope: item.territory_scope || null,
                territory_province: item.territory_province || null,
                territory_city: item.territory_city || null,
                territory_district: item.territory_district || null,
                territory_subdistrict: item.territory_subdistrict || null,
            }));

        const syncWorkLocation = () => {
            const selectedArea = attendanceWorkAreaInput?.selectedOptions[0]?.dataset.name;
            if (workLocationInput && selectedArea) {
                workLocationInput.value = selectedArea;
            }
        };

        attendanceWorkAreaInput?.addEventListener('change', syncWorkLocation);

        const findCanonical = (values, preferred, pickName = (item) => item.name) => {
            if (!preferred) {
                return null;
            }

            const normalizedPreferred = normalizeValue(preferred);
            return values.find((value) => normalizeValue(pickName(value)) === normalizedPreferred) ?? null;
        };

        const replaceOptions = (select, values, { placeholder = null } = {}) => {
            select.innerHTML = '';

            if (placeholder !== null) {
                const option = document.createElement('option');
                option.value = '';
                option.textContent = placeholder;
                select.appendChild(option);
            }

            values.forEach((item) => {
                const option = document.createElement('option');
                option.value = item.name;
                option.textContent = item.name;
                option.dataset.code = item.code;
                select.appendChild(option);
            });
        };

        const selectedCode = (select) => select.selectedOptions[0]?.dataset.code ?? '';
        const selectedName = (select) => {
            const value = select.value?.trim();
            return value ? value : null;
        };

        const requestJson = async (url) => {
            const response = await fetch(url, {
                headers: {
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest',
                },
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const payload = await response.json();
            return Array.isArray(payload.data) ? payload.data : [];
        };

        const inferScope = (rule) => {
            if (rule.territory_subdistrict) {
                return 'subdistrict';
            }
            if (rule.territory_district) {
                return 'district';
            }
            if (rule.territory_city) {
                return 'city';
            }
            if (rule.territory_province) {
                return 'province';
            }
            return null;
        };

        const ruleLabel = (rule) => {
            return [
                rule.territory_province,
                rule.territory_city,
                rule.territory_district,
                rule.territory_subdistrict,
            ].filter(Boolean).join(' > ');
        };

        const summarizeRules = (entries) => {
            const includes = entries.filter((item) => item.rule_type !== 'exclude').map(ruleLabel).filter(Boolean);
            if (includes.length === 0) {
                return '';
            }

            const uniqueIncludes = [...new Set(includes)];
            const includeSummary = uniqueIncludes.length === 1
                ? uniqueIncludes[0]
                : `${uniqueIncludes[0]} +${uniqueIncludes.length - 1} wilayah`;

            const excludes = entries.filter((item) => item.rule_type === 'exclude').map(ruleLabel).filter(Boolean);
            if (excludes.length === 0) {
                return includeSummary;
            }

            const uniqueExcludes = [...new Set(excludes)];
            const excludeSummary = uniqueExcludes.length === 1
                ? uniqueExcludes[0]
                : `${uniqueExcludes[0]} +${uniqueExcludes.length - 1} wilayah`;

            return `${includeSummary} (kecuali ${excludeSummary})`;
        };

        const syncPayloadPreview = () => {
            payloadInput.value = JSON.stringify(rules);
            areaInput.value = summarizeRules(rules);
            const primaryInclude = rules.find((item) => item.rule_type !== 'exclude');
            scopeInput.value = primaryInclude ? (primaryInclude.territory_scope || inferScope(primaryInclude) || '') : '';
        };

        const renderRules = () => {
            ruleList.innerHTML = '';

            if (rules.length === 0) {
                const empty = document.createElement('div');
                empty.className = 'muted';
                empty.textContent = 'Belum ada rule wilayah. Tambahkan minimal satu rule include.';
                ruleList.appendChild(empty);
                syncPayloadPreview();
                return;
            }

            rules.forEach((rule, index) => {
                const item = document.createElement('div');
                item.className = 'rule-chip';
                item.innerHTML = `
                    <div>
                        <strong>${rule.rule_type === 'exclude' ? 'Exclude' : 'Include'}</strong>
                        <div class="muted">${ruleLabel(rule) || 'Rule belum lengkap'}</div>
                    </div>
                    <button type="button" class="btn secondary rule-remove" data-index="${index}">Hapus</button>
                `;
                ruleList.appendChild(item);
            });

            ruleList.querySelectorAll('.rule-remove').forEach((button) => {
                button.addEventListener('click', () => {
                    const index = Number(button.dataset.index);
                    rules.splice(index, 1);
                    renderRules();
                });
            });

            syncPayloadPreview();
        };

        const setSelectValue = (select, preferred, items) => {
            const canonical = findCanonical(items, preferred);
            select.value = canonical?.name ?? '';
        };

        const loadProvinces = async (preferred = null) => {
            const provinces = await requestJson('/api/territories/provinces');
            replaceOptions(provinceInput, provinces, { placeholder: '- Pilih Provinsi -' });
            setSelectValue(provinceInput, preferred, provinces);
            return provinces;
        };

        const loadCities = async (preferred = null) => {
            const provinceCode = selectedCode(provinceInput);
            const cities = provinceCode
                ? await requestJson(`/api/territories/cities?province_code=${encodeURIComponent(provinceCode)}`)
                : [];
            replaceOptions(cityInput, cities, { placeholder: '- Semua Kota/Kabupaten dalam Provinsi -' });
            setSelectValue(cityInput, preferred, cities);
            cityInput.disabled = !provinceCode;
            return cities;
        };

        const loadDistricts = async (preferred = null) => {
            const cityCode = selectedCode(cityInput);
            const districts = cityCode
                ? await requestJson(`/api/territories/districts?city_code=${encodeURIComponent(cityCode)}`)
                : [];
            replaceOptions(districtInput, districts, { placeholder: '- Semua Kecamatan dalam Kota -' });
            setSelectValue(districtInput, preferred, districts);
            districtInput.disabled = !cityCode;
            return districts;
        };

        const loadSubdistricts = async (preferred = null) => {
            const districtCode = selectedCode(districtInput);
            const subdistricts = districtCode
                ? await requestJson(`/api/territories/subdistricts?district_code=${encodeURIComponent(districtCode)}`)
                : [];
            replaceOptions(subdistrictInput, subdistricts, { placeholder: '- Semua Kelurahan dalam Kecamatan -' });
            setSelectValue(subdistrictInput, preferred, subdistricts);
            subdistrictInput.disabled = !districtCode;
            return subdistricts;
        };

        const resetLower = (selects) => {
            selects.forEach((select) => {
                select.value = '';
                replaceOptions(select, [], { placeholder: select === cityInput
                    ? '- Semua Kota/Kabupaten dalam Provinsi -'
                    : select === districtInput
                        ? '- Semua Kecamatan dalam Kota -'
                        : '- Semua Kelurahan dalam Kecamatan -' });
            });
        };

        provinceInput?.addEventListener('change', async () => {
            resetLower([cityInput, districtInput, subdistrictInput]);
            await loadCities();
            await loadDistricts();
            await loadSubdistricts();
        });

        cityInput?.addEventListener('change', async () => {
            resetLower([districtInput, subdistrictInput]);
            await loadDistricts();
            await loadSubdistricts();
        });

        districtInput?.addEventListener('change', async () => {
            resetLower([subdistrictInput]);
            await loadSubdistricts();
        });

        addRuleButton?.addEventListener('click', () => {
            const rule = {
                rule_type: ruleTypeInput.value === 'exclude' ? 'exclude' : 'include',
                territory_scope: null,
                territory_province: selectedName(provinceInput),
                territory_city: selectedName(cityInput),
                territory_district: selectedName(districtInput),
                territory_subdistrict: selectedName(subdistrictInput),
            };

            rule.territory_scope = inferScope(rule);

            if (!rule.territory_province || !rule.territory_scope) {
                window.alert('Pilih minimal provinsi sebelum menambahkan rule wilayah.');
                return;
            }

            const fingerprint = [
                rule.rule_type,
                rule.territory_scope,
                rule.territory_province || '',
                rule.territory_city || '',
                rule.territory_district || '',
                rule.territory_subdistrict || '',
            ].join('|');

            const exists = rules.some((item) => [
                item.rule_type || 'include',
                item.territory_scope || '',
                item.territory_province || '',
                item.territory_city || '',
                item.territory_district || '',
                item.territory_subdistrict || '',
            ].join('|') === fingerprint);

            if (exists) {
                window.alert('Rule wilayah ini sudah ada.');
                return;
            }

            rules.push(rule);
            renderRules();
        });

        const bootstrap = async () => {
            await loadProvinces(rules[0]?.territory_province || null);
            await loadCities(rules[0]?.territory_city || null);
            await loadDistricts(rules[0]?.territory_district || null);
            await loadSubdistricts(rules[0]?.territory_subdistrict || null);
            syncWorkLocation();
            renderRules();
        };

        bootstrap().catch((error) => {
            console.error('territory form load failed', error);
        });
    })();
</script>

<style>
    .rule-list {
        display: grid;
        gap: 10px;
    }
    .rule-chip {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 12px;
        padding: 12px 14px;
        border: 1px solid #E7E5E4;
        border-radius: 14px;
        background: #FFF;
    }
</style>
