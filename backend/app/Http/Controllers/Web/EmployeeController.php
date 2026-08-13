<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\ApprovalStep;
use App\Models\LeaveRequest;
use App\Models\AttendanceRecord;
use App\Models\AttendanceWorkArea;
use App\Models\User;
use App\Models\WfaRequest;
use App\Services\Admin\AdminMetricsService;
use App\Services\Admin\AdminExportService;
use App\Services\AttendanceSummaryService;
use App\Services\PerformanceTargetService;
use App\Support\Performance\PerformanceMetric;
use App\Support\Territory\TerritoryData;
use App\Support\Territory\TerritoryRuleType;
use App\Support\Territory\TerritoryScope;
use App\Support\Workflow\UserRole;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class EmployeeController extends Controller
{
    public function index(Request $request, AdminMetricsService $metricsService, AdminExportService $exportService): View|StreamedResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string'],
            'role' => ['nullable', 'string'],
            'status' => ['nullable', 'string'],
        ]);

        $query = User::query()
            ->where('role', '!=', UserRole::HR)
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(function ($builder) use ($search) {
                    $builder->where('full_name', 'like', '%' . $search . '%')
                        ->orWhere('employee_code', 'like', '%' . $search . '%')
                        ->orWhere('phone_number', 'like', '%' . $search . '%');
                });
            })
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('role', $role))
            ->when($filters['status'] ?? null, function ($query, string $status) {
                if ($status === 'active') {
                    $query->where('is_active', true);
                }
                if ($status === 'inactive') {
                    $query->where('is_active', false);
                }
            })
            ->orderBy('full_name');

        if ($request->string('export')->value() === 'csv') {
            $rows = $query->get()->map(function (User $user) use ($metricsService): array {
                $metrics = $metricsService->employeeSummary($user);

                return [
                    $user->employee_code,
                    $user->full_name,
                    UserRole::label($user->role),
                    $user->job_title,
                    $user->work_location,
                    $user->phone_number,
                    $user->email,
                    number_format((float) $metrics['leave_balance_days'], 1, '.', ''),
                    $metricsService->formatMinutes($metrics['total_work_minutes']),
                ];
            });

            return $exportService->streamCsv(
                'employees.csv',
                ['Kode', 'Nama', 'Role', 'Jabatan', 'Lokasi Kerja', 'No HP', 'Email', 'Saldo Cuti', 'Total Jam Kerja'],
                $rows,
            );
        }

        $employees = $query->paginate(12)->withQueryString();

        $employeeMetrics = $employees->getCollection()->mapWithKeys(
            fn (User $user) => [$user->id => $metricsService->employeeSummary($user)]
        );

        return view('admin.employees.index', [
            'employees' => $employees,
            'employeeMetrics' => $employeeMetrics,
            'roles' => UserRole::adminOptions(),
            'filters' => $filters,
        ]);
    }

    public function create(): View
    {
        return view('admin.employees.create', [
            'employee' => new User([
                'is_active' => true,
                'leave_balance_days' => 12,
            ]),
            'roles' => UserRole::adminOptions(),
            'attendanceWorkAreas' => AttendanceWorkArea::query()->where('is_active', true)->orderBy('name')->get(),
            'spvs' => User::query()->where('role', UserRole::SPV)->orderBy('full_name')->get(),
            'managements' => User::query()->where('role', UserRole::MANAGEMENT)->orderBy('full_name')->get(),
            'action' => route('admin.employees.store'),
            'method' => 'POST',
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $payload = $this->validatedPayload($request);
        if (in_array($payload['role'], [UserRole::FGG, UserRole::AREA_MANAGER], true)) {
            $payload = TerritoryData::syncAssignmentPayload($payload);
        }
        $payload['id'] = $payload['employee_code'];
        $payload['password'] = $payload['password'];

        User::query()->create($payload);

        return redirect()
            ->route('admin.employees.index')
            ->with('status', 'Karyawan baru berhasil ditambahkan.');
    }

    public function show(
        Request $request,
        User $employee,
        AdminMetricsService $metricsService,
        PerformanceTargetService $performanceTargetService,
        AttendanceSummaryService $attendanceSummaryService,
    ): View
    {
        abort_if($employee->role === UserRole::HR, 404);

        $recentAttendance = $employee->attendanceRecords()
            ->latest('recorded_at')
            ->limit(8)
            ->get();

        return view('admin.employees.show', [
            'employee' => $employee->load(['spv', 'management']),
            'metrics' => $metricsService->employeeSummary($employee),
            'recentLeaves' => LeaveRequest::query()
                ->where('requester_id', $employee->id)
                ->latest('submitted_at')
                ->limit(5)
                ->get(),
            'recentWfas' => WfaRequest::query()
                ->where('requester_id', $employee->id)
                ->with('approvalSteps')
                ->latest('submitted_at')
                ->limit(5)
                ->get(),
            'recentAttendance' => $recentAttendance,
            'recentAttendanceSummaries' => $this->attendanceSummariesForRecords(
                $attendanceSummaryService,
                $recentAttendance,
                $employee,
            ),
            'recentApprovals' => ApprovalStep::query()
                ->where(function ($query) use ($employee) {
                    $query->whereHas('leaveRequest', fn ($builder) => $builder->where('requester_id', $employee->id))
                        ->orWhereHas('wfaRequest', fn ($builder) => $builder->where('requester_id', $employee->id));
                })
                ->with(['leaveRequest', 'wfaRequest'])
                ->orderByDesc('updated_at')
                ->limit(8)
                ->get(),
            'formattedWorkHours' => $metricsService->formatMinutes($metricsService->employeeSummary($employee)['total_work_minutes']),
            'performanceTargetDefinitions' => $performanceTargetService->metricDefinitionsForRole($employee->role),
            'performanceTargetValues' => $performanceTargetService->targetValuesForUser($employee),
            'performanceTargetSummary' => $performanceTargetService->summaryForUser($employee),
        ]);
    }

    public function edit(User $employee): View
    {
        abort_if($employee->role === UserRole::HR, 404);

        return view('admin.employees.edit', [
            'employee' => $employee,
            'roles' => UserRole::adminOptions(),
            'attendanceWorkAreas' => AttendanceWorkArea::query()->where('is_active', true)->orderBy('name')->get(),
            'spvs' => User::query()->where('role', UserRole::SPV)->orderBy('full_name')->get(),
            'managements' => User::query()->where('role', UserRole::MANAGEMENT)->orderBy('full_name')->get(),
            'action' => route('admin.employees.update', $employee),
            'method' => 'PUT',
        ]);
    }

    public function update(Request $request, User $employee): RedirectResponse
    {
        abort_if($employee->role === UserRole::HR, 404);

        $payload = $this->validatedPayload($request, $employee);
        if (in_array($payload['role'], [UserRole::FGG, UserRole::AREA_MANAGER], true)) {
            $payload = TerritoryData::syncAssignmentPayload($payload);
        }
        if (blank($payload['password'] ?? null)) {
            unset($payload['password']);
        }

        $employee->update($payload);

        return redirect()
            ->route('admin.employees.show', $employee)
            ->with('status', 'Data karyawan berhasil diperbarui.');
    }

    public function updatePerformanceTargets(
        Request $request,
        User $employee,
        PerformanceTargetService $performanceTargetService,
    ): RedirectResponse {
        abort_if($employee->role === UserRole::HR, 404);

        $allowedMetrics = PerformanceMetric::forRole($employee->role);
        if ($allowedMetrics === []) {
            return redirect()
                ->route('admin.employees.show', $employee)
                ->with('status', 'Role ini belum memakai target aktif.');
        }

        $validated = $request->validate([
            'targets' => ['nullable', 'array'],
            'targets.*' => ['nullable', 'integer', 'min:0', 'max:1000000'],
        ]);

        $targets = array_intersect_key(
            $validated['targets'] ?? [],
            array_flip($allowedMetrics),
        );

        $performanceTargetService->upsertTargets(
            $employee,
            $request->user(),
            $targets,
        );

        return redirect()
            ->route('admin.employees.show', $employee)
            ->with('status', 'Target aktif berhasil diperbarui.');
    }

    private function attendanceSummariesForRecords(
        AttendanceSummaryService $attendanceSummaryService,
        Collection $records,
        User $employee,
    ): array {
        $cache = [];

        foreach ($records as $record) {
            if (! $record instanceof AttendanceRecord || ! $record->work_date) {
                continue;
            }

            $key = $record->user_id . '|' . $record->work_date->toDateString();
            if (array_key_exists($key, $cache)) {
                continue;
            }

            $cache[$key] = $attendanceSummaryService->summarize(
                $employee,
                Carbon::parse($record->work_date)->startOfDay(),
            );
        }

        return $cache;
    }

    private function validatedPayload(Request $request, ?User $employee = null): array
    {
        $employeeId = $employee?->id;

        $payload = $request->validate([
            'employee_code' => [
                'required',
                'string',
                'max:32',
                Rule::unique('users', 'employee_code')->ignore($employeeId, 'id'),
            ],
            'full_name' => ['required', 'string', 'max:255'],
            'phone_number' => ['nullable', 'string', 'max:32'],
            'email' => ['nullable', 'email', 'max:255', Rule::unique('users', 'email')->ignore($employeeId, 'id')],
            'role' => ['required', Rule::in(array_values(array_filter(UserRole::ALL, fn (string $role) => $role !== UserRole::HR)))],
            'job_title' => ['nullable', 'string', 'max:255'],
            'area_name' => ['nullable', 'string', 'max:255'],
            'work_location' => ['nullable', 'string', 'max:255'],
            'attendance_work_area_id' => ['required', 'string', 'exists:attendance_work_areas,id'],
            'office_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'office_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'attendance_radius_meters' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'territory_province' => ['nullable', 'string', 'max:255'],
            'territory_city' => ['nullable', 'string', 'max:255'],
            'territory_scope' => ['nullable', Rule::in(TerritoryScope::ALL)],
            'territory_rules_payload' => ['nullable', 'string'],
            'territory_districts' => ['nullable', 'array'],
            'territory_districts.*' => ['nullable', 'string', 'max:255'],
            'territory_subdistricts' => ['nullable', 'array'],
            'territory_subdistricts.*' => ['nullable', 'string', 'max:255'],
            'territory_district' => ['nullable', 'string', 'max:255'],
            'territory_subdistrict' => ['nullable', 'string', 'max:255'],
            'spv_id' => ['nullable', 'string', 'exists:users,id'],
            'management_id' => ['nullable', 'string', 'exists:users,id'],
            'leave_balance_days' => ['required', 'numeric', 'min:0', 'max:365'],
            'joined_at' => ['nullable', 'date'],
            'address' => ['nullable', 'string'],
            'emergency_contact_name' => ['nullable', 'string', 'max:255'],
            'emergency_contact_phone' => ['nullable', 'string', 'max:32'],
            'is_active' => ['nullable', 'boolean'],
            'password' => [$employee ? 'nullable' : 'required', 'string', 'min:6'],
        ]);

        if (blank($payload['spv_id'] ?? null) && blank($payload['management_id'] ?? null)) {
            throw ValidationException::withMessages([
                'spv_id' => 'Minimal isi SPV atau Management sebagai approver.',
                'management_id' => 'Minimal isi SPV atau Management sebagai approver.',
            ]);
        }

        $attendanceWorkArea = AttendanceWorkArea::query()->find($payload['attendance_work_area_id']);
        if ($attendanceWorkArea) {
            $payload['work_location'] = $attendanceWorkArea->name;
        }

        $districts = array_values(array_filter(array_map(
            fn ($value) => is_scalar($value) ? trim((string) $value) : '',
            Arr::wrap($payload['territory_districts'] ?? []),
        )));
        $subdistricts = array_values(array_filter(array_map(
            fn ($value) => is_scalar($value) ? trim((string) $value) : '',
            Arr::wrap($payload['territory_subdistricts'] ?? []),
        )));
        $rawTerritoryRules = is_string($payload['territory_rules_payload'] ?? null)
            ? trim((string) $payload['territory_rules_payload'])
            : '';
        $usesRulePayload = $rawTerritoryRules !== '' && $rawTerritoryRules !== '[]';
        $requiresTerritory = in_array($payload['role'], [UserRole::FGG, UserRole::AREA_MANAGER], true);

        if (! $requiresTerritory && ! $usesRulePayload) {
            return $payload;
        }

        if ($requiresTerritory && ! $usesRulePayload && blank($payload['territory_province'] ?? null)) {
            throw ValidationException::withMessages([
                'territory_province' => 'Provinsi area kerja wajib dipilih untuk FGG dan Area Manager.',
            ]);
        }

        if (($payload['territory_city'] ?? null) !== null && trim((string) $payload['territory_city']) === '') {
            $payload['territory_city'] = null;
        }

        if (! $usesRulePayload && $subdistricts !== [] && count($districts) !== 1) {
            throw ValidationException::withMessages([
                'territory_subdistricts' => 'Kelurahan hanya bisa dipilih jika kecamatan yang dipilih tepat satu.',
            ]);
        }

        if (! $usesRulePayload && $districts !== [] && blank($payload['territory_city'] ?? null)) {
            throw ValidationException::withMessages([
                'territory_city' => 'Pilih kota/kabupaten dulu sebelum memilih kecamatan.',
            ]);
        }

        if (! $usesRulePayload && $subdistricts !== [] && blank($payload['territory_city'] ?? null)) {
            throw ValidationException::withMessages([
                'territory_city' => 'Pilih kota/kabupaten dulu sebelum memilih kelurahan.',
            ]);
        }

        $payload['territory_districts'] = $districts;
        $payload['territory_subdistricts'] = $subdistricts;

        $assignments = $this->territoryAssignmentsFromValidatedPayload(
            $payload,
            $districts,
            $subdistricts,
        );
        if ($requiresTerritory && $assignments === []) {
            throw ValidationException::withMessages([
                'territory_province' => 'Wilayah kerja wajib dipilih minimal sampai provinsi.',
            ]);
        }

        if (($requiresTerritory || $usesRulePayload) && TerritoryData::includeAssignments($assignments) === []) {
            throw ValidationException::withMessages([
                'territory_rules_payload' => 'Minimal harus ada satu rule include untuk area kerja.',
            ]);
        }

        $payload['territory_assignments'] = $assignments;

        $primaryAssignment = TerritoryData::includeAssignments($assignments)[0] ?? [];
        $payload['territory_scope'] = $primaryAssignment['territory_scope'] ?? null;
        $payload['territory_district'] = $primaryAssignment['territory_district'] ?? null;
        $payload['territory_subdistrict'] = $primaryAssignment['territory_subdistrict'] ?? null;

        return $payload;
    }

    private function territoryAssignmentsFromValidatedPayload(
        array $payload,
        array $districts,
        array $subdistricts,
    ): array {
        $rawRules = $payload['territory_rules_payload'] ?? null;
        if (is_string($rawRules) && trim($rawRules) !== '') {
            try {
                $decoded = json_decode($rawRules, true, 512, JSON_THROW_ON_ERROR);
            } catch (\JsonException) {
                throw ValidationException::withMessages([
                    'territory_rules_payload' => 'Format rule wilayah tidak valid.',
                ]);
            }

            if (! is_array($decoded)) {
                throw ValidationException::withMessages([
                    'territory_rules_payload' => 'Format rule wilayah tidak valid.',
                ]);
            }

            $assignments = TerritoryData::rulesFromPayloadArray($decoded);
            if ($assignments === [] && $decoded !== []) {
                throw ValidationException::withMessages([
                    'territory_rules_payload' => 'Rule wilayah tidak bisa dibaca. Periksa kembali pilihan include/exclude dan level wilayah.',
                ]);
            }

            foreach ($assignments as $assignment) {
                if (($assignment['rule_type'] ?? TerritoryRuleType::INCLUDE) === TerritoryRuleType::EXCLUDE
                    && blank($assignment['territory_province'] ?? null)) {
                    throw ValidationException::withMessages([
                        'territory_rules_payload' => 'Rule exclude minimal harus memiliki provinsi.',
                    ]);
                }
            }

            return $assignments;
        }

        $payload['territory_districts'] = $districts;
        $payload['territory_subdistricts'] = $subdistricts;

        return TerritoryData::assignmentsFromPayload($payload);
    }
}
