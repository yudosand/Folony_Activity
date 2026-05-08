<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
            'address' => 'Sawangan Depok',
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

    public function test_follow_up_history_is_recorded_and_visible_from_fgg_to_area_manager(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));
        $createResponse = $this->postJson('/api/network', [
            'id' => 'net_followup_e2e',
            'type' => 'ukm',
            'name' => 'UKM Follow Up Bersama',
            'address' => 'Depok',
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
                'latitude' => -6.2,
                'longitude' => 106.8166,
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
            ->assertJsonPath('data.action', 'checkIn');

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
                'latitude' => -6.2,
                'longitude' => 106.8166,
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
}
