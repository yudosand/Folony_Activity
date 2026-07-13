<?php

namespace Tests\Feature;

use App\Models\NetworkProfile;
use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FieldOpsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_fgg_can_create_network_profile(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));

        $response = $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Sinar Jaya',
            'address' => 'Jl. Raya Ragunan No. 12',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Ragunan',
            'business_type' => 'Kuliner',
            'phone_number' => '081300000001',
            'status' => 'draft',
            'note' => 'Input dari batch testing.',
            'latitude' => -6.3901000,
            'longitude' => 106.8112000,
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.owner_id', 'usr_fgg_001')
            ->assertJsonPath('data.type', 'ukm')
            ->assertJsonPath('data.name', 'UKM Sinar Jaya');
    }

    public function test_area_manager_can_read_team_ukm(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));

        $response = $this->getJson('/api/network/team-ukm');

        $response
            ->assertOk()
            ->assertJsonPath('data.0.owner_role', 'fgg')
            ->assertJsonPath('data.0.id', 'net_fgg_001');
    }

    public function test_province_area_manager_can_read_fgg_ukm_from_other_city_and_district_in_same_province(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $fgg = User::query()->create([
            'id' => 'usr_fgg_tamansari_001',
            'employee_code' => 'EMP-FGG-TS-001',
            'full_name' => 'Tester FGG Taman Sari',
            'phone_number' => '085500001111',
            'area_name' => 'Taman Sari',
            'work_location' => 'Jakarta Barat',
            'territory_scope' => 'district',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'role' => 'fgg',
            'job_title' => 'Field Growth Guide',
            'password' => '123456',
            'is_active' => true,
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_warung_kunkun',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => 'fgg',
            'area_name' => 'Taman Sari',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Keagungan',
            'type' => 'ukm',
            'name' => 'Warung Kunkun',
            'address' => 'Jl. Keagungan',
            'business_type' => 'Kelontong',
            'phone_number' => '081299998888',
            'status' => 'followUp',
        ]);

        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));

        $this->getJson('/api/network/team-ukm')
            ->assertOk()
            ->assertJsonFragment([
                'id' => 'net_warung_kunkun',
                'name' => 'Warung Kunkun',
                'territory_city' => 'Jakarta Barat',
                'territory_district' => 'Taman Sari',
            ]);
    }

    public function test_follow_up_history_is_recorded_and_visible_from_fgg_to_area_manager(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));
        $createResponse = $this->postJson('/api/network', [
            'id' => 'net_followup_e2e',
            'type' => 'ukm',
            'name' => 'UKM Follow Up Bersama',
            'address' => 'Jl. TB Simatupang No. 8',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Jati Padang',
            'business_type' => 'Retail',
            'phone_number' => '081300000555',
            'status' => 'draft',
        ]);

        $createResponse->assertCreated();

        $followUpResponse = $this->postJson('/api/network/net_followup_e2e/follow-ups', [
            'id' => 'followup_e2e_001',
            'title' => 'Kunjungan kedua',
            'note' => 'Pemilik siap lanjut ke tahap verifikasi dokumen.',
            'created_at' => now()->toIso8601String(),
            'next_status' => 'followUp',
        ]);

        $followUpResponse
            ->assertCreated()
            ->assertJsonPath('data.id', 'net_followup_e2e')
            ->assertJsonPath('data.follow_ups.0.title', 'Kunjungan kedua')
            ->assertJsonPath('data.follow_ups.0.note', 'Pemilik siap lanjut ke tahap verifikasi dokumen.');

        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));
        $teamResponse = $this->getJson('/api/network/team-ukm');

        $teamResponse
            ->assertOk()
            ->assertJsonFragment([
                'id' => 'net_followup_e2e',
                'owner_role' => 'fgg',
                'name' => 'UKM Follow Up Bersama',
            ])
            ->assertJsonFragment([
                'title' => 'Kunjungan kedua',
                'note' => 'Pemilik siap lanjut ke tahap verifikasi dokumen.',
            ]);
    }

    public function test_follow_up_submission_with_same_id_is_idempotent(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));
        $this->postJson('/api/network', [
            'id' => 'net_followup_single_submit',
            'type' => 'ukm',
            'name' => 'UKM Single Submit',
            'address' => 'Jl. Kebon Jeruk No. 8',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Jati Padang',
            'business_type' => 'Retail',
            'phone_number' => '081355550000',
            'status' => 'draft',
        ])->assertCreated();

        $payload = [
            'id' => 'followup_single_submit_001',
            'title' => 'Kunjungan lagi',
            'note' => 'Catatan follow-up tidak boleh dobel.',
            'created_at' => now()->toIso8601String(),
            'next_status' => 'followUp',
        ];

        $this->postJson('/api/network/net_followup_single_submit/follow-ups', $payload)
            ->assertCreated()
            ->assertJsonPath('data.follow_ups.0.title', 'Kunjungan lagi');

        $this->postJson('/api/network/net_followup_single_submit/follow-ups', $payload)
            ->assertCreated()
            ->assertJsonPath('data.follow_ups.0.title', 'Kunjungan lagi');

        $this->assertSame(
            1,
            DB::table('network_follow_ups')
                ->where('network_profile_id', 'net_followup_single_submit')
                ->where('id', 'followup_single_submit_001')
                ->count(),
        );
    }

    public function test_staff_can_submit_attendance_and_read_daily_summary(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $checkIn = $this->postJson('/api/attendance/check-in', [
            'id' => 'att_custom_001',
            'work_date' => now()->toIso8601String(),
            'recorded_at' => now()->setTime(8, 35)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -6.1596929,
                'longitude' => 106.8180445,
                'recorded_at' => now()->setTime(8, 35)->toIso8601String(),
                'address_label' => 'Client Site',
            ],
            'verification' => [
                'verified_at' => now()->setTime(8, 34)->toIso8601String(),
                'match_score' => 0.96,
                'liveness_score' => 0.94,
            ],
        ]);

        $checkIn
            ->assertCreated()
            ->assertJsonPath('data.action', 'checkIn')
            ->assertJsonPath('data.location.within_radius', true)
            ->assertJsonPath('data.location.work_area_name', 'Kantor Pusat');

        $summary = $this->getJson('/api/attendance/daily-summary?date=' . now()->toDateString());

        $summary
            ->assertOk()
            ->assertJsonPath('data.standard_start_time', '08:30')
            ->assertJsonStructure([
                'data' => [
                    'arrival_label',
                    'departure_label',
                    'summary_label',
                    'work_duration_minutes',
                ],
            ]);
    }

    public function test_attendance_duration_stays_zero_until_checkout_exists(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));
        $targetDate = now()->addDays(14);

        $this->postJson('/api/attendance/check-in', [
            'id' => 'att_checkin_only',
            'work_date' => $targetDate->toIso8601String(),
            'recorded_at' => $targetDate->copy()->setTime(8, 35)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -6.1596929,
                'longitude' => 106.8180445,
                'recorded_at' => $targetDate->copy()->setTime(8, 35)->toIso8601String(),
                'address_label' => 'Client Site',
            ],
        ])->assertCreated();

        $summary = $this->getJson('/api/attendance/daily-summary?date=' . $targetDate->toDateString());

        $summary
            ->assertOk()
            ->assertJsonPath('data.summary_label', 'Sesi aktif')
            ->assertJsonPath('data.work_duration_minutes', 0)
            ->assertJsonPath('data.summary_note', 'Durasi kerja akan dihitung setelah check-out.');
    }

    public function test_staff_cannot_submit_normal_attendance_outside_assigned_work_area_radius(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));
        $targetDate = now()->addDays(15);

        $this->postJson('/api/attendance/check-in', [
            'id' => 'att_checkin_far_001',
            'work_date' => $targetDate->toIso8601String(),
            'recorded_at' => $targetDate->copy()->setTime(9, 15)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -7.250445,
                'longitude' => 112.768845,
                'recorded_at' => $targetDate->copy()->setTime(9, 15)->toIso8601String(),
                'address_label' => 'Lokasi jauh dari kantor',
            ],
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['location'])
            ->assertJsonFragment([
                'location' => ['Anda tidak berada di area kantor.'],
            ]);
    }

    public function test_area_manager_outside_office_starts_on_click_and_finishes_on_save(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));
        $targetDate = now()->addDays(3);

        $this->postJson('/api/attendance/outside-office/start', [
            'id' => 'att_outside_start_001',
            'work_date' => $targetDate->toIso8601String(),
            'recorded_at' => $targetDate->copy()->setTime(9, 0)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -6.2001,
                'longitude' => 106.8167,
                'recorded_at' => $targetDate->copy()->setTime(9, 0)->toIso8601String(),
                'address_label' => 'Lokasi visit pagi',
            ],
            'verification' => [
                'verified_at' => $targetDate->copy()->setTime(8, 59)->toIso8601String(),
                'decision' => 'verified',
                'match_score' => 0.98,
                'liveness_score' => 0.96,
                'note' => 'Face verification passed.',
                'capture' => [
                    'id' => 'upload_face_001',
                    'file_name' => 'face-capture.jpg',
                    'mime_type' => 'image/jpeg',
                    'url' => 'https://example.test/face-capture.jpg',
                ],
            ],
            'metadata' => [
                'place_description' => 'Kunjungan client pagi di Tomang',
                'evidence_attachment' => [
                    'id' => 'upload_outside_start_001',
                    'file_name' => 'visit-start.jpg',
                    'mime_type' => 'image/jpeg',
                    'url' => 'https://example.test/visit-start.jpg',
                ],
            ],
        ])
            ->assertCreated()
            ->assertJsonPath('data.action', 'outsideOfficeStart')
            ->assertJsonPath('data.metadata.attendance_mode', 'outside_office')
            ->assertJsonPath('data.metadata.place_description', 'Kunjungan client pagi di Tomang')
            ->assertJsonPath('data.verification.decision', 'verified')
            ->assertJsonPath('data.verification.capture.id', 'upload_face_001');

        $this->postJson('/api/attendance/outside-office/finish', [
            'id' => 'att_outside_finish_001',
            'work_date' => $targetDate->toIso8601String(),
            'recorded_at' => $targetDate->copy()->setTime(11, 30)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -6.2002,
                'longitude' => 106.8168,
                'recorded_at' => $targetDate->copy()->setTime(11, 30)->toIso8601String(),
                'address_label' => 'Lokasi visit siang',
            ],
            'verification' => [
                'verified_at' => $targetDate->copy()->setTime(11, 29)->toIso8601String(),
                'decision' => 'verified',
                'match_score' => 0.97,
                'liveness_score' => 0.95,
                'note' => 'Face verification passed.',
                'capture' => [
                    'id' => 'upload_face_002',
                    'file_name' => 'face-capture-finish.jpg',
                    'mime_type' => 'image/jpeg',
                    'url' => 'https://example.test/face-capture-finish.jpg',
                ],
            ],
            'metadata' => [
                'place_description' => 'Follow up client siang di Tomang',
                'evidence_attachment' => [
                    'id' => 'upload_outside_office_001',
                    'file_name' => 'visit-proof.jpg',
                    'mime_type' => 'image/jpeg',
                    'url' => 'https://example.test/visit-proof.jpg',
                ],
            ],
        ])
            ->assertCreated()
            ->assertJsonPath('data.action', 'outsideOfficeFinish')
            ->assertJsonPath('data.metadata.place_description', 'Follow up client siang di Tomang')
            ->assertJsonPath('data.verification.capture.id', 'upload_face_002')
            ->assertJsonPath('data.metadata.duration_minutes', 150);
    }

    public function test_staff_can_use_outside_office_attendance(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));
        $targetDate = now()->addDays(4);

        $this->postJson('/api/attendance/outside-office/start', [
            'id' => 'att_outside_staff_start_001',
            'work_date' => $targetDate->toIso8601String(),
            'recorded_at' => $targetDate->copy()->setTime(10, 0)->toIso8601String(),
            'status' => 'success',
            'location' => [
                'latitude' => -6.1801,
                'longitude' => 106.8011,
                'recorded_at' => $targetDate->copy()->setTime(10, 0)->toIso8601String(),
                'address_label' => 'Kunjungan vendor',
            ],
            'metadata' => [
                'place_description' => 'Kunjungan vendor luar kantor',
                'evidence_attachment' => [
                    'id' => 'upload_staff_start_001',
                    'file_name' => 'staff-start.jpg',
                    'mime_type' => 'image/jpeg',
                    'url' => 'https://example.test/staff-start.jpg',
                ],
            ],
        ])->assertCreated()
            ->assertJsonPath('data.action', 'outsideOfficeStart')
            ->assertJsonPath('data.metadata.place_description', 'Kunjungan vendor luar kantor');
    }

    public function test_heat_map_returns_points_in_radius(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));

        $response = $this->getJson('/api/heat-map?latitude=-6.3690&longitude=106.8315&radius_meters=1200');

        $response
            ->assertOk()
            ->assertJsonPath('data.radius_meters', 1200)
            ->assertJsonFragment(['id' => 'net_fgg_001']);
    }

    public function test_fgg_cannot_create_network_profile_outside_registered_territory(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));

        $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Luar Area',
            'address' => 'Jl. Margonda Raya',
            'territory_province' => 'Jawa Barat',
            'territory_city' => 'Depok',
            'territory_district' => 'Pancoran Mas',
            'territory_subdistrict' => 'Depok',
            'business_type' => 'Retail',
            'phone_number' => '081399999999',
            'status' => 'draft',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['territory']);
    }

    public function test_replacement_fgg_in_same_territory_inherits_existing_ukm_data(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $replacement = User::query()->create([
            'id' => 'usr_fgg_002',
            'employee_code' => 'EMP-FGG-002',
            'full_name' => 'Rio FGG Baru',
            'phone_number' => '085566667777',
            'area_name' => 'Pasar Minggu',
            'work_location' => 'Pasar Minggu',
            'role' => 'fgg',
            'job_title' => 'Field Growth Guide',
            'territory_scope' => 'district',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'password' => '123456',
            'is_active' => true,
        ]);

        Sanctum::actingAs($replacement);

        $this->getJson('/api/network')
            ->assertOk()
            ->assertJsonFragment([
                'id' => 'net_fgg_001',
                'name' => 'UKM Toko Harapan',
            ]);

        $this->patchJson('/api/network/net_fgg_001', [
            'type' => 'ukm',
            'name' => 'UKM Toko Harapan Reassign',
            'address' => 'Pasar Minggu Blok A',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Pejaten Timur',
            'business_type' => 'Sembako',
            'phone_number' => '081234567890',
            'status' => 'followUp',
            'note' => 'Diambil alih FGG pengganti pada area yang sama.',
        ])->assertOk()
            ->assertJsonPath('data.owner_id', 'usr_fgg_002');
    }

    public function test_area_manager_can_read_legacy_team_ukm_by_area_name_when_structured_territory_is_missing(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $areaManager = User::query()->create([
            'id' => 'usr_area_grogol_001',
            'employee_code' => 'EMP-AM-777',
            'full_name' => 'Ari Area Grogol',
            'phone_number' => '081377778899',
            'area_name' => 'Grogol Petamburan',
            'work_location' => 'Grogol Petamburan',
            'role' => 'areaManager',
            'job_title' => 'Area Manager',
            'territory_scope' => 'district',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Grogol Petamburan',
            'password' => '123456',
            'is_active' => true,
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_legacy_grogol_001',
            'owner_id' => 'usr_fgg_001',
            'owner_name' => 'Bima FGG',
            'owner_role' => 'fgg',
            'area_name' => 'Grogol Petamburan',
            'type' => 'ukm',
            'name' => 'UKM Legacy Grogol',
            'address' => 'Jl. Kyai Tapa',
            'business_type' => 'Kuliner',
            'phone_number' => '081322223333',
            'status' => 'followUp',
        ]);

        Sanctum::actingAs($areaManager);

        $this->getJson('/api/network/team-ukm')
            ->assertOk()
            ->assertJsonFragment([
                'id' => 'net_legacy_grogol_001',
                'name' => 'UKM Legacy Grogol',
            ]);
    }

    public function test_fgg_with_multiple_district_assignments_can_create_ukm_in_any_registered_district(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $multiDistrictFgg = User::query()->create([
            'id' => 'usr_fgg_multi_001',
            'employee_code' => 'EMP-FGG-777',
            'full_name' => 'Nina FGG Multi',
            'phone_number' => '081388889999',
            'area_name' => 'Grogol Petamburan +1 wilayah',
            'work_location' => 'Jakarta Barat',
            'territory_scope' => 'district',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Grogol Petamburan',
            'territory_assignments' => [
                [
                    'territory_scope' => 'district',
                    'territory_province' => 'DKI Jakarta',
                    'territory_city' => 'Jakarta Barat',
                    'territory_district' => 'Grogol Petamburan',
                ],
                [
                    'territory_scope' => 'district',
                    'territory_province' => 'DKI Jakarta',
                    'territory_city' => 'Jakarta Barat',
                    'territory_district' => 'Palmerah',
                ],
            ],
            'role' => 'fgg',
            'job_title' => 'Field Growth Guide',
            'password' => '123456',
            'is_active' => true,
        ]);

        Sanctum::actingAs($multiDistrictFgg);

        $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Grogol Baru',
            'address' => 'Jl. Dr. Susilo',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Grogol Petamburan',
            'territory_subdistrict' => 'Grogol',
            'business_type' => 'Retail',
            'phone_number' => '081311112222',
            'status' => 'draft',
        ])->assertCreated();

        $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Palmerah Baru',
            'address' => 'Jl. Palmerah Barat',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Palmerah',
            'territory_subdistrict' => 'Palmerah',
            'business_type' => 'Retail',
            'phone_number' => '081333334444',
            'status' => 'draft',
        ])->assertCreated();

        $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Cengkareng Ditolak',
            'address' => 'Jl. Kamal Raya',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Cengkareng',
            'territory_subdistrict' => 'Cengkareng Barat',
            'business_type' => 'Retail',
            'phone_number' => '081355556666',
            'status' => 'draft',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['territory']);
    }

    public function test_area_manager_include_and_exclude_rules_allow_large_coverage_with_small_hole(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $areaManager = User::query()->create([
            'id' => 'usr_area_rules_001',
            'employee_code' => 'EMP-AM-RULES-001',
            'full_name' => 'Raka Rules Area Manager',
            'phone_number' => '081300001111',
            'area_name' => 'DKI Jakarta +1 wilayah (kecuali Mangga Besar)',
            'work_location' => 'Multi area',
            'role' => 'areaManager',
            'job_title' => 'Area Manager',
            'territory_scope' => 'province',
            'territory_province' => 'DKI Jakarta',
            'territory_assignments' => [
                [
                    'rule_type' => 'include',
                    'territory_scope' => 'province',
                    'territory_province' => 'DKI Jakarta',
                ],
                [
                    'rule_type' => 'include',
                    'territory_scope' => 'province',
                    'territory_province' => 'Banten',
                ],
                [
                    'rule_type' => 'exclude',
                    'territory_scope' => 'subdistrict',
                    'territory_province' => 'DKI Jakarta',
                    'territory_city' => 'Kota Administrasi Jakarta Barat',
                    'territory_district' => 'Taman Sari',
                    'territory_subdistrict' => 'Mangga Besar',
                ],
            ],
            'password' => '123456',
            'is_active' => true,
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_allowed_dki_001',
            'owner_id' => 'usr_fgg_001',
            'owner_name' => 'Bima FGG',
            'owner_role' => 'fgg',
            'area_name' => 'Taman Sari',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Keagungan',
            'type' => 'ukm',
            'name' => 'UKM DKI Allowed',
            'address' => 'Jl. Keagungan',
            'business_type' => 'Kuliner',
            'phone_number' => '081300000101',
            'status' => 'followUp',
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_excluded_subdistrict_001',
            'owner_id' => 'usr_fgg_001',
            'owner_name' => 'Bima FGG',
            'owner_role' => 'fgg',
            'area_name' => 'Mangga Besar',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Mangga Besar',
            'type' => 'ukm',
            'name' => 'UKM DKI Excluded',
            'address' => 'Jl. Mangga Besar',
            'business_type' => 'Retail',
            'phone_number' => '081300000102',
            'status' => 'followUp',
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_allowed_banten_001',
            'owner_id' => 'usr_fgg_001',
            'owner_name' => 'Bima FGG',
            'owner_role' => 'fgg',
            'area_name' => 'Serpong',
            'territory_province' => 'Banten',
            'territory_city' => 'Kota Tangerang Selatan',
            'territory_district' => 'Serpong',
            'territory_subdistrict' => 'Serpong',
            'type' => 'ukm',
            'name' => 'UKM Banten Allowed',
            'address' => 'Jl. Serpong Raya',
            'business_type' => 'Retail',
            'phone_number' => '081300000103',
            'status' => 'followUp',
        ]);

        Sanctum::actingAs($areaManager);

        $this->getJson('/api/network/team-ukm')
            ->assertOk()
            ->assertJsonFragment(['id' => 'net_allowed_dki_001', 'name' => 'UKM DKI Allowed'])
            ->assertJsonFragment(['id' => 'net_allowed_banten_001', 'name' => 'UKM Banten Allowed'])
            ->assertJsonMissing(['id' => 'net_excluded_subdistrict_001', 'name' => 'UKM DKI Excluded']);
    }

    public function test_fgg_include_and_exclude_rules_block_excluded_subdistrict_even_when_parent_city_is_included(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $fgg = User::query()->create([
            'id' => 'usr_fgg_rules_001',
            'employee_code' => 'EMP-FGG-RULES-001',
            'full_name' => 'Nina FGG Rules',
            'phone_number' => '081300001222',
            'area_name' => 'Jakarta Barat (kecuali Mangga Besar)',
            'work_location' => 'Jakarta Barat',
            'territory_scope' => 'city',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_assignments' => [
                [
                    'rule_type' => 'include',
                    'territory_scope' => 'city',
                    'territory_province' => 'DKI Jakarta',
                    'territory_city' => 'Kota Administrasi Jakarta Barat',
                ],
                [
                    'rule_type' => 'exclude',
                    'territory_scope' => 'subdistrict',
                    'territory_province' => 'DKI Jakarta',
                    'territory_city' => 'Kota Administrasi Jakarta Barat',
                    'territory_district' => 'Taman Sari',
                    'territory_subdistrict' => 'Mangga Besar',
                ],
            ],
            'role' => 'fgg',
            'job_title' => 'Field Growth Guide',
            'password' => '123456',
            'is_active' => true,
        ]);

        Sanctum::actingAs($fgg);

        $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Keagungan Aman',
            'address' => 'Jl. Keagungan',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Keagungan',
            'business_type' => 'Kuliner',
            'phone_number' => '081300000201',
            'status' => 'draft',
        ])->assertCreated();

        $this->postJson('/api/network', [
            'type' => 'ukm',
            'name' => 'UKM Mangga Besar Ditolak',
            'address' => 'Jl. Mangga Besar',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Mangga Besar',
            'business_type' => 'Kuliner',
            'phone_number' => '081300000202',
            'status' => 'draft',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['territory']);
    }
}
