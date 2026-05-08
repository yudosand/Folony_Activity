<?php

namespace Database\Seeders;

use App\Models\ApprovalStep;
use App\Models\AttendanceRecord;
use App\Models\User;
use App\Models\NetworkProfile;
use App\Models\NetworkFollowUp;
use App\Models\WfaRequest;
use App\Models\WfaTaskUpdate;
use App\Models\Attachment;
use App\Services\LeaveService;
use App\Services\WfaService;
use App\Support\Workflow\ApprovalStepStatus;
use App\Support\Workflow\UserRole;
use App\Support\Workflow\WorkflowModule;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class WorkflowDemoSeeder extends Seeder
{
    public function run(): void
    {
        $management = User::query()->updateOrCreate(
            ['id' => 'usr_mgt_001'],
            [
                'full_name' => 'Sinta Management',
                'phone_number' => '081111111111',
                'area_name' => 'Head Office',
                'role' => UserRole::MANAGEMENT,
                'email' => 'management@hex.local',
                'password' => '123456',
                'is_active' => true,
            ],
        );

        $spv = User::query()->updateOrCreate(
            ['id' => 'usr_spv_001'],
            [
                'full_name' => 'Dimas SPV',
                'phone_number' => '082222222222',
                'area_name' => 'Jakarta Selatan',
                'role' => UserRole::SPV,
                'management_id' => $management->id,
                'email' => 'spv@hex.local',
                'password' => '123456',
                'is_active' => true,
            ],
        );

        $staff = User::query()->updateOrCreate(
            ['id' => 'usr_001'],
            [
                'full_name' => 'Nadia Staff',
                'phone_number' => '083333333333',
                'area_name' => 'Head Office',
                'role' => UserRole::STAFF,
                'spv_id' => $spv->id,
                'management_id' => $management->id,
                'email' => 'staff@hex.local',
                'password' => '123456',
                'is_active' => true,
            ],
        );

        User::query()->updateOrCreate(
            ['id' => 'usr_area_001'],
            [
                'full_name' => 'Raka Area Manager',
                'phone_number' => '084444444444',
                'area_name' => 'Depok',
                'role' => UserRole::AREA_MANAGER,
                'management_id' => $management->id,
                'email' => 'area.manager@hex.local',
                'password' => '123456',
                'is_active' => true,
            ],
        );

        User::query()->updateOrCreate(
            ['id' => 'usr_fgg_001'],
            [
                'full_name' => 'Bima FGG',
                'phone_number' => '085555555555',
                'area_name' => 'Depok',
                'role' => UserRole::FGG,
                'email' => 'fgg@hex.local',
                'password' => '123456',
                'is_active' => true,
            ],
        );

        /** @var LeaveService $leaveService */
        $leaveService = app(LeaveService::class);
        /** @var WfaService $wfaService */
        $wfaService = app(WfaService::class);

        $leaveRequest = $leaveService->create([
            'id' => 'leave_001',
            'category' => 'izinPerHari',
            'compensation_option' => 'tidakPotongGaji',
            'start_at' => now()->startOfDay()->toIso8601String(),
            'end_at' => now()->addDay()->startOfDay()->toIso8601String(),
            'duration_value' => 1,
            'reason' => 'Keperluan keluarga',
            'delegate_to' => 'Dian Pratama',
            'note' => 'Seeder leave pending.',
        ], $staff);

        $firstLeaveStep = $leaveRequest->approvalSteps->first();
        if ($firstLeaveStep && $firstLeaveStep->status === ApprovalStepStatus::PENDING) {
            $firstLeaveStep->update([
                'status' => ApprovalStepStatus::APPROVED,
                'note' => 'Lanjutkan ke management.',
                'acted_at' => now()->subHours(2),
            ]);
        }

        $wfaRequest = $wfaService->create([
            'id' => 'wfa_001',
            'mode' => 'overtime',
            'compensation_mode' => 'shiftMundur',
            'work_date' => now()->startOfDay()->toIso8601String(),
            'start_time' => '19:30',
            'end_time' => '21:00',
            'location_label' => 'Online meeting dari rumah',
            'reason' => 'Meeting malam dengan mitra regional',
            'initial_task' => 'Presentasi progres dan tindak lanjut hasil meeting malam',
            'note' => 'Seeder WFA overtime.',
        ], $staff);

        $wfaRequest->approvalSteps()->update([
            'status' => ApprovalStepStatus::APPROVED,
            'note' => 'Seeder auto-approved.',
            'acted_at' => now()->subHour(),
        ]);

        $wfaRequest->update([
            'status' => WorkflowStatus::COMPLETED,
            'actual_start_at' => now()->setTime(19, 30),
            'actual_end_at' => now()->setTime(21, 0),
            'note' => 'Seeder WFA completed.',
        ]);

        $taskUpdate = WfaTaskUpdate::query()->updateOrCreate(
            ['id' => 'wfa_upd_001'],
            [
                'wfa_request_id' => $wfaRequest->id,
                'created_by' => $staff->id,
                'message' => 'Meeting selesai, tindak lanjut sudah dicatat.',
                'created_at' => now()->subMinutes(30),
                'updated_at' => now()->subMinutes(30),
            ],
        );

        Attachment::query()->updateOrCreate(
            ['id' => 'file_002'],
            [
                'module' => WorkflowModule::WFA_TASK_UPDATE,
                'reference_id' => $taskUpdate->id,
                'file_name' => 'meeting-night.jpg',
                'mime_type' => 'image/jpeg',
                'url' => 'https://example.test/files/meeting-night.jpg',
                'thumbnail_url' => 'https://example.test/files/meeting-night-thumb.jpg',
                'size_in_bytes' => 245760,
            ],
        );

        $managementPending = ApprovalStep::query()
            ->where('module', WorkflowModule::LEAVE)
            ->where('reference_id', $leaveRequest->id)
            ->where('approver_id', $management->id)
            ->first();

        if (! $managementPending) {
            ApprovalStep::create([
                'id' => (string) Str::uuid(),
                'module' => WorkflowModule::LEAVE,
                'reference_id' => $leaveRequest->id,
                'sequence' => 2,
                'approver_role' => UserRole::MANAGEMENT,
                'approver_id' => $management->id,
                'approver_name' => $management->full_name,
                'status' => ApprovalStepStatus::PENDING,
            ]);
        }

        $leaveRequest->update(['status' => WorkflowStatus::PENDING]);

        $areaManager = User::query()->findOrFail('usr_area_001');
        $fgg = User::query()->findOrFail('usr_fgg_001');

        NetworkProfile::query()->updateOrCreate(
            ['id' => 'net_area_001'],
            [
                'owner_id' => $areaManager->id,
                'owner_name' => $areaManager->full_name,
                'owner_role' => $areaManager->role,
                'area_name' => $areaManager->area_name,
                'type' => 'mitra',
                'name' => 'Mitra Hub Budi Jaya',
                'address' => 'Jl. Jagakarsa Raya No. 18',
                'business_type' => 'Mitra Distribusi',
                'phone_number' => '081298765432',
                'status' => 'followUp',
                'reference_name' => 'Referensi Area Manager',
                'note' => 'Perlu update dokumen dan validasi lokasi ulang.',
                'personality_metrics' => [
                    ['label' => 'Etika pribadi', 'score' => 82],
                    ['label' => 'Jiwa bisnis', 'score' => 80],
                ],
                'documents' => [
                    ['label' => 'Fotocopy KTP', 'exists' => true, 'is_valid' => true],
                    ['label' => 'Survey lokasi', 'exists' => true, 'is_valid' => false],
                ],
                'latitude' => -6.3707000,
                'longitude' => 106.8332000,
            ],
        );

        NetworkProfile::query()->updateOrCreate(
            ['id' => 'net_fgg_001'],
            [
                'owner_id' => $fgg->id,
                'owner_name' => $fgg->full_name,
                'owner_role' => $fgg->role,
                'area_name' => $fgg->area_name,
                'type' => 'ukm',
                'name' => 'UKM Toko Harapan',
                'address' => 'Pasar Minggu Blok A',
                'business_type' => 'Sembako',
                'phone_number' => '081234567890',
                'status' => 'followUp',
                'reference_name' => 'Prospek Lapangan',
                'note' => 'Terakhir dikunjungi 3 hari lalu.',
                'latitude' => -6.3674000,
                'longitude' => 106.8294000,
            ],
        );

        NetworkFollowUp::query()->updateOrCreate(
            ['id' => 'net_fu_001'],
            [
                'network_profile_id' => 'net_fgg_001',
                'title' => 'Kunjungan awal',
                'note' => 'UKM prospektif dan siap di-follow-up.',
                'actor_id' => $fgg->id,
                'actor_name' => $fgg->full_name,
                'created_at' => now()->subDay(),
            ],
        );

        AttendanceRecord::query()->updateOrCreate(
            ['id' => 'att_001'],
            [
                'user_id' => $staff->id,
                'work_date' => now()->toDateString(),
                'action' => 'checkIn',
                'status' => 'success',
                'recorded_at' => now()->setTime(8, 32),
                'location' => [
                    'latitude' => -6.2000000,
                    'longitude' => 106.8166660,
                    'recorded_at' => now()->setTime(8, 32)->toIso8601String(),
                    'address_label' => 'Head Office',
                ],
                'verification' => [
                    'verified_at' => now()->setTime(8, 31)->toIso8601String(),
                    'match_score' => 0.97,
                    'liveness_score' => 0.93,
                ],
                'note' => 'Seeder check-in.',
            ],
        );

        AttendanceRecord::query()->updateOrCreate(
            ['id' => 'att_002'],
            [
                'user_id' => $staff->id,
                'work_date' => now()->toDateString(),
                'action' => 'checkOut',
                'status' => 'success',
                'recorded_at' => now()->setTime(17, 45),
                'location' => [
                    'latitude' => -6.2000000,
                    'longitude' => 106.8166660,
                    'recorded_at' => now()->setTime(17, 45)->toIso8601String(),
                    'address_label' => 'Head Office',
                ],
                'verification' => [
                    'verified_at' => now()->setTime(17, 44)->toIso8601String(),
                    'match_score' => 0.98,
                    'liveness_score' => 0.95,
                ],
                'note' => 'Seeder check-out.',
            ],
        );
    }
}
