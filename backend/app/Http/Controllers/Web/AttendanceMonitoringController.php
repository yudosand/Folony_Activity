<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\AttendanceRecord;
use App\Models\AttendanceWorkArea;
use App\Models\LeaveRequest;
use App\Models\User;
use App\Models\WfaRequest;
use App\Services\Admin\AdminExportService;
use App\Services\Admin\AttendanceDailyReport;
use App\Services\AttendanceSummaryService;
use App\Support\Workflow\UserRole;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AttendanceMonitoringController extends Controller
{
    public function index(
        Request $request,
        AdminExportService $exportService,
        AttendanceSummaryService $attendanceSummaryService,
    ): View|StreamedResponse {
        $filters = $request->validate([
            'search' => ['nullable', 'string'],
            'role' => ['nullable', 'string'],
            'decision' => ['nullable', 'string'],
            'date' => ['nullable', 'date'],
            'date_from' => ['nullable', 'date'],
            'date_until' => ['nullable', 'date'],
        ]);

        $query = AttendanceRecord::query()
            ->with('user')
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->whereHas('user', function ($builder) use ($search) {
                    $builder->where('full_name', 'like', '%'.$search.'%')
                        ->orWhere('employee_code', 'like', '%'.$search.'%');
                });
            })
            ->when($filters['role'] ?? null, function ($query, string $role) {
                $query->whereHas('user', fn ($builder) => $builder->where('role', $role));
            })
            ->when($filters['decision'] ?? null, function ($query, string $decision) {
                $query->where('verification->decision', $decision);
            })
            ->when($filters['date'] ?? null, fn ($query, string $date) => $query->whereDate('work_date', $date))
            ->when($filters['date_from'] ?? null, fn ($query, string $dateFrom) => $query->whereDate('work_date', '>=', $dateFrom))
            ->when($filters['date_until'] ?? null, fn ($query, string $dateUntil) => $query->whereDate('work_date', '<=', $dateUntil))
            ->latest('recorded_at');

        $summary = $this->buildSummary(clone $query);

        $dailyReport = app(AttendanceDailyReport::class);
        $dailyQuery = (clone $query)->reorder()->select('user_id', 'work_date')
            ->groupBy('user_id', 'work_date')->orderByDesc('work_date')->orderBy('user_id');
        if ($request->string('export')->value() === 'csv') {
            $rows = $dailyQuery->get()->map(function ($record) use ($dailyReport) {
                $day = $dailyReport->day($record->user_id, $record->work_date->toDateString());

                return [$day['user']?->employee_code, $day['user']?->full_name, $day['date'],
                    $day['check_in']?->format('Y-m-d H:i:s'), $day['check_out']?->format('Y-m-d H:i:s'),
                    $day['duration_label'], $day['open_sessions'] ? 'Belum selesai' : 'Tercatat', $day['records']->count()];
            });

            return $exportService->streamCsv('attendance-monitoring.csv',
                ['Kode', 'Karyawan', 'Tanggal', 'Check-in', 'Check-out', 'Durasi (HH:MM:SS)', 'Sesi', 'Jumlah Catatan'], $rows);
        }
        $days = $dailyQuery->paginate(20)->withQueryString();
        $days->setCollection($days->getCollection()->map(fn ($record) => $dailyReport->day($record->user_id, $record->work_date->toDateString())));
        $attendanceRecap = $this->buildAttendanceRecap(
            $filters,
            $attendanceSummaryService,
        );

        return view('admin.attendance.index', [
            'days' => $days,
            'attendanceRecap' => $attendanceRecap,
            'attendanceWorkAreas' => AttendanceWorkArea::query()->orderBy('name')->get(),
            'summary' => $summary,
            'roles' => UserRole::adminOptions(),
            'decisions' => ['verified', 'retry', 'rejected'],
            'filters' => $filters,
        ]);
    }

    public function show(User $employee, string $date, AttendanceSummaryService $attendanceSummaryService): View
    {
        abort_unless(preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) && checkdate((int) substr($date, 5, 2), (int) substr($date, 8, 2), (int) substr($date, 0, 4)), 404);
        $day = app(AttendanceDailyReport::class)->day($employee->id, $date);
        abort_if($day['records']->isEmpty(), 404);

        return view('admin.attendance.show', ['day' => $day, 'records' => $day['records'],
            'recordSummaries' => $this->summariesForRecords($attendanceSummaryService, $day['records'])]);
    }

    public function storeWorkArea(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:attendance_work_areas,name'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_meters' => ['required', 'integer', 'min:1', 'max:100000'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        AttendanceWorkArea::query()->create([
            'id' => 'work_area_'.Str::uuid(),
            'name' => $validated['name'],
            'latitude' => (float) $validated['latitude'],
            'longitude' => (float) $validated['longitude'],
            'radius_meters' => (int) $validated['radius_meters'],
            'is_active' => (bool) ($validated['is_active'] ?? true),
        ]);

        return redirect()
            ->route('admin.attendance.index')
            ->with('status', 'Area absensi baru berhasil ditambahkan.');
    }

    public function updateWorkArea(Request $request, AttendanceWorkArea $workArea): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('attendance_work_areas', 'name')->ignore($workArea->id, 'id')],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_meters' => ['required', 'integer', 'min:1', 'max:100000'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $workArea->update([
            'name' => $validated['name'],
            'latitude' => (float) $validated['latitude'],
            'longitude' => (float) $validated['longitude'],
            'radius_meters' => (int) $validated['radius_meters'],
            'is_active' => (bool) ($validated['is_active'] ?? false),
        ]);

        User::query()
            ->where('attendance_work_area_id', $workArea->id)
            ->update(['work_location' => $workArea->name]);

        return redirect()
            ->route('admin.attendance.index')
            ->with('status', 'Area absensi berhasil diperbarui.');
    }

    /**
     * @return array{records:int,audited:int,verified:int,retry:int,rejected:int,late:int,check_ins:int,check_outs:int,work_minutes:int}
     */
    private function buildSummary(Builder $query): array
    {
        $records = (clone $query)->get();
        $auditedRecords = $records->filter(
            fn (AttendanceRecord $record) => ($record->verification['decision'] ?? null) !== null
        );

        return [
            'records' => $records->count(),
            'audited' => $auditedRecords->count(),
            'verified' => $auditedRecords->filter(fn (AttendanceRecord $record) => ($record->verification['decision'] ?? null) === 'verified')->count(),
            'retry' => $auditedRecords->filter(fn (AttendanceRecord $record) => ($record->verification['decision'] ?? null) === 'retry')->count(),
            'rejected' => $auditedRecords->filter(fn (AttendanceRecord $record) => ($record->verification['decision'] ?? null) === 'rejected')->count(),
            'late' => $records
                ->filter(fn (AttendanceRecord $record) => $record->action === 'checkIn' && $record->status === 'success' && $record->recorded_at?->format('H:i') > '08:30')
                ->count(),
            'check_ins' => $records->where('action', 'checkIn')->count(),
            'check_outs' => $records->where('action', 'checkOut')->count(),
            'work_minutes' => $this->calculateTotalMinutes($records),
        ];
    }

    private function calculateTotalMinutes(Collection $records): int
    {
        return $records
            ->groupBy(fn (AttendanceRecord $record) => $record->user_id.'|'.$record->work_date?->toDateString())
            ->reduce(function (int $carry, Collection $group): int {
                $first = $group->first();
                $day = app(AttendanceDailyReport::class)->day($first->user_id, $first->work_date->toDateString());

                return $carry + intdiv($day['duration_seconds'] ?? 0, 60);
            }, 0);
    }

    private function summariesForRecords(
        AttendanceSummaryService $attendanceSummaryService,
        Collection $records,
    ): array {
        $cache = [];

        foreach ($records as $record) {
            if (! $record instanceof AttendanceRecord) {
                continue;
            }

            $key = $this->summaryKeyForRecord($record);
            if ($key === null || array_key_exists($key, $cache)) {
                continue;
            }

            $cache[$key] = $this->summaryForRecord($attendanceSummaryService, $record);
        }

        return $cache;
    }

    private function summaryForRecord(
        AttendanceSummaryService $attendanceSummaryService,
        AttendanceRecord $record,
    ): ?array {
        if (! $record->user || ! $record->work_date) {
            return null;
        }

        return $attendanceSummaryService->summarize(
            $record->user,
            Carbon::parse($record->work_date)->startOfDay(),
        );
    }

    private function summaryKeyForRecord(AttendanceRecord $record): ?string
    {
        if (! $record->user_id || ! $record->work_date) {
            return null;
        }

        return $record->user_id.'|'.$record->work_date->toDateString();
    }

    private function actionLabelForRecord(AttendanceRecord $record): string
    {
        return match ($record->action) {
            'checkIn' => 'Checkin',
            'checkOut' => 'Checkout',
            'outsideOfficeStart' => 'Checkin Outside',
            'outsideOfficeFinish' => 'Checkout Outside',
            default => $record->action,
        };
    }

    private function summaryNoteForRecord(AttendanceRecord $record, ?array $summary): ?string
    {
        if (($record->metadata['attendance_mode'] ?? null) === 'outside_office') {
            $placeDescription = trim((string) ($record->metadata['place_description'] ?? ''));

            return $placeDescription !== '' ? $placeDescription : $record->note;
        }

        if ($summary === null) {
            return null;
        }

        if ($record->action === 'checkIn') {
            return $summary['arrival_note'] ?? null;
        }

        if ($record->action === 'checkOut') {
            return $summary['departure_note'] ?? null;
        }

        return null;
    }

    private function buildAttendanceRecap(
        array $filters,
        AttendanceSummaryService $attendanceSummaryService,
    ): ?array {
        $range = $this->resolveRecapRange($filters);
        if ($range === null) {
            return null;
        }

        $employee = $this->resolveEmployeeFromSearch($filters['search'] ?? null);
        if (! $employee) {
            return null;
        }

        [$dateFrom, $dateUntil] = $range;

        $attendanceByDate = AttendanceRecord::query()
            ->where('user_id', $employee->id)
            ->whereBetween('work_date', [$dateFrom->toDateString(), $dateUntil->toDateString()])
            ->orderBy('recorded_at')
            ->get()
            ->groupBy(fn (AttendanceRecord $record) => $record->work_date?->toDateString() ?? '');

        $leaveByDate = [];
        LeaveRequest::query()
            ->where('requester_id', $employee->id)
            ->where('status', WorkflowStatus::APPROVED)
            ->whereDate('start_at', '<=', $dateUntil->toDateString())
            ->whereDate('end_at', '>=', $dateFrom->toDateString())
            ->get()
            ->each(function (LeaveRequest $leave) use (&$leaveByDate, $dateFrom, $dateUntil): void {
                $start = Carbon::parse($leave->start_at)->startOfDay();
                $end = Carbon::parse($leave->end_at)->startOfDay();
                if ($end->lessThan($start)) {
                    $end = $start->copy();
                }

                $cursor = $start->greaterThan($dateFrom) ? $start->copy() : $dateFrom->copy();
                $last = $end->lessThan($dateUntil) ? $end->copy() : $dateUntil->copy();

                while ($cursor->lessThanOrEqualTo($last)) {
                    $leaveByDate[$cursor->toDateString()] = $leave;
                    $cursor->addDay();
                }
            });

        $wfaByDate = WfaRequest::query()
            ->where('requester_id', $employee->id)
            ->whereDate('work_date', '>=', $dateFrom->toDateString())
            ->whereDate('work_date', '<=', $dateUntil->toDateString())
            ->whereIn('status', [
                WorkflowStatus::APPROVED,
                WorkflowStatus::ACTIVE,
                WorkflowStatus::COMPLETED,
            ])
            ->get()
            ->keyBy(fn (WfaRequest $request) => $request->work_date?->toDateString() ?? '');

        $days = [];
        $presentDays = 0;
        $leaveDays = 0;
        $wfaDays = 0;
        $absentDays = 0;

        for ($cursor = $dateFrom->copy(); $cursor->lessThanOrEqualTo($dateUntil); $cursor->addDay()) {
            $dateKey = $cursor->toDateString();
            /** @var Collection<int, AttendanceRecord> $records */
            $records = $attendanceByDate->get($dateKey, collect());
            $successfulCheckIn = $records->first(
                fn (AttendanceRecord $record) => $record->action === 'checkIn' && $record->status === 'success'
            );
            $successfulCheckOut = $records->reverse()->first(
                fn (AttendanceRecord $record) => $record->action === 'checkOut' && $record->status === 'success'
            );

            if ($successfulCheckIn || $successfulCheckOut) {
                $presentDays++;
                $summary = $attendanceSummaryService->summarize($employee, $cursor->copy()->startOfDay());
                $notes = array_values(array_filter([
                    $summary['arrival_note'] ?? null,
                    $summary['departure_note'] ?? null,
                ]));

                $days[] = [
                    'date' => $cursor->copy(),
                    'status_label' => 'Hadir',
                    'check_in' => optional($successfulCheckIn?->recorded_at)->format('H:i') ?: '-',
                    'check_out' => optional($successfulCheckOut?->recorded_at)->format('H:i') ?: '-',
                    'rule_label' => $summary['summary_label'] ?? '-',
                    'note' => $notes === [] ? 'Absensi harian tercatat.' : implode(' / ', $notes),
                ];

                continue;
            }

            $leave = $leaveByDate[$dateKey] ?? null;
            if ($leave instanceof LeaveRequest) {
                $leaveDays++;
                $days[] = [
                    'date' => $cursor->copy(),
                    'status_label' => 'Cuti',
                    'check_in' => '-',
                    'check_out' => '-',
                    'rule_label' => ucfirst((string) $leave->category),
                    'note' => $leave->reason ?: 'Ada approval cuti pada tanggal ini.',
                ];

                continue;
            }

            $wfa = $wfaByDate->get($dateKey);
            if ($wfa instanceof WfaRequest) {
                $wfaDays++;
                $days[] = [
                    'date' => $cursor->copy(),
                    'status_label' => 'WFA',
                    'check_in' => '-',
                    'check_out' => '-',
                    'rule_label' => strtoupper((string) $wfa->mode),
                    'note' => trim(($wfa->reason ?: 'Ada approval WFA pada tanggal ini.').' ('.$wfa->start_time.' - '.$wfa->end_time.')'),
                ];

                continue;
            }

            $absentDays++;
            $days[] = [
                'date' => $cursor->copy(),
                'status_label' => 'Tidak ada absensi',
                'check_in' => '-',
                'check_out' => '-',
                'rule_label' => '-',
                'note' => 'Tidak ada absensi.',
            ];
        }

        return [
            'employee' => $employee,
            'date_from' => $dateFrom,
            'date_until' => $dateUntil,
            'days' => $days,
            'summary' => [
                'present_days' => $presentDays,
                'leave_days' => $leaveDays,
                'wfa_days' => $wfaDays,
                'absent_days' => $absentDays,
            ],
        ];
    }

    private function resolveRecapRange(array $filters): ?array
    {
        if (! empty($filters['date'])) {
            $date = Carbon::parse($filters['date'])->startOfDay();

            return [$date, $date->copy()];
        }

        if (empty($filters['date_from']) || empty($filters['date_until'])) {
            return null;
        }

        $dateFrom = Carbon::parse($filters['date_from'])->startOfDay();
        $dateUntil = Carbon::parse($filters['date_until'])->startOfDay();

        if ($dateUntil->lessThan($dateFrom)) {
            [$dateFrom, $dateUntil] = [$dateUntil, $dateFrom];
        }

        return [$dateFrom, $dateUntil];
    }

    private function resolveEmployeeFromSearch(?string $search): ?User
    {
        $keyword = trim((string) $search);
        if ($keyword === '') {
            return null;
        }

        $exact = User::query()
            ->where('role', '!=', UserRole::HR)
            ->where(function ($query) use ($keyword) {
                $query->where('full_name', $keyword)
                    ->orWhere('employee_code', $keyword);
            })
            ->first();

        if ($exact) {
            return $exact;
        }

        $matched = User::query()
            ->where('role', '!=', UserRole::HR)
            ->where(function ($query) use ($keyword) {
                $query->where('full_name', 'like', '%'.$keyword.'%')
                    ->orWhere('employee_code', 'like', '%'.$keyword.'%');
            })
            ->limit(2)
            ->get();

        return $matched->count() === 1 ? $matched->first() : null;
    }
}
