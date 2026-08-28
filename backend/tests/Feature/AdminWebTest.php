<?php

namespace Tests\Feature;

use App\Models\ApprovalStep;
use App\Models\Announcement;
use App\Models\Faq;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Services\PushNotificationService;
use App\Support\Workflow\UserRole;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Laravel\Sanctum\Sanctum;
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

    public function test_hr_can_manage_faq_content_for_mobile_app(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->post(route('admin.faqs.store'), [
            'title' => 'Cara Test FAQ',
            'body' => "1. Buka aplikasi.\n2. Ikuti panduan.",
            'sort_order' => 5,
            'is_active' => '1',
        ]);

        $response->assertRedirect(route('admin.faqs.index'));

        $faq = Faq::query()->where('title', 'Cara Test FAQ')->firstOrFail();
        $this->assertSame("1. Buka aplikasi.\n2. Ikuti panduan.", $faq->body);

        $this->actingAs($hr)
            ->get(route('admin.faqs.index'))
            ->assertOk()
            ->assertSee('Cara Test FAQ');
    }

    public function test_mobile_app_can_read_active_faqs(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        Faq::query()->create([
            'id' => 'faq_mobile_active',
            'title' => 'Cara Absensi Test',
            'body' => 'Pastikan wajah terlihat dan cahaya cukup.',
            'sort_order' => 1,
            'is_active' => true,
        ]);
        Faq::query()->create([
            'id' => 'faq_mobile_inactive',
            'title' => 'FAQ Tidak Aktif',
            'body' => 'Tidak tampil.',
            'sort_order' => 2,
            'is_active' => false,
        ]);

        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $this->getJson('/api/faqs')
            ->assertOk()
            ->assertJsonFragment([
                'id' => 'faq_mobile_active',
                'title' => 'Cara Absensi Test',
            ])
            ->assertJsonMissing([
                'id' => 'faq_mobile_inactive',
                'title' => 'FAQ Tidak Aktif',
            ]);
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
            ->assertSee('UKM Demo')
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

    public function test_hr_can_import_network_profiles_from_csv_for_heatmap(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $csv = implode("\n", [
            'Laporan export jaringan HR',
            'Periode Agustus',
            'tipe,nama,alamat,jenis_usaha,nomor_hp,provinsi,kota,kecamatan,kelurahan,latitude,longitude,catatan',
            'ukm,Warung Sheet,Indramayu,Kuliner,081200000001,Jawa Barat,Indramayu,Indramayu,Karanganyar,-6.3265,108.3240,Import dari sheet',
            'mitra,Mitra Tanpa Titik,Bandung,Distribusi,081200000002,Jawa Barat,Bandung,Coblong,Dago,,,Tanpa koordinat',
        ]);

        $response = $this->actingAs($hr)->post(route('admin.network.import'), [
            'csv_file' => UploadedFile::fake()->createWithContent('network-import.csv', $csv),
            'default_type' => 'ukm',
            'default_status' => 'draft',
        ]);

        $response
            ->assertRedirect(route('admin.network.index'))
            ->assertSessionHas('status', fn (string $message): bool => str_contains($message, '1 data baru masuk ke heatmap')
                && str_contains($message, '1 baris dilewati'));

        $this->assertDatabaseHas('network_profiles', [
            'owner_id' => $hr->id,
            'owner_role' => UserRole::HR,
            'reference_name' => 'Input spreadsheet HR',
            'name' => 'Warung Sheet',
            'area_name' => 'Karanganyar',
            'latitude' => -6.3265,
            'longitude' => 108.324,
        ]);

        $this->assertDatabaseMissing('network_profiles', [
            'name' => 'Mitra Tanpa Titik',
        ]);
    }

    public function test_hr_import_rejects_html_instead_of_treating_it_as_csv(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->from(route('admin.network.index'))->post(route('admin.network.import'), [
            'csv_file' => UploadedFile::fake()->createWithContent('google-error.csv', '<!DOCTYPE html><html><body>Halaman Tidak Ditemukan</body></html>'),
            'default_type' => 'ukm',
            'default_status' => 'draft',
        ]);

        $response
            ->assertRedirect(route('admin.network.index'))
            ->assertSessionHasErrors('csv_file');

        $this->assertDatabaseMissing('network_profiles', [
            'reference_name' => 'Input spreadsheet HR',
        ]);
    }

    public function test_hr_can_import_legacy_dataukm_csv_for_heatmap(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $csv = implode("\n", [
            'Timestamp,iduser,IdUkm,NamaUser,NamaUkm,JenisProduk,Tipe,Kelurahan,Alamat,NamaPemilik,WAPemilik,LinkFoto,Lat,Long,GpsAddress',
            '2/24/2025 11:11:06,9,9-1740370231330,wildan,sate ayam bang otong,sate ayam,Warung Sayur,DKI Jakarta - Kota Jakarta Barat - Taman Sari - Krukut - 11140,Ruko Ketapang no 10,Otong,6283894553550,https://ik.imagekit.io/85dycihzm/tr:n-ik_ml_thumbnail/kunjungan_1740370263_rNo0ZW6g0.png,-6.15926,106.818,"SD Negeri Krukut 01, Jalan Ketapang Utara I, Krukut, Taman Sari"',
        ]);

        $response = $this->actingAs($hr)->post(route('admin.network.import'), [
            'csv_file' => UploadedFile::fake()->createWithContent('dataukm.csv', $csv),
            'default_type' => 'ukm',
            'default_status' => 'draft',
        ]);

        $response
            ->assertRedirect(route('admin.network.index'))
            ->assertSessionHas('status', fn (string $message): bool => str_contains($message, '1 data baru masuk ke heatmap'));

        $profile = NetworkProfile::query()->where('name', 'sate ayam bang otong')->firstOrFail();

        $this->assertSame('ukm', $profile->type);
        $this->assertSame('sate ayam', $profile->business_type);
        $this->assertSame('DKI Jakarta', $profile->territory_province);
        $this->assertSame('Kota Jakarta Barat', $profile->territory_city);
        $this->assertSame('Taman Sari', $profile->territory_district);
        $this->assertSame('Krukut', $profile->territory_subdistrict);
        $this->assertSame(-6.15926, $profile->latitude);
        $this->assertSame(106.818, $profile->longitude);
        $this->assertSame('6283894553550', $profile->phone_number);
        $this->assertSame('wildan', $profile->owner_name);
        $this->assertSame($hr->id, $profile->owner_id);
        $this->assertStringContainsString('ID CSV: 9-1740370231330', (string) $profile->note);
        $this->assertStringContainsString('Pemilik: Otong', (string) $profile->note);
        $this->assertIsArray($profile->photo_attachment);

        $updatedCsv = implode("\n", [
            'Timestamp,iduser,IdUkm,NamaUser,NamaUkm,JenisProduk,Tipe,Kelurahan,Alamat,NamaPemilik,WAPemilik,LinkFoto,Lat,Long,GpsAddress',
            '2/24/2025 11:11:06,9,9-1740370231330,budi,sate ayam bang otong,sate madura,Warung Sayur,DKI Jakarta - Kota Jakarta Barat - Taman Sari - Krukut - 11140,Ruko Ketapang no 10 updated,Bang Budi,6283894553550,https://ik.imagekit.io/85dycihzm/tr:n-ik_ml_thumbnail/kunjungan_1740370263_rNo0ZW6g0.png,-6.15926,106.818,"SD Negeri Krukut 01, Jalan Ketapang Utara I, Krukut, Taman Sari"',
        ]);

        $secondResponse = $this->actingAs($hr)->post(route('admin.network.import'), [
            'csv_file' => UploadedFile::fake()->createWithContent('dataukm.csv', $updatedCsv),
            'default_type' => 'ukm',
            'default_status' => 'draft',
        ]);

        $secondResponse
            ->assertRedirect(route('admin.network.index'))
            ->assertSessionHas('status', fn (string $message): bool => str_contains($message, '0 data baru masuk ke heatmap')
                && str_contains($message, '1 data diperbarui'));

        $this->assertSame(1, NetworkProfile::query()->where('name', 'sate ayam bang otong')->count());

        $profile->refresh();
        $this->assertSame('budi', $profile->owner_name);
        $this->assertSame('sate madura', $profile->business_type);
        $this->assertSame('Ruko Ketapang no 10 updated', $profile->address);
        $this->assertStringContainsString('Pemilik: Bang Budi', (string) $profile->note);
    }

    public function test_hr_can_export_network_monitoring_csv(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $hr = User::query()->findOrFail('usr_hr_001');

        $response = $this->actingAs($hr)->get(route('admin.network.index', ['export' => 'csv']));

        $response->assertDownload('network-monitoring.csv');
        $content = $response->streamedContent();
        $this->assertStringContainsString('ID,Type,Nama,Owner,"Owner Role",Area,Status,"Bidang Usaha",Alamat,"Follow-up Terakhir","Waktu Follow-up"', $content);
        $this->assertStringContainsString('net_fgg_001,ukm,"UKM Demo","Bima FGG",FGG', $content);
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
                )
                ->andReturn([
                    'target_users' => count($staffIds),
                    'tokens' => 1,
                    'sent' => 1,
                    'failed' => 0,
                    'skipped_reason' => null,
                ]);
        });

        $this->actingAs($hr)->post(route('admin.announcements.store'), [
            'title' => 'Reminder Staff',
            'body' => 'Isi announcement staff.',
            'target_roles' => [UserRole::STAFF],
            'is_active' => 1,
        ])
            ->assertRedirect(route('admin.announcements.index'))
            ->assertSessionHas('status', 'Announcement berhasil dipublikasikan. Push notification: 1 terkirim, 0 gagal, dari 1 token untuk ' . count($staffIds) . ' user target.');
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
