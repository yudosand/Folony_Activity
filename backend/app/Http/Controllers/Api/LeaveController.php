<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Leave\StoreLeaveRequest;
use App\Http\Requests\Leave\UpdateLeaveStatusRequest;
use App\Models\ApprovalStep;
use App\Models\LeaveRequest;
use App\Models\User;
use App\Services\ApprovalFlowService;
use App\Services\LeaveService;
use App\Support\Api\ApiListResponse;
use App\Support\Workflow\WorkflowApiData;
use App\Support\Workflow\WorkflowModule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LeaveController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $requester = $request->user();
        $query = LeaveRequest::query()
            ->with('approvalSteps')
            ->orderByDesc('submitted_at');

        if ($requester != null) {
            $query->where('requester_id', $requester->id);
        } elseif ($request->filled('user_id')) {
            $query->where('requester_id', $request->string('user_id')->toString());
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        return ApiListResponse::fromQuery(
            $request,
            $query,
            fn (LeaveRequest $leaveRequest) => WorkflowApiData::leave($leaveRequest),
        );
    }

    public function approvals(Request $request, ApprovalFlowService $approvalFlowService): JsonResponse
    {
        $approverId = $request->user()?->id ?? $request->string('approver_id')->toString();
        abort_if($approverId === '', 422, 'approver_id wajib diisi.');

        $steps = $approvalFlowService->inboxForApprover($approverId, WorkflowModule::LEAVE);

        return ApiListResponse::fromCollection(
            $request,
            $steps->filter(fn (ApprovalStep $step) => $step->module === WorkflowModule::LEAVE && $step->leaveRequest),
            fn (ApprovalStep $step) => WorkflowApiData::leave($step->leaveRequest),
        );
    }

    public function store(StoreLeaveRequest $request, LeaveService $leaveService): JsonResponse
    {
        $requester = $request->user() instanceof User
            ? $request->user()->loadMissing(['spv', 'management'])
            : User::query()
                ->with(['spv', 'management'])
                ->findOrFail($request->string('requester_id')->toString());

        $leaveRequest = $leaveService->create($request->validated(), $requester);

        return response()->json([
            'data' => WorkflowApiData::leave($leaveRequest),
        ], 201);
    }

    public function updateStatus(UpdateLeaveStatusRequest $request, LeaveRequest $leaveRequest, LeaveService $leaveService): JsonResponse
    {
        $leaveRequest = $leaveService->updateStatus($leaveRequest, $request->validated());

        return response()->json([
            'data' => WorkflowApiData::leave($leaveRequest),
        ]);
    }
}
