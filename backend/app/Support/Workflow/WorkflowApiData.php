<?php

namespace App\Support\Workflow;

use App\Models\ApprovalStep;
use App\Models\FaceProfile;
use App\Models\FaceVerificationLog;
use App\Models\LeaveRequest;
use App\Models\User;
use App\Models\WfaRequest;
use App\Models\WfaTaskUpdate;
use App\Services\OfficeAttendanceSettingService;
use App\Support\Territory\TerritoryData;
use Illuminate\Support\Carbon;

class WorkflowApiData
{
    public static function user(User $user): array
    {
        $user->loadMissing('faceProfile');
        $globalOffice = app(OfficeAttendanceSettingService::class)->current();

        return [
            'id' => $user->id,
            'full_name' => $user->full_name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'area_name' => $user->area_name,
            'work_location' => $user->work_location,
            'job_title' => $user->job_title,
            'office_latitude' => $globalOffice['latitude'] ?? ($user->office_latitude === null ? null : (float) $user->office_latitude),
            'office_longitude' => $globalOffice['longitude'] ?? ($user->office_longitude === null ? null : (float) $user->office_longitude),
            'attendance_radius_meters' => $globalOffice['radius_meters'] ?? $user->attendance_radius_meters,
            'territory_scope' => $user->territory_scope,
            'territory_province' => $user->territory_province,
            'territory_city' => $user->territory_city,
            'territory_district' => $user->territory_district,
            'territory_subdistrict' => $user->territory_subdistrict,
            'territory_assignments' => TerritoryData::userAssignments($user),
            'territory_label' => TerritoryData::displayAssignmentsLabel(TerritoryData::userAssignments($user)),
            'role' => $user->role,
            'can_switch_roles' => false,
            'available_roles' => [$user->role],
            'spv_id' => $user->spv_id,
            'spv_name' => $user->spv?->full_name,
            'management_id' => $user->management_id,
            'management_name' => $user->management?->full_name,
            'is_active' => $user->is_active,
            'leave_balance_days' => $user->leave_balance_days === null ? null : (float) $user->leave_balance_days,
            'joined_at' => optional($user->joined_at)?->toDateString(),
            'address' => $user->address,
            'emergency_contact_name' => $user->emergency_contact_name,
            'emergency_contact_phone' => $user->emergency_contact_phone,
            'face_enrollment_status' => $user->faceProfile?->status ?? 'pending',
            'face_samples_count' => count($user->faceProfile?->samples ?? []),
        ];
    }

    public static function faceProfile(FaceProfile $profile): array
    {
        return [
            'id' => $profile->id,
            'user_id' => $profile->user_id,
            'status' => $profile->status,
            'samples' => $profile->samples ?? [],
            'samples_count' => count($profile->samples ?? []),
            'enrolled_at' => self::dateTime($profile->enrolled_at),
            'last_verified_at' => self::dateTime($profile->last_verified_at),
            'verification_mode' => $profile->verification_mode,
            'biometric_template_ready' => count($profile->biometric_template ?? []) >= 64,
            'note' => $profile->note,
        ];
    }

    public static function faceVerificationLog(FaceVerificationLog $log): array
    {
        return [
            'id' => $log->id,
            'user_id' => $log->user_id,
            'face_profile_id' => $log->face_profile_id,
            'action' => $log->action,
            'result' => $log->result,
            'match_score' => $log->match_score === null ? null : (float) $log->match_score,
            'liveness_score' => $log->liveness_score === null ? null : (float) $log->liveness_score,
            'capture_attachment' => $log->capture_attachment,
            'metadata' => $log->metadata ?? [],
            'verified_at' => self::dateTime($log->verified_at),
            'note' => $log->note,
        ];
    }

    public static function approvalStep(ApprovalStep $step): array
    {
        return [
            'sequence' => $step->sequence,
            'approver_role' => $step->approver_role,
            'status' => $step->status,
            'approver_id' => $step->approver_id,
            'approver_name' => $step->approver_name,
            'note' => $step->note,
            'acted_at' => self::dateTime($step->acted_at),
        ];
    }

    public static function leave(LeaveRequest $leaveRequest): array
    {
        return [
            'id' => $leaveRequest->id,
            'requester_id' => $leaveRequest->requester_id,
            'requester_name' => $leaveRequest->requester_name,
            'requester_role' => $leaveRequest->requester_role,
            'category' => $leaveRequest->category,
            'compensation_option' => $leaveRequest->compensation_option,
            'start_at' => self::dateTime($leaveRequest->start_at),
            'end_at' => self::dateTime($leaveRequest->end_at),
            'duration_value' => (float) $leaveRequest->duration_value,
            'reason' => $leaveRequest->reason,
            'delegate_to' => $leaveRequest->delegate_to,
            'status' => $leaveRequest->status,
            'approval_steps' => $leaveRequest->approvalSteps->map(fn (ApprovalStep $step) => self::approvalStep($step))->values()->all(),
            'attachments' => $leaveRequest->attachments->map(fn ($attachment) => [
                'id' => $attachment->id,
                'file_name' => $attachment->file_name,
                'mime_type' => $attachment->mime_type,
                'url' => $attachment->url,
                'thumbnail_url' => $attachment->thumbnail_url,
                'size_in_bytes' => $attachment->size_in_bytes,
            ])->values()->all(),
            'submitted_at' => self::dateTime($leaveRequest->submitted_at),
            'note' => $leaveRequest->note,
        ];
    }

    public static function wfa(WfaRequest $wfaRequest): array
    {
        return [
            'id' => $wfaRequest->id,
            'requester_id' => $wfaRequest->requester_id,
            'requester_name' => $wfaRequest->requester_name,
            'requester_role' => $wfaRequest->requester_role,
            'mode' => $wfaRequest->mode,
            'compensation_mode' => $wfaRequest->compensation_mode,
            'work_date' => self::dateTime($wfaRequest->work_date),
            'start_time' => $wfaRequest->start_time,
            'end_time' => $wfaRequest->end_time,
            'location_label' => $wfaRequest->location_label,
            'reason' => $wfaRequest->reason,
            'initial_task' => $wfaRequest->initial_task,
            'status' => $wfaRequest->status,
            'approval_steps' => $wfaRequest->approvalSteps->map(fn (ApprovalStep $step) => self::approvalStep($step))->values()->all(),
            'task_updates' => $wfaRequest->taskUpdates->map(fn (WfaTaskUpdate $update) => self::wfaTaskUpdate($update))->values()->all(),
            'submitted_at' => self::dateTime($wfaRequest->submitted_at),
            'actual_start_at' => self::dateTime($wfaRequest->actual_start_at),
            'actual_end_at' => self::dateTime($wfaRequest->actual_end_at),
            'note' => $wfaRequest->note,
        ];
    }

    public static function wfaTaskUpdate(WfaTaskUpdate $taskUpdate): array
    {
        return [
            'id' => $taskUpdate->id,
            'message' => $taskUpdate->message,
            'created_at' => self::dateTime($taskUpdate->created_at),
            'attachments' => $taskUpdate->attachments->map(fn ($attachment) => [
                'id' => $attachment->id,
                'file_name' => $attachment->file_name,
                'mime_type' => $attachment->mime_type,
                'url' => $attachment->url,
                'thumbnail_url' => $attachment->thumbnail_url,
                'size_in_bytes' => $attachment->size_in_bytes,
            ])->values()->all(),
        ];
    }

    public static function approvalInboxItem(ApprovalStep $step): array
    {
        if ($step->module === WorkflowModule::LEAVE && $step->leaveRequest) {
            $leaveRequest = $step->leaveRequest;

            return [
                'id' => $step->id,
                'module' => WorkflowModule::LEAVE,
                'reference_id' => $leaveRequest->id,
                'requester_id' => $leaveRequest->requester_id,
                'requester_name' => $leaveRequest->requester_name,
                'requester_role' => $leaveRequest->requester_role,
                'title' => $leaveRequest->category,
                'summary' => $leaveRequest->reason,
                'status' => $leaveRequest->status,
                'submitted_at' => self::dateTime($leaveRequest->submitted_at),
                'approval_steps' => $leaveRequest->approvalSteps->map(fn (ApprovalStep $innerStep) => self::approvalStep($innerStep))->values()->all(),
            ];
        }

        $wfaRequest = $step->wfaRequest;

        return [
            'id' => $step->id,
            'module' => WorkflowModule::WFA,
            'reference_id' => $wfaRequest?->id,
            'requester_id' => $wfaRequest?->requester_id,
            'requester_name' => $wfaRequest?->requester_name,
            'requester_role' => $wfaRequest?->requester_role,
            'title' => $wfaRequest?->mode,
            'summary' => $wfaRequest?->reason,
            'status' => $wfaRequest?->status,
            'submitted_at' => self::dateTime($wfaRequest?->submitted_at),
            'approval_steps' => $wfaRequest?->approvalSteps->map(fn (ApprovalStep $innerStep) => self::approvalStep($innerStep))->values()->all() ?? [],
        ];
    }

    private static function dateTime(Carbon|string|null $value): ?string
    {
        if ($value instanceof Carbon) {
            return $value->toIso8601String();
        }

        if (is_string($value) && $value !== '') {
            return Carbon::parse($value)->toIso8601String();
        }

        return null;
    }
}
