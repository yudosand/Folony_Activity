<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Approval\ApproveApprovalRequest;
use App\Http\Requests\Approval\RejectApprovalRequest;
use App\Models\ApprovalStep;
use App\Models\User;
use App\Services\ApprovalFlowService;
use App\Support\Api\ApiListResponse;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ApprovalController extends Controller
{
    public function index(Request $request, ApprovalFlowService $approvalFlowService): JsonResponse
    {
        $approverId = $request->user()?->id ?? $request->string('approver_id')->toString();
        abort_if($approverId === '', 422, 'approver_id wajib diisi.');

        $module = $request->filled('module') ? $request->string('module')->toString() : null;
        $steps = $approvalFlowService->inboxForApprover($approverId, $module);

        return ApiListResponse::fromCollection(
            $request,
            $steps,
            fn (ApprovalStep $step) => WorkflowApiData::approvalInboxItem($step),
        );
    }

    public function approve(ApproveApprovalRequest $request, string $approvalIdentifier, ApprovalFlowService $approvalFlowService): JsonResponse
    {
        $actor = $request->user() instanceof User
            ? $request->user()
            : User::query()->findOrFail($request->string('approver_id')->toString());
        $step = $approvalFlowService->approve(
            $approvalFlowService->resolveStep($approvalIdentifier, $actor->id),
            $actor,
            $request->input('note'),
        );

        return response()->json([
            'data' => WorkflowApiData::approvalInboxItem($step),
        ]);
    }

    public function reject(RejectApprovalRequest $request, string $approvalIdentifier, ApprovalFlowService $approvalFlowService): JsonResponse
    {
        $actor = $request->user() instanceof User
            ? $request->user()
            : User::query()->findOrFail($request->string('approver_id')->toString());
        $step = $approvalFlowService->reject(
            $approvalFlowService->resolveStep($approvalIdentifier, $actor->id),
            $actor,
            $request->string('note')->toString(),
        );

        return response()->json([
            'data' => WorkflowApiData::approvalInboxItem($step),
        ]);
    }
}
