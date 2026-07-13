<?php

namespace App\Services;

use App\Models\ApprovalStep;
use App\Models\User;
use App\Support\Workflow\ApprovalStepStatus;
use App\Support\Workflow\WorkflowModule;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class ApprovalFlowService
{
    public function __construct(
        private readonly LeaveBalanceService $leaveBalanceService,
        private readonly PushNotificationService $pushNotificationService,
    ) {}

    /**
     * @return Collection<int, ApprovalStep>
     */
    public function inboxForApprover(string $approverId, ?string $module = null): Collection
    {
        $query = ApprovalStep::query()
            ->with(['leaveRequest.approvalSteps', 'wfaRequest.approvalSteps'])
            ->where('approver_id', $approverId)
            ->where('status', ApprovalStepStatus::PENDING)
            ->orderBy('created_at');

        if ($module) {
            $query->where('module', $module);
        }

        return $query->get()->filter(function (ApprovalStep $step) {
            $minimumPendingSequence = ApprovalStep::query()
                ->where('module', $step->module)
                ->where('reference_id', $step->reference_id)
                ->where('status', ApprovalStepStatus::PENDING)
                ->min('sequence');

            return (int) $minimumPendingSequence === $step->sequence;
        })->values();
    }

    public function approve(ApprovalStep $step, User $actor, ?string $note = null): ApprovalStep
    {
        return DB::transaction(function () use ($step, $actor, $note) {
            $this->assertApprovable($step, $actor);

            $step->update([
                'status' => ApprovalStepStatus::APPROVED,
                'note' => $note,
                'acted_at' => now(),
            ]);

            $remainingPending = ApprovalStep::query()
                ->where('module', $step->module)
                ->where('reference_id', $step->reference_id)
                ->where('status', ApprovalStepStatus::PENDING)
                ->count();

            if ($remainingPending === 0) {
                $this->updateSourceStatus($step, WorkflowStatus::APPROVED, $note);
                $this->notifyRequester($step, WorkflowStatus::APPROVED);
            } else {
                $this->pushNotificationService->notifyNextApprovers($step);
            }

            return $this->refreshStep($step);
        });
    }

    public function reject(ApprovalStep $step, User $actor, string $note): ApprovalStep
    {
        return DB::transaction(function () use ($step, $actor, $note) {
            $this->assertApprovable($step, $actor);

            $step->update([
                'status' => ApprovalStepStatus::REJECTED,
                'note' => $note,
                'acted_at' => now(),
            ]);

            if ($step->module === WorkflowModule::LEAVE && $step->leaveRequest) {
                $requester = User::query()->find($step->leaveRequest->requester_id);
                if (
                    $requester instanceof User
                    && $this->leaveBalanceService->usesBalanceForRequest($step->leaveRequest)
                ) {
                    $this->leaveBalanceService->restore($requester, (float) $step->leaveRequest->duration_value);
                }
            }

            $this->updateSourceStatus($step, WorkflowStatus::REJECTED, $note);
            $this->notifyRequester($step, WorkflowStatus::REJECTED);

            return $this->refreshStep($step);
        });
    }

    private function assertApprovable(ApprovalStep $step, User $actor): void
    {
        abort_if($step->status !== ApprovalStepStatus::PENDING, 422, 'Step approval sudah diproses.');
        abort_if($step->approver_id !== $actor->id, 403, 'Approval ini bukan milik user aktif.');
    }

    private function updateSourceStatus(ApprovalStep $step, string $status, ?string $note): void
    {
        if ($step->module === WorkflowModule::LEAVE && $step->leaveRequest) {
            $step->leaveRequest->update([
                'status' => $status,
                'note' => $note ?? $step->leaveRequest->note,
            ]);

            return;
        }

        if ($step->module === WorkflowModule::WFA && $step->wfaRequest) {
            $step->wfaRequest->update([
                'status' => $status,
                'note' => $note ?? $step->wfaRequest->note,
            ]);
        }
    }

    private function refreshStep(ApprovalStep $step): ApprovalStep
    {
        return ApprovalStep::query()
            ->with(['leaveRequest.approvalSteps', 'wfaRequest.approvalSteps'])
            ->findOrFail($step->id);
    }

    public function resolveStep(string $approvalIdentifier, string $approverId): ApprovalStep
    {
        if (str_contains($approvalIdentifier, '::')) {
            [$module, $referenceId] = explode('::', $approvalIdentifier, 2);

            return ApprovalStep::query()
                ->with(['leaveRequest.approvalSteps', 'wfaRequest.approvalSteps'])
                ->where('module', $module)
                ->where('reference_id', $referenceId)
                ->where('approver_id', $approverId)
                ->where('status', ApprovalStepStatus::PENDING)
                ->orderBy('sequence')
                ->firstOrFail();
        }

        return ApprovalStep::query()
            ->with(['leaveRequest.approvalSteps', 'wfaRequest.approvalSteps'])
            ->findOrFail($approvalIdentifier);
    }

    private function notifyRequester(ApprovalStep $step, string $status): void
    {
        if ($step->module === WorkflowModule::LEAVE && $step->leaveRequest) {
            $this->pushNotificationService->notifyRequesterStatusChanged(
                $step->leaveRequest->requester_id,
                WorkflowModule::LEAVE,
                $status,
                $step->leaveRequest->requester_name,
                $step->leaveRequest->category
            );

            return;
        }

        if ($step->module === WorkflowModule::WFA && $step->wfaRequest) {
            $this->pushNotificationService->notifyRequesterStatusChanged(
                $step->wfaRequest->requester_id,
                WorkflowModule::WFA,
                $status,
                $step->wfaRequest->requester_name,
                $step->wfaRequest->mode
            );
        }
    }
}
