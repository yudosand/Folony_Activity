<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\LeaveRequest;
use App\Services\Admin\AdminExportService;
use App\Support\Workflow\UserRole;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class LeaveMonitoringController extends Controller
{
    public function index(Request $request, AdminExportService $exportService): View|StreamedResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string'],
            'role' => ['nullable', 'string'],
            'status' => ['nullable', 'string'],
            'category' => ['nullable', 'string'],
        ]);

        $query = LeaveRequest::query()
            ->with('approvalSteps')
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where('requester_name', 'like', '%' . $search . '%')
                    ->orWhere('id', 'like', '%' . $search . '%');
            })
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('requester_role', $role))
            ->when($filters['status'] ?? null, fn ($query, string $status) => $query->where('status', $status))
            ->when($filters['category'] ?? null, fn ($query, string $category) => $query->where('category', $category))
            ->latest('submitted_at');

        if ($request->string('export')->value() === 'csv') {
            $rows = $query->get()->map(function (LeaveRequest $request): array {
                return [
                    $request->id,
                    $request->requester_name,
                    $request->requester_role,
                    $request->category,
                    $request->status,
                    optional($request->start_at)->format('Y-m-d'),
                    optional($request->end_at)->format('Y-m-d'),
                    (string) $request->duration_value,
                    $request->delegate_to,
                    $request->reason,
                ];
            });

            return $exportService->streamCsv(
                'leave-monitoring.csv',
                ['ID', 'Requester', 'Role', 'Category', 'Status', 'Start', 'End', 'Duration', 'Delegasi', 'Reason'],
                $rows,
            );
        }

        $requests = $query->paginate(20)->withQueryString();

        return view('admin.leaves.index', [
            'requests' => $requests,
            'roles' => array_values(array_filter(UserRole::ALL, fn (string $role) => $role !== UserRole::HR)),
            'filters' => $filters,
            'statuses' => ['pending', 'approved', 'rejected', 'completed', 'cancelled', 'draft'],
            'categories' => ['cuti', 'sakit', 'izinPerJam', 'izinPerHari'],
        ]);
    }
}
