<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\LeaveRequest;
use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\PerformanceTarget;
use App\Models\WfaRequest;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminWebAdvancedTest extends TestCase
{
    use RefreshDatabase;

    private User $hr;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(WorkflowDemoSeeder::class);
        $this->hr = User::query()->findOrFail('usr_hr_001');
    }

    public function test_hr_can_view_wfa_monitoring_page(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.wfa.index'))
            ->assertOk()
            ->assertSee('Monitoring WFA')
            ->assertSee('Meeting malam dengan mitra regional');
    }

    public function test_hr_can_view_approval_center_page(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.approvals.index'))
            ->assertOk()
            ->assertSee('Approval Center')
            ->assertSee('leave_001');
    }

    public function test_hr_can_view_network_monitoring_page(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.network.index'))
            ->assertOk()
            ->assertSee('Monitoring Jaringan')
            ->assertSee('UKM Toko Harapan');
    }

    public function test_hr_can_view_wfa_detail_page(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.wfa.show', 'wfa_001'))
            ->assertOk()
            ->assertSee('Detail WFA')
            ->assertSee('Meeting selesai, tindak lanjut sudah dicatat.');
    }

    public function test_hr_can_view_network_detail_page(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.network.show', 'net_fgg_001'))
            ->assertOk()
            ->assertSee('Detail Jaringan')
            ->assertSee('Kunjungan awal');
    }

    public function test_hr_can_view_reports_page(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.reports.index'))
            ->assertOk()
            ->assertSee('Laporan HR')
            ->assertSee('Rekap Karyawan Teratas');
    }

    public function test_dashboard_shows_current_mobile_data_source_state(): void
    {
        $this->actingAs($this->hr)
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Source Data Mobile')
            ->assertSee('DB Connection')
            ->assertSee('sqlite')
            ->assertSee('Masih memakai data lokal / sqlite');
    }

    public function test_hr_can_see_wfa_created_via_mobile_api_with_attachment_preview(): void
    {
        $staff = User::query()->findOrFail('usr_001');

        Sanctum::actingAs($staff);
        $this->postJson('/api/wfa', [
            'id' => 'wfa_admin_sync_001',
            'requester_id' => $staff->id,
            'mode' => 'regular',
            'work_date' => now()->toDateString(),
            'start_time' => '09:00',
            'end_time' => '17:00',
            'location_label' => 'Remote warehouse',
            'reason' => 'Sinkronisasi data admin HR',
            'initial_task' => 'Validasi request sinkron via API',
        ])->assertCreated();

        $this->patchJson('/api/wfa/wfa_admin_sync_001/status', [
            'status' => 'approved',
            'note' => 'Approved for preview testing.',
        ])->assertOk();

        $this->postJson('/api/wfa/wfa_admin_sync_001/task-updates', [
            'id' => 'wfa_admin_sync_upd_001',
            'actor_id' => $staff->id,
            'message' => 'Lampiran bukti kerja mobile berhasil terkirim.',
            'attachments' => [[
                'id' => 'att_admin_sync_001',
                'file_name' => 'api-proof.jpg',
                'mime_type' => 'image/jpeg',
                'url' => 'https://cdn.example.test/api-proof.jpg',
                'thumbnail_url' => 'https://cdn.example.test/api-proof-thumb.jpg',
                'size_in_bytes' => 120045,
            ]],
        ])->assertCreated();

        $this->actingAs($this->hr)
            ->get(route('admin.wfa.show', 'wfa_admin_sync_001'))
            ->assertOk()
            ->assertSee('Lampiran bukti kerja mobile berhasil terkirim.')
            ->assertSee('api-proof.jpg')
            ->assertSee('https://cdn.example.test/api-proof-thumb.jpg', false);
    }

    public function test_hr_can_see_network_created_via_mobile_api_with_photo_and_document_preview(): void
    {
        $fgg = User::query()->findOrFail('usr_fgg_001');

        Sanctum::actingAs($fgg);
        $this->postJson('/api/network', [
            'id' => 'net_admin_sync_001',
            'type' => 'ukm',
            'name' => 'UKM Sinkron Admin',
            'address' => 'Depok Barat',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Pejaten Barat',
            'business_type' => 'Kuliner',
            'phone_number' => '081300009999',
            'status' => 'followUp',
            'note' => 'Dibuat dari endpoint mobile.',
            'photo' => [
                'id' => 'photo_sync_001',
                'file_name' => 'ukm-front.jpg',
                'mime_type' => 'image/jpeg',
                'url' => 'https://cdn.example.test/ukm-front.jpg',
                'thumbnail_url' => 'https://cdn.example.test/ukm-front-thumb.jpg',
                'size_in_bytes' => 212345,
            ],
            'documents' => [[
                'label' => 'KTP Pemilik',
                'exists' => true,
                'is_valid' => true,
                'attachment' => [
                    'id' => 'doc_sync_001',
                    'file_name' => 'ktp-usaha.pdf',
                    'mime_type' => 'application/pdf',
                    'url' => 'https://cdn.example.test/ktp-usaha.pdf',
                ],
            ]],
            'personality_metrics' => [
                ['label' => 'Komitmen', 'score' => 88],
            ],
            'latitude' => -6.3901000,
            'longitude' => 106.8112000,
        ])->assertCreated();

        $this->postJson('/api/network/net_admin_sync_001/follow-ups', [
            'id' => 'net_admin_sync_fu_001',
            'title' => 'Verifikasi dokumen awal',
            'note' => 'Dokumen dan foto outlet sudah lengkap.',
            'next_status' => 'completed',
        ])->assertCreated();

        $this->actingAs($this->hr)
            ->get(route('admin.network.show', 'net_admin_sync_001'))
            ->assertOk()
            ->assertSee('UKM Sinkron Admin')
            ->assertSee('Verifikasi dokumen awal')
            ->assertSee('ktp-usaha.pdf')
            ->assertSee('-6.390100')
            ->assertSee('https://www.google.com/maps?q=-6.3901,106.8112', false)
            ->assertSee('https://cdn.example.test/ukm-front-thumb.jpg', false);
    }

    public function test_hr_can_see_leave_and_attendance_created_via_mobile_api(): void
    {
        $staff = User::query()->findOrFail('usr_001');

        Sanctum::actingAs($staff);
        $this->postJson('/api/leave', [
            'id' => 'leave_admin_sync_001',
            'requester_id' => $staff->id,
            'category' => 'cuti',
            'compensation_option' => 'potongSaldoCuti',
            'start_at' => now()->addDays(3)->startOfDay()->toIso8601String(),
            'end_at' => now()->addDays(4)->startOfDay()->toIso8601String(),
            'duration_value' => 2,
            'reason' => 'Cuti sinkron admin HR',
            'delegate_to' => 'Rekan Tim Operasional',
        ])->assertCreated();

        $this->postJson('/api/attendance/check-in', [
            'id' => 'att_admin_sync_001',
            'work_date' => now()->addDays(5)->toIso8601String(),
            'recorded_at' => now()->addDays(5)->setTime(8, 31)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -6.2,
                'longitude' => 106.8166,
                'recorded_at' => now()->addDays(5)->setTime(8, 31)->toIso8601String(),
                'address_label' => 'Gudang Barat',
            ],
            'verification' => [
                'verified_at' => now()->addDays(5)->setTime(8, 30)->toIso8601String(),
                'match_score' => 0.99,
                'liveness_score' => 0.97,
            ],
        ])->assertCreated();

        $this->actingAs($this->hr)
            ->get(route('admin.leaves.index'))
            ->assertOk()
            ->assertSee('Cuti sinkron admin HR');

        $this->actingAs($this->hr)
            ->get(route('admin.attendance.index', [
                'date' => now()->addDays(5)->toDateString(),
                'search' => 'Nadia Staff',
            ]))
            ->assertOk()
            ->assertSee('Gudang Barat')
            ->assertSee('-6.200000, 106.816600')
            ->assertSee('https://www.google.com/maps?q=-6.2,106.8166', false)
            ->assertSee('Terlambat 1 menit dari jadwal 08:30.')
            ->assertSee('Terverifikasi');

        $this->actingAs($this->hr)
            ->get(route('admin.employees.show', $staff))
            ->assertOk()
            ->assertSee('Gudang Barat')
            ->assertSee('-6.200000, 106.816600')
            ->assertSee('Terlambat 1 menit dari jadwal 08:30.')
            ->assertSee('https://www.google.com/maps?q=-6.2,106.8166', false);
    }

    public function test_hr_can_export_employee_csv(): void
    {
        $response = $this->actingAs($this->hr)
            ->get(route('admin.employees.index', ['export' => 'csv']));

        $response
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_hr_can_export_wfa_csv(): void
    {
        $response = $this->actingAs($this->hr)
            ->get(route('admin.wfa.index', ['export' => 'csv']));

        $response
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_hr_can_export_reports_csv(): void
    {
        $response = $this->actingAs($this->hr)
            ->get(route('admin.reports.index', ['export' => 'csv']));

        $response
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
    }

    public function test_hr_can_open_employee_create_and_edit_forms(): void
    {
        $employee = User::query()->findOrFail('usr_fgg_001');

        $this->actingAs($this->hr)
            ->get(route('admin.employees.create'))
            ->assertOk()
            ->assertSee('Wilayah Kerja Bertingkat')
            ->assertSee('Tambah Rule Wilayah');

        $this->actingAs($this->hr)
            ->get(route('admin.employees.edit', $employee))
            ->assertOk()
            ->assertSee('Wilayah Kerja Bertingkat')
            ->assertSee('Tambah Rule Wilayah');
    }

    public function test_hr_can_update_employee_with_include_and_exclude_territory_rules(): void
    {
        $employee = User::query()->findOrFail('usr_area_001');

        $rules = [
            [
                'rule_type' => 'include',
                'territory_scope' => 'province',
                'territory_province' => 'DKI Jakarta',
                'territory_city' => null,
                'territory_district' => null,
                'territory_subdistrict' => null,
            ],
            [
                'rule_type' => 'include',
                'territory_scope' => 'province',
                'territory_province' => 'Banten',
                'territory_city' => null,
                'territory_district' => null,
                'territory_subdistrict' => null,
            ],
            [
                'rule_type' => 'exclude',
                'territory_scope' => 'subdistrict',
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Kota Administrasi Jakarta Barat',
                'territory_district' => 'Taman Sari',
                'territory_subdistrict' => 'Mangga Besar',
            ],
        ];

        $this->actingAs($this->hr)
            ->put(route('admin.employees.update', $employee), [
                'employee_code' => $employee->employee_code,
                'full_name' => $employee->full_name,
                'phone_number' => $employee->phone_number,
                'email' => $employee->email,
                'role' => 'areaManager',
                'job_title' => $employee->job_title,
                'work_location' => $employee->work_location,
                'territory_rules_payload' => json_encode($rules, JSON_UNESCAPED_UNICODE),
                'leave_balance_days' => 10,
                'joined_at' => optional($employee->joined_at)->format('Y-m-d'),
                'is_active' => '1',
            ])
            ->assertRedirect(route('admin.employees.show', $employee));

        $employee->refresh();

        $this->assertSame('province', $employee->territory_scope);
        $this->assertSame('DKI Jakarta', $employee->territory_province);
        $this->assertCount(3, $employee->territory_assignments);
        $this->assertSame('exclude', $employee->territory_assignments[2]['rule_type']);
        $this->assertStringContainsString('kecuali Mangga Besar', $employee->area_name);
    }

    public function test_hr_can_set_active_performance_targets_for_employee(): void
    {
        $employee = User::query()->findOrFail('usr_fgg_001');

        $this->actingAs($this->hr)
            ->post(route('admin.employees.targets.update', $employee), [
                'targets' => [
                    'fgg_new_ukm' => 50,
                    'fgg_follow_up_visit' => 20,
                ],
            ])
            ->assertRedirect(route('admin.employees.show', $employee));

        $this->assertDatabaseHas('performance_targets', [
            'user_id' => $employee->id,
            'metric_key' => 'fgg_new_ukm',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 50,
        ]);

        $this->assertDatabaseHas('performance_targets', [
            'user_id' => $employee->id,
            'metric_key' => 'fgg_follow_up_visit',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 20,
        ]);

        $this->actingAs($this->hr)
            ->get(route('admin.employees.show', $employee))
            ->assertOk()
            ->assertSee('Ubah Target Aktif')
            ->assertSee('Target Aktif')
            ->assertSee('UKM Baru')
            ->assertSee('Kunjungan');
    }

    public function test_hr_can_see_employee_daily_attendance_recap_for_period(): void
    {
        $staff = User::query()->findOrFail('usr_001');

        $presentDay = Carbon::create(2026, 5, 1);
        $leaveDay = Carbon::create(2026, 5, 2);
        $wfaDay = Carbon::create(2026, 5, 3);
        $absentDay = Carbon::create(2026, 5, 4);

        \App\Models\AttendanceRecord::query()->create([
            'id' => 'att_recap_in_001',
            'user_id' => $staff->id,
            'work_date' => $presentDay->toDateString(),
            'action' => 'checkIn',
            'status' => 'success',
            'recorded_at' => $presentDay->copy()->setTime(8, 31),
            'location' => [
                'latitude' => -6.2,
                'longitude' => 106.8,
                'address_label' => 'Kantor Pusat',
            ],
            'verification' => [
                'decision' => 'verified',
                'match_score' => 0.99,
                'liveness_score' => 0.98,
            ],
        ]);

        \App\Models\AttendanceRecord::query()->create([
            'id' => 'att_recap_out_001',
            'user_id' => $staff->id,
            'work_date' => $presentDay->toDateString(),
            'action' => 'checkOut',
            'status' => 'success',
            'recorded_at' => $presentDay->copy()->setTime(17, 0),
            'location' => [
                'latitude' => -6.2,
                'longitude' => 106.8,
                'address_label' => 'Kantor Pusat',
            ],
            'verification' => [
                'decision' => 'verified',
                'match_score' => 0.99,
                'liveness_score' => 0.98,
            ],
        ]);

        LeaveRequest::query()->create([
            'id' => 'leave_recap_001',
            'requester_id' => $staff->id,
            'requester_name' => $staff->full_name,
            'requester_role' => $staff->role,
            'category' => 'cuti',
            'compensation_option' => 'potongSaldoCuti',
            'start_at' => $leaveDay->copy()->startOfDay(),
            'end_at' => $leaveDay->copy()->startOfDay(),
            'duration_value' => 1,
            'reason' => 'Cuti keluarga',
            'delegate_to' => 'Tim Operasional',
            'status' => 'approved',
            'submitted_at' => $leaveDay->copy()->subDay(),
        ]);

        WfaRequest::query()->create([
            'id' => 'wfa_recap_001',
            'requester_id' => $staff->id,
            'requester_name' => $staff->full_name,
            'requester_role' => $staff->role,
            'mode' => 'regular',
            'compensation_mode' => null,
            'work_date' => $wfaDay->copy()->startOfDay(),
            'start_time' => '09:00',
            'end_time' => '17:00',
            'location_label' => 'Rumah',
            'reason' => 'WFA review laporan',
            'initial_task' => 'Review laporan bulanan',
            'status' => 'approved',
            'submitted_at' => $wfaDay->copy()->subDay(),
        ]);

        $this->actingAs($this->hr)
            ->get(route('admin.attendance.index', [
                'search' => 'Nadia Staff',
                'date_from' => $presentDay->toDateString(),
                'date_until' => $absentDay->toDateString(),
            ]))
            ->assertOk()
            ->assertSee('Rekap Harian Nadia Staff')
            ->assertSee('01 May 2026')
            ->assertSee('Hadir')
            ->assertSee('Terlambat 1 menit dari jadwal 08:30.')
            ->assertSee('02 May 2026')
            ->assertSee('Cuti')
            ->assertSee('Cuti keluarga')
            ->assertSee('03 May 2026')
            ->assertSee('WFA')
            ->assertSee('WFA review laporan')
            ->assertSee('04 May 2026')
            ->assertSee('Tidak ada absensi');
    }

    public function test_hr_can_see_network_activity_recap_for_owner_and_period(): void
    {
        $fgg = User::query()->findOrFail('usr_fgg_001');
        $createdAt = Carbon::create(2026, 5, 10, 10, 0);

        $profile = NetworkProfile::query()->create([
            'id' => 'net_recap_001',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => $fgg->area_name,
            'type' => 'ukm',
            'name' => 'UKM Rekap Bima',
            'address' => 'Pasar Minggu',
            'business_type' => 'Kuliner',
            'phone_number' => '081200009999',
            'status' => 'followUp',
        ]);
        $profile->forceFill([
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ])->saveQuietly();

        NetworkFollowUp::query()->create([
            'id' => 'net_recap_fu_001',
            'network_profile_id' => $profile->id,
            'title' => 'Kunjungan ulang',
            'note' => 'Pemilik minta follow-up pekan depan.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => $createdAt->copy()->addHours(2),
        ]);

        $this->actingAs($this->hr)
            ->get(route('admin.network.index', [
                'search' => 'Bima FGG',
                'date_from' => '2026-05-01',
                'date_until' => '2026-05-31',
            ]))
            ->assertOk()
            ->assertSee('Rekap Aktivitas Bima FGG')
            ->assertSee('UKM Baru')
            ->assertSee('Kunjungan UKM')
            ->assertSee('UKM Rekap Bima')
            ->assertSee('Pemilik minta follow-up pekan depan.');
    }
}
