<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\ApprovalStep;
use App\Services\Admin\AdminExportService;
use App\Support\Workflow\UserRole;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ApprovalCenterController extends Controller
{
    public function index(Request $request, AdminExportService $exportService): View|StreamedResponse
    {
        $filters = $request->validate([
            'module' => ['nullable', 'string'],
            'status' => ['nullable', 'string'],
            'approver_role' => ['nullable', 'string'],
            'search' => ['nullable', 'string'],
        ]);

        $query = ApprovalStep::query()
            ->with(['leaveRequest', 'wfaRequest'])
            ->when($filters['module'] ?? null, fn ($builder, string $module) => $builder->where('module', $module))
            ->when($filters['status'] ?? null, fn ($builder, string $status) => $builder->where('status', $status))
            ->when($filters['approver_role'] ?? null, fn ($builder, string $role) => $builder->where('approver_role', $role))
            ->when($filters['search'] ?? null, function ($builder, string $search) {
                $builder->where(function ($query) use ($search) {
                    $query->where('approver_name', 'like', '%' . $search . '%')
                        ->orWhere('reference_id', 'like', '%' . $search . '%');
                });
            })
            ->orderByDesc('updated_at');

        $summary = $this->buildSummary(clone $query);

        if ($request->string('export')->value() === 'csv') {
            $rows = $query->get()->map(function (ApprovalStep $step): array {
                $reference = $step->module === 'leave' ? $step->leaveRequest : $step->wfaRequest;

                return [
                    $step->module,
                    $step->reference_id,
                    $reference?->requester_name ?? '-',
                    $reference?->requester_role ?? '-',
                    $step->approver_name,
                    $step->approver_role,
                    $step->status,
                    $step->note,
                    optional($step->acted_at)->format('Y-m-d H:i'),
                ];
            });

            return $exportService->streamCsv(
                'approval-center.csv',
                ['Module', 'Reference ID', 'Requester', 'Requester Role', 'Approver', 'Approver Role', 'Status', 'Note', 'Acted At'],
                $rows,
            );
        }

        return view('admin.approvals.index', [
            'steps' => $query->paginate(20)->withQueryString(),
            'summary' => $summary,
            'filters' => $filters,
            'modules' => [
                'leave' => 'Cuti / Izin',
                'wfa' => 'WFA',
            ],
            'statuses' => ['pending', 'approved', 'rejected'],
            'approverRoles' => $this->roleOptions(),
        ]);
    }

    /**
     * @return array{total:int,pending:int,approved:int,rejected:int,leave:int,wfa:int}
     */
    private function buildSummary(Builder $query): array
    {
        return [
            'total' => (clone $query)->count(),
            'pending' => (clone $query)->where('status', 'pending')->count(),
            'approved' => (clone $query)->where('status', 'approved')->count(),
            'rejected' => (clone $query)->where('status', 'rejected')->count(),
            'leave' => (clone $query)->where('module', 'leave')->count(),
            'wfa' => (clone $query)->where('module', 'wfa')->count(),
        ];
    }

    /**
     * @return array<string, string>
     */
    private function roleOptions(): array
    {
        return [
            UserRole::SPV => 'Supervisor',
            UserRole::AREA_MANAGER => 'Area Manager',
            UserRole::MANAGEMENT => 'Management',
        ];
    }
}
