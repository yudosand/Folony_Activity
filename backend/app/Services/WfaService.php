<?php

namespace App\Services;

use App\Models\ApprovalStep;
use App\Models\Attachment;
use App\Models\User;
use App\Models\WfaRequest;
use App\Models\WfaTaskUpdate;
use App\Support\Workflow\ApprovalChainFactory;
use App\Support\Workflow\ApprovalStepStatus;
use App\Support\Workflow\WorkflowModule;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WfaService
{
    public function __construct(
        private readonly ApprovalChainFactory $approvalChainFactory,
        private readonly PushNotificationService $pushNotificationService,
    ) {
    }

    public function create(array $payload, User $requester): WfaRequest
    {
        $wfaRequest = DB::transaction(function () use ($payload, $requester) {
            $wfaRequest = WfaRequest::create([
                'id' => $payload['id'] ?? (string) Str::uuid(),
                'requester_id' => $requester->id,
                'requester_name' => $requester->full_name,
                'requester_role' => $requester->role,
                'mode' => $payload['mode'],
                'compensation_mode' => $payload['compensation_mode'] ?? null,
                'work_date' => $payload['work_date'],
                'start_time' => $payload['start_time'],
                'end_time' => $payload['end_time'],
                'location_label' => $payload['location_label'],
                'reason' => $payload['reason'],
                'initial_task' => $payload['initial_task'],
                'status' => WorkflowStatus::PENDING,
                'note' => $payload['note'] ?? 'Pengajuan WFA dibuat dari mobile.',
                'submitted_at' => now(),
            ]);

            foreach ($this->approvalChainFactory->buildFor($requester) as $step) {
                ApprovalStep::create([
                    'id' => (string) Str::uuid(),
                    'module' => WorkflowModule::WFA,
                    'reference_id' => $wfaRequest->id,
                    'sequence' => $step['sequence'],
                    'approver_role' => $step['approver_role'],
                    'approver_id' => $step['approver_id'],
                    'approver_name' => $step['approver_name'],
                    'status' => ApprovalStepStatus::PENDING,
                ]);
            }

            if ($wfaRequest->approvalSteps()->count() === 0) {
                $wfaRequest->update(['status' => WorkflowStatus::APPROVED]);
            }

            return $this->findById($wfaRequest->id);
        });

        $this->pushNotificationService->notifyPendingApproversForWfa($wfaRequest);

        return $wfaRequest;
    }

    public function updateStatus(WfaRequest $wfaRequest, array $payload): WfaRequest
    {
        $wfaRequest->update([
            'status' => $payload['status'],
            'actual_start_at' => $payload['actual_start_at'] ?? $wfaRequest->actual_start_at,
            'actual_end_at' => $payload['actual_end_at'] ?? $wfaRequest->actual_end_at,
            'note' => $payload['note'] ?? $wfaRequest->note,
        ]);

        return $this->findById($wfaRequest->id);
    }

    public function createTaskUpdate(WfaRequest $wfaRequest, User $actor, array $payload): WfaRequest
    {
        DB::transaction(function () use ($wfaRequest, $actor, $payload) {
            $taskUpdate = WfaTaskUpdate::create([
                'id' => $payload['id'] ?? (string) Str::uuid(),
                'wfa_request_id' => $wfaRequest->id,
                'created_by' => $actor->id,
                'message' => $payload['message'],
                'created_at' => $payload['created_at'] ?? now(),
                'updated_at' => $payload['created_at'] ?? now(),
            ]);

            foreach ($payload['attachments'] ?? [] as $attachment) {
                Attachment::create([
                    'id' => $attachment['id'] ?? (string) Str::uuid(),
                    'module' => WorkflowModule::WFA_TASK_UPDATE,
                    'reference_id' => $taskUpdate->id,
                    'file_name' => $attachment['file_name'],
                    'mime_type' => $attachment['mime_type'],
                    'url' => $attachment['url'] ?? null,
                    'thumbnail_url' => $attachment['thumbnail_url'] ?? null,
                    'size_in_bytes' => $attachment['size_in_bytes'] ?? null,
                ]);
            }
        });

        return $this->findById($wfaRequest->id);
    }

    public function findById(string $id): WfaRequest
    {
        return WfaRequest::query()
            ->with(['approvalSteps', 'taskUpdates.attachments'])
            ->findOrFail($id);
    }
}
