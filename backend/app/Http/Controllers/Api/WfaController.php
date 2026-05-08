<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Wfa\StoreWfaRequest;
use App\Http\Requests\Wfa\StoreWfaTaskUpdateRequest;
use App\Http\Requests\Wfa\UpdateWfaStatusRequest;
use App\Models\ApprovalStep;
use App\Models\User;
use App\Models\WfaRequest;
use App\Services\ApprovalFlowService;
use App\Services\WfaService;
use App\Support\Api\ApiListResponse;
use App\Support\Workflow\WorkflowApiData;
use App\Support\Workflow\WorkflowModule;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WfaController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $requester = $request->user();
        $query = WfaRequest::query()
            ->with(['approvalSteps', 'taskUpdates.attachments'])
            ->orderByDesc('submitted_at');

        if ($requester != null) {
            $query->where('requester_id', $requester->id);
        } elseif ($request->filled('user_id')) {
            $query->where('requester_id', $request->string('user_id')->toString());
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        if ($request->filled('mode')) {
            $query->where('mode', $request->string('mode')->toString());
        }

        return ApiListResponse::fromQuery(
            $request,
            $query,
            fn (WfaRequest $wfaRequest) => WorkflowApiData::wfa($wfaRequest),
        );
    }

    public function approvals(Request $request, ApprovalFlowService $approvalFlowService): JsonResponse
    {
        $approverId = $request->user()?->id ?? $request->string('approver_id')->toString();
        abort_if($approverId === '', 422, 'approver_id wajib diisi.');

        $steps = $approvalFlowService->inboxForApprover($approverId, WorkflowModule::WFA);

        return ApiListResponse::fromCollection(
            $request,
            $steps->filter(fn (ApprovalStep $step) => $step->module === WorkflowModule::WFA && $step->wfaRequest),
            fn (ApprovalStep $step) => WorkflowApiData::wfa($step->wfaRequest),
        );
    }

    public function store(StoreWfaRequest $request, WfaService $wfaService): JsonResponse
    {
        $requester = $request->user() instanceof User
            ? $request->user()->loadMissing(['spv', 'management'])
            : User::query()
                ->with(['spv', 'management'])
                ->findOrFail($request->string('requester_id')->toString());

        $wfaRequest = $wfaService->create($request->validated(), $requester);

        return response()->json([
            'data' => WorkflowApiData::wfa($wfaRequest),
        ], 201);
    }

    public function updateStatus(UpdateWfaStatusRequest $request, WfaRequest $wfaRequest, WfaService $wfaService): JsonResponse
    {
        $currentStatus = $wfaRequest->status;
        $nextStatus = $request->string('status')->toString();

        abort_if(
            $currentStatus === WorkflowStatus::PENDING && $nextStatus === WorkflowStatus::ACTIVE,
            422,
            'WFA pending tidak bisa langsung aktif.',
        );

        abort_if(
            $currentStatus === WorkflowStatus::REJECTED && $nextStatus === WorkflowStatus::ACTIVE,
            422,
            'WFA rejected tidak bisa diaktifkan.',
        );

        abort_if(
            $currentStatus === WorkflowStatus::COMPLETED && $nextStatus === WorkflowStatus::ACTIVE,
            422,
            'WFA completed tidak bisa kembali aktif.',
        );

        $wfaRequest = $wfaService->updateStatus($wfaRequest, $request->validated());

        return response()->json([
            'data' => WorkflowApiData::wfa($wfaRequest),
        ]);
    }

    public function storeTaskUpdate(StoreWfaTaskUpdateRequest $request, WfaRequest $wfaRequest, WfaService $wfaService): JsonResponse
    {
        abort_if(
            ! in_array($wfaRequest->status, [WorkflowStatus::APPROVED, WorkflowStatus::ACTIVE, WorkflowStatus::COMPLETED], true),
            422,
            'Task update hanya bisa ditambahkan saat WFA sudah approved, active, atau completed.',
        );

        $actor = $request->user() instanceof User
            ? $request->user()
            : User::query()->findOrFail($request->string('actor_id')->toString());
        $wfaRequest = $wfaService->createTaskUpdate($wfaRequest, $actor, $request->validated());

        return response()->json([
            'data' => WorkflowApiData::wfa($wfaRequest),
        ], 201);
    }
}
