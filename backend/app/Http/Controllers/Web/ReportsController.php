<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\AttendanceRecord;
use App\Models\LeaveRequest;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Models\WfaRequest;
use App\Services\Admin\AdminExportService;
use App\Services\Admin\AdminMetricsService;
use App\Support\Workflow\UserRole;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportsController extends Controller
{
    public function index(Request $request, AdminExportService $exportService, AdminMetricsService $metricsService): View|StreamedResponse
    {
        $filters = $request->validate([
            'date_from' => ['nullable', 'date'],
            'date_until' => ['nullable', 'date'],
            'role' => ['nullable', 'string'],
        ]);

        $employeeQuery = User::query()
            ->where('role', '!=', UserRole::HR)
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('role', $role))
            ->orderBy('full_name');

        $leaveQuery = LeaveRequest::query()
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('requester_role', $role))
            ->when($filters['date_from'] ?? null, fn ($query, string $dateFrom) => $query->whereDate('start_at', '>=', $dateFrom))
            ->when($filters['date_until'] ?? null, fn ($query, string $dateUntil) => $query->whereDate('end_at', '<=', $dateUntil));

        $wfaQuery = WfaRequest::query()
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('requester_role', $role))
            ->when($filters['date_from'] ?? null, fn ($query, string $dateFrom) => $query->whereDate('work_date', '>=', $dateFrom))
            ->when($filters['date_until'] ?? null, fn ($query, string $dateUntil) => $query->whereDate('work_date', '<=', $dateUntil));

        $attendanceQuery = AttendanceRecord::query()
            ->with('user')
            ->when($filters['role'] ?? null, function ($query, string $role) {
                $query->whereHas('user', fn ($builder) => $builder->where('role', $role));
            })
            ->when($filters['date_from'] ?? null, fn ($query, string $dateFrom) => $query->whereDate('work_date', '>=', $dateFrom))
            ->when($filters['date_until'] ?? null, fn ($query, string $dateUntil) => $query->whereDate('work_date', '<=', $dateUntil));

        $networkQuery = NetworkProfile::query()
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('owner_role', $role));

        if ($request->string('export')->value() === 'csv') {
            $rows = $employeeQuery->get()->map(function (User $employee) use ($metricsService): array {
                $employeeMetrics = $metricsService->employeeSummary($employee);

                return [
                    $employee->employee_code,
                    $employee->full_name,
                    UserRole::label($employee->role),
                    number_format((float) $employeeMetrics['leave_balance_days'], 1, '.', ''),
                    $employeeMetrics['attendance_days'],
                    $metricsService->formatMinutes($employeeMetrics['total_work_minutes']),
                    $employeeMetrics['leave_requests_count'],
                    $employeeMetrics['wfa_requests_count'],
                ];
            });

            return $exportService->streamCsv(
                'hr-report-summary.csv',
                ['Kode', 'Nama', 'Role', 'Saldo Cuti', 'Hari Absensi', 'Total Jam Kerja', 'Total Cuti', 'Total WFA'],
                $rows,
            );
        }

        return view('admin.reports.index', [
            'filters' => $filters,
            'roles' => UserRole::adminOptions(),
            'summary' => [
                'employees' => (clone $employeeQuery)->count(),
                'activeEmployees' => (clone $employeeQuery)->where('is_active', true)->count(),
                'leaveRequests' => (clone $leaveQuery)->count(),
                'approvedLeaves' => (clone $leaveQuery)->where('status', 'approved')->count(),
                'wfaRequests' => (clone $wfaQuery)->count(),
                'overtimeWfa' => (clone $wfaQuery)->where('mode', 'overtime')->count(),
                'attendanceRecords' => (clone $attendanceQuery)->count(),
                'networkProfiles' => (clone $networkQuery)->count(),
            ],
            'topEmployees' => $employeeQuery->limit(10)->get()->map(function (User $employee) use ($metricsService) {
                return [
                    'employee' => $employee,
                    'metrics' => $metricsService->employeeSummary($employee),
                ];
            }),
            'recentApprovals' => collect()
                ->concat((clone $leaveQuery)->latest('submitted_at')->limit(5)->get()->map(fn ($leave) => ['module' => 'leave', 'record' => $leave]))
                ->concat((clone $wfaQuery)->latest('submitted_at')->limit(5)->get()->map(fn ($wfa) => ['module' => 'wfa', 'record' => $wfa]))
                ->sortByDesc(fn (array $item) => $item['record']->submitted_at ?? $item['record']->work_date)
                ->take(8)
                ->values(),
        ]);
    }
}
