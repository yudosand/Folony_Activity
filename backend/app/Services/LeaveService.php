<?php

namespace App\Services;

use App\Models\ApprovalStep;
use App\Models\Attachment;
use App\Models\LeaveRequest;
use App\Models\User;
use App\Support\Workflow\ApprovalChainFactory;
use App\Support\Workflow\ApprovalStepStatus;
use App\Support\Workflow\WorkflowModule;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class LeaveService
{
    public function __construct(
        private readonly ApprovalChainFactory $approvalChainFactory,
        private readonly LeaveBalanceService $leaveBalanceService,
        private readonly PushNotificationService $pushNotificationService,
    ) {}

    public function create(array $payload, User $requester): LeaveRequest
    {
        $leaveRequest = DB::transaction(function () use ($payload, $requester) {
            if ($this->leaveBalanceService->usesBalance($payload['category'], $payload['compensation_option'])) {
                $this->leaveBalanceService->reserve($requester, (float) $payload['duration_value']);
            }

            $leaveRequest = LeaveRequest::create([
                'id' => $payload['id'] ?? (string) Str::uuid(),
                'requester_id' => $requester->id,
                'requester_name' => $requester->full_name,
                'requester_role' => $requester->role,
                'category' => $payload['category'],
                'compensation_option' => $payload['compensation_option'],
                'start_at' => $payload['start_at'],
                'end_at' => $payload['end_at'] ?? null,
                'duration_value' => $payload['duration_value'],
                'reason' => $payload['reason'],
                'delegate_to' => $payload['delegate_to'] ?? null,
                'status' => WorkflowStatus::PENDING,
                'note' => $payload['note'] ?? 'Pengajuan dibuat dari mobile.',
                'submitted_at' => now(),
            ]);

            foreach ($payload['attachments'] ?? [] as $attachmentPayload) {
                Attachment::create([
                    'id' => $attachmentPayload['id'],
                    'module' => WorkflowModule::LEAVE,
                    'reference_id' => $leaveRequest->id,
                    'file_name' => $attachmentPayload['file_name'],
                    'mime_type' => $attachmentPayload['mime_type'],
                    'url' => $attachmentPayload['url'] ?? null,
                    'thumbnail_url' => $attachmentPayload['thumbnail_url'] ?? null,
                    'size_in_bytes' => $attachmentPayload['size_in_bytes'] ?? null,
                ]);
            }

            foreach ($this->approvalChainFactory->buildFor($requester) as $step) {
                ApprovalStep::create([
                    'id' => (string) Str::uuid(),
                    'module' => WorkflowModule::LEAVE,
                    'reference_id' => $leaveRequest->id,
                    'sequence' => $step['sequence'],
                    'approver_role' => $step['approver_role'],
                    'approver_id' => $step['approver_id'],
                    'approver_name' => $step['approver_name'],
                    'status' => ApprovalStepStatus::PENDING,
                ]);
            }

            if ($leaveRequest->approvalSteps()->count() === 0) {
                $leaveRequest->update(['status' => WorkflowStatus::APPROVED]);
            }

            return $this->findById($leaveRequest->id);
        });

        $this->pushNotificationService->notifyPendingApproversForLeave($leaveRequest);

        return $leaveRequest;
    }

    public function updateStatus(LeaveRequest $leaveRequest, array $payload): LeaveRequest
    {
        DB::transaction(function () use ($leaveRequest, $payload) {
            $originalStatus = (string) $leaveRequest->status;
            $nextStatus = (string) $payload['status'];

            if (
                $nextStatus === WorkflowStatus::REJECTED
                && $originalStatus !== WorkflowStatus::REJECTED
                && $this->leaveBalanceService->usesBalanceForRequest($leaveRequest)
            ) {
                $requester = User::query()->find($leaveRequest->requester_id);
                if ($requester instanceof User) {
                    $this->leaveBalanceService->restore($requester, (float) $leaveRequest->duration_value);
                }
            }

            $leaveRequest->update([
                'status' => $nextStatus,
                'note' => $payload['note'] ?? $leaveRequest->note,
            ]);
        });

        return $this->findById($leaveRequest->id);
    }

    public function findById(string $id): LeaveRequest
    {
        return LeaveRequest::query()
            ->with(['approvalSteps', 'attachments'])
            ->findOrFail($id);
    }
}
