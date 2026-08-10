<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\WfaRequest;
use App\Services\Admin\AdminExportService;
use App\Services\Admin\AdminMetricsService;
use App\Support\Workflow\UserRole;
use Illuminate\Http\Request;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class WfaMonitoringController extends Controller
{
    public function index(Request $request, AdminExportService $exportService): View|StreamedResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string'],
            'role' => ['nullable', 'string'],
            'status' => ['nullable', 'string'],
            'mode' => ['nullable', 'string'],
        ]);

        $query = WfaRequest::query()
            ->with(['approvalSteps', 'taskUpdates.attachments'])
            ->when($filters['search'] ?? null, function ($builder, string $search) {
                $builder->where(function ($query) use ($search) {
                    $query->where('requester_name', 'like', '%' . $search . '%')
                        ->orWhere('id', 'like', '%' . $search . '%')
                        ->orWhere('location_label', 'like', '%' . $search . '%');
                });
            })
            ->when($filters['role'] ?? null, fn ($builder, string $role) => $builder->where('requester_role', $role))
            ->when($filters['status'] ?? null, fn ($builder, string $status) => $builder->where('status', $status))
            ->when($filters['mode'] ?? null, fn ($builder, string $mode) => $builder->where('mode', $mode))
            ->latest('submitted_at');

        $summary = $this->buildSummary(clone $query);

        if ($request->string('export')->value() === 'csv') {
            $rows = $query->get()->map(function (WfaRequest $request): array {
                return [
                    $request->id,
                    $request->requester_name,
                    UserRole::label($request->requester_role),
                    $request->mode,
                    $request->status,
                    $request->work_date?->format('Y-m-d'),
                    $request->start_time,
                    $request->end_time,
                    $request->location_label,
                    $request->compensation_mode,
                    (string) $request->taskUpdates->count(),
                ];
            });

            return $exportService->streamCsv(
                'wfa-monitoring.csv',
                ['ID', 'Karyawan', 'Role', 'Mode', 'Status', 'Tanggal', 'Mulai', 'Selesai', 'Lokasi', 'Kompensasi', 'Task Updates'],
                $rows,
            );
        }

        return view('admin.wfa.index', [
            'requests' => $query->paginate(20)->withQueryString(),
            'summary' => $summary,
            'roles' => $this->roleOptions(),
            'filters' => $filters,
            'statuses' => ['pending', 'approved', 'rejected', 'active', 'completed', 'cancelled', 'draft'],
            'modes' => [
                'regular' => 'WFA Reguler',
                'overtime' => 'WFA Overtime',
            ],
        ]);
    }

    public function show(WfaRequest $requestRecord, AdminMetricsService $metricsService): View
    {
        $requestRecord->load(['requester', 'approvalSteps', 'taskUpdates.attachments']);

        return view('admin.wfa.show', [
            'requestRecord' => $requestRecord,
            'requesterMetrics' => $requestRecord->requester ? $metricsService->employeeSummary($requestRecord->requester) : null,
        ]);
    }

    /**
     * @return array{total:int,pending:int,overtime:int,active:int,completed:int}
     */
    private function buildSummary(Builder $query): array
    {
        return [
            'total' => (clone $query)->count(),
            'pending' => (clone $query)->where('status', 'pending')->count(),
            'overtime' => (clone $query)->where('mode', 'overtime')->count(),
            'active' => (clone $query)->where('status', 'active')->count(),
            'completed' => (clone $query)->where('status', 'completed')->count(),
        ];
    }

    /**
     * @return array<string, string>
     */
    private function roleOptions(): array
    {
        return UserRole::adminOptions();
    }
}
