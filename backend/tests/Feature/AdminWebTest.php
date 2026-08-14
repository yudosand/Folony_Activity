<?php

namespace Tests\Feature;

use App\Models\ApprovalStep;
use App\Models\Announcement;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Services\PushNotificationService;
use App\Support\Workflow\UserRole;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class AdminWebTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_login_page_can_be_rendered(): void
    {
        $response = $this->get('/admin/login');

        $response
            ->assertOk()
            ->assertSee('Login Web Admin');
    }

    public function test_hr_can_login_and_open_dashboard(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $response = $this->post('/admin/login', [
            'identifier' => 'hr@hex.local',
            'password' => '123456',
        ]);

        $response->assertRedirect(route('admin.dashboard'));

        $this->followRedirects($response)
            ->assertOk()
            ->assertSee('Dashboard HR')
            ->assertSee('Total Karyawan');
    }

    public function test_non_hr_user_cannot_access_admin_dashboard(): void
    {
        $management = User::query()->create([
            'id' => 'usr_test_mgt',
            'employee_code' => 'EMP-TST-MGT',
            'full_name' => 'Test Management',
            'email' => 'test-management@local.test',
            'role' => UserRole::MANAGEMENT,
            'password' => '123456',
            'leave_balance_days' => 12,
        ]);

        $response = $this->actingAs($management)->get('/admin/dashboard');

        $response->assertForbidden();
    }

    public function test_hr_can_create_employee_from_web_admin(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->post(route('admin.employees.store'), [
            'employee_code' => 'EMP-NEW-001',
            'full_name' => 'Salsa Tester',
            'email' => 'salsa@test.local',
            'phone_number' => '081299998888',
            'role' => UserRole::STAFF,
            'job_title' => 'Staff Operasional',
            'area_name' => 'Jakarta Barat',
            'work_location' => 'Kantor Cabang Barat',
            'attendance_work_area_id' => 'work_area_ho',
            'spv_id' => 'usr_spv_001',
            'management_id' => 'usr_mgt_001',
            'leave_balance_days' => 11,
            'joined_at' => '2026-05-01',
            'address' => 'Jl. Palmerah No. 9',
            'emergency_contact_name' => 'Ibu Salsa',
            'emergency_contact_phone' => '081200001234',
            'is_active' => 1,
            'password' => '123456',
        ]);

        $response->assertRedirect(route('admin.employees.index'));

        $this->assertDatabaseHas('users', [
            'id' => 'EMP-NEW-001',
            'employee_code' => 'EMP-NEW-001',
            'full_name' => 'Salsa Tester',
            'role' => UserRole::STAFF,
        ]);
    }

    public function test_hr_can_view_attendance_monitoring_page(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.attendance.index'));

        $response
            ->assertOk()
            ->assertSee('Monitoring Absensi')
            ->assertSee('Head Office');
    }

    public function test_hr_can_view_leave_monitoring_page(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.leaves.index'));

        $response
            ->assertOk()
            ->assertSee('Monitoring Cuti / Izin')
            ->assertSee('Keperluan keluarga');
    }

    public function test_hr_can_view_employee_detail_page_with_rich_history(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.employees.show', 'usr_001'));

        $response
            ->assertOk()
            ->assertSee('WFA Terbaru')
            ->assertSee('Approval Trail')
            ->assertSee('Meeting malam dengan mitra regional');
    }

    public function test_hr_can_view_wfa_monitoring_page(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.wfa.index'));

        $response
            ->assertOk()
            ->assertSee('Monitoring WFA')
            ->assertSee('Meeting malam dengan mitra regional')
            ->assertSee('Export CSV');
    }

    public function test_hr_can_export_wfa_monitoring_csv(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.wfa.index', ['export' => 'csv']));

        $response->assertDownload('wfa-monitoring.csv');
        $content = $response->streamedContent();
        $this->assertStringContainsString('ID,Karyawan,Role,Mode,Status,Tanggal,Mulai,Selesai,Lokasi,Kompensasi', $content);
        $this->assertStringContainsString('"Task Updates"', $content);
        $this->assertStringContainsString('wfa_001,"Nadia Staff",Staff,overtime,completed', $content);
    }

    public function test_hr_can_view_approval_center_page(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.approvals.index'));

        $response
            ->assertOk()
            ->assertSee('Approval Center')
            ->assertSee('Lanjutkan ke management.')
            ->assertSee('Export CSV');
    }

    public function test_hr_can_export_approval_center_csv(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.approvals.index', ['export' => 'csv']));

        $response->assertDownload('approval-center.csv');
        $content = $response->streamedContent();
        $this->assertStringContainsString('Module,"Reference ID",Requester,"Requester Role",Approver,"Approver Role",Status,Note,"Acted At"', $content);
        $this->assertStringContainsString('leave,leave_001,"Nadia Staff",Staff', $content);
    }

    public function test_hr_can_view_network_monitoring_page(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.network.index'));

        $response
            ->assertOk()
            ->assertSee('Monitoring Jaringan')
            ->assertSee('UKM Toko Harapan')
            ->assertSee('Kunjungan awal');
    }

    public function test_hr_can_create_manual_network_profile_from_monitoring_page(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->post(route('admin.network.manual.store'), [
            'type' => 'ukm',
            'name' => 'Manual HR UKM',
            'address' => 'Jl. Manual No. 1',
            'business_type' => 'Kuliner',
            'phone_number' => '081299990001',
            'status' => 'draft',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Tebet',
            'territory_subdistrict' => 'Manggarai',
            'latitude' => '-6.21462',
            'longitude' => '106.84513',
            'note' => 'Input manual saat audit HR.',
        ]);

        $response->assertRedirect(route('admin.network.index'));

        $this->assertDatabaseHas('network_profiles', [
            'owner_id' => $hr->id,
            'owner_role' => UserRole::HR,
            'name' => 'Manual HR UKM',
            'area_name' => 'Manggarai',
        ]);

        $this->assertSame(
            1,
            NetworkProfile::query()->where('name', 'Manual HR UKM')->count(),
        );
    }

    public function test_hr_can_export_network_monitoring_csv(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.network.index', ['export' => 'csv']));

        $response->assertDownload('network-monitoring.csv');
        $content = $response->streamedContent();
        $this->assertStringContainsString('ID,Type,Nama,Owner,"Owner Role",Area,Status,"Bidang Usaha",Alamat,"Follow-up Terakhir","Waktu Follow-up"', $content);
        $this->assertStringContainsString('net_fgg_001,ukm,"UKM Toko Harapan","Bima FGG",FGG', $content);
    }

    public function test_hr_can_view_attendance_monitoring_summary(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.attendance.index'));

        $response
            ->assertOk()
            ->assertSee('Total Record')
            ->assertSee('Terverifikasi / Telat')
            ->assertSee('Export CSV');
    }

    public function test_hr_can_publish_announcement_from_web_admin(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->post(route('admin.announcements.store'), [
            'title' => 'Reminder Absensi',
            'body' => 'Jangan lupa check-in dan check-out sesuai jadwal.',
            'is_active' => 1,
        ]);

        $response->assertRedirect(route('admin.announcements.index'));

        $this->assertDatabaseHas('announcements', [
            'title' => 'Reminder Absensi',
            'is_active' => true,
        ]);

        $this->actingAs($hr)
            ->get(route('admin.announcements.index'))
            ->assertOk()
            ->assertSee('Reminder Absensi');
    }

    public function test_active_announcement_sends_push_to_target_roles(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');
        $staffIds = User::query()
            ->where('role', UserRole::STAFF)
            ->where('is_active', true)
            ->pluck('id')
            ->values()
            ->all();

        $this->mock(PushNotificationService::class, function ($mock) use ($staffIds): void {
            $mock->shouldReceive('sendToUsers')
                ->once()
                ->with(
                    Mockery::on(fn (array $userIds): bool => $userIds === $staffIds),
                    'Announcement HR: Reminder Staff',
                    'Isi announcement staff.',
                    Mockery::on(fn (array $data): bool => ($data['type'] ?? null) === 'announcement'
                        && ! empty($data['announcement_id'])),
                );
        });

        $this->actingAs($hr)->post(route('admin.announcements.store'), [
            'title' => 'Reminder Staff',
            'body' => 'Isi announcement staff.',
            'target_roles' => [UserRole::STAFF],
            'is_active' => 1,
        ])->assertRedirect(route('admin.announcements.index'));
    }

    public function test_inactive_announcement_does_not_send_push(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $this->mock(PushNotificationService::class, function ($mock): void {
            $mock->shouldNotReceive('sendToUsers');
        });

        $this->actingAs($hr)->post(route('admin.announcements.store'), [
            'title' => 'Draft Announcement',
            'body' => 'Belum perlu dikirim.',
            'target_roles' => [UserRole::STAFF],
        ])->assertRedirect(route('admin.announcements.index'));
    }
}
