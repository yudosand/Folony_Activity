<?php

namespace Tests\Feature;

use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\PerformanceTarget;
use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PerformanceTargetApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_fgg_summary_counts_new_ukm_and_follow_up_for_current_month(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $fgg = User::query()->findOrFail('usr_fgg_001');

        PerformanceTarget::query()->create([
            'user_id' => $fgg->id,
            'metric_key' => 'fgg_new_ukm',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 50,
        ]);
        PerformanceTarget::query()->create([
            'user_id' => $fgg->id,
            'metric_key' => 'fgg_follow_up_visit',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 20,
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_target_fgg_001',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => 'Pasar Minggu',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Ragunan',
            'type' => 'ukm',
            'name' => 'UKM Target FGG 1',
            'address' => 'Jl. Ragunan',
            'business_type' => 'Kuliner',
            'phone_number' => '081300000301',
            'status' => 'draft',
            'created_at' => now()->subDays(2),
            'updated_at' => now()->subDays(2),
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_target_fgg_002',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => 'Pasar Minggu',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Jati Padang',
            'type' => 'ukm',
            'name' => 'UKM Target FGG 2',
            'address' => 'Jl. Jati Padang',
            'business_type' => 'Retail',
            'phone_number' => '081300000302',
            'status' => 'followUp',
            'created_at' => now()->subDay(),
            'updated_at' => now()->subDay(),
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_target_fgg_old',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => 'Pasar Minggu',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Pejaten Barat',
            'type' => 'ukm',
            'name' => 'UKM Target FGG Lama',
            'address' => 'Jl. Lama',
            'business_type' => 'Retail',
            'phone_number' => '081300000303',
            'status' => 'followUp',
            'created_at' => now()->subMonth()->startOfMonth(),
            'updated_at' => now()->subMonth()->startOfMonth(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_target_fgg_001',
            'network_profile_id' => 'net_target_fgg_001',
            'title' => 'Visit 1',
            'note' => 'Draft pun dihitung.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now()->subDay(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_target_fgg_002',
            'network_profile_id' => 'net_target_fgg_002',
            'title' => 'Visit 2',
            'note' => 'Follow-up dihitung.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_target_fgg_old',
            'network_profile_id' => 'net_target_fgg_old',
            'title' => 'Visit Lama',
            'note' => 'Bulan lalu tidak dihitung.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now()->subMonth()->startOfMonth(),
        ]);

        Sanctum::actingAs($fgg);

        $this->getJson('/api/performance/summary')
            ->assertOk()
            ->assertJsonPath('data.role', 'fgg')
            ->assertJsonPath('data.metrics.0.key', 'fgg_new_ukm')
            ->assertJsonPath('data.metrics.0.actual_value', 4)
            ->assertJsonPath('data.metrics.0.target_value', 50)
            ->assertJsonPath('data.metrics.1.key', 'fgg_follow_up_visit')
            ->assertJsonPath('data.metrics.1.actual_value', 3)
            ->assertJsonPath('data.metrics.1.target_value', 20);
    }

    public function test_area_manager_summary_counts_team_ukm_own_ukm_own_mitra_and_team_visits(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $areaManager = User::query()->findOrFail('usr_area_001');
        $fgg = User::query()->findOrFail('usr_fgg_001');

        PerformanceTarget::query()->create([
            'user_id' => $areaManager->id,
            'metric_key' => 'area_manager_team_new_ukm',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 100,
        ]);
        PerformanceTarget::query()->create([
            'user_id' => $areaManager->id,
            'metric_key' => 'area_manager_new_mitra',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 20,
        ]);
        PerformanceTarget::query()->create([
            'user_id' => $areaManager->id,
            'metric_key' => 'area_manager_team_follow_up_visit',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 100,
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_am_team_ukm_001',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => 'Pasar Minggu',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Ragunan',
            'type' => 'ukm',
            'name' => 'UKM Tim 1',
            'address' => 'Jl. Ragunan',
            'business_type' => 'Retail',
            'phone_number' => '081300000401',
            'status' => 'draft',
            'created_at' => now()->subDays(3),
            'updated_at' => now()->subDays(3),
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_am_own_ukm_001',
            'owner_id' => $areaManager->id,
            'owner_name' => $areaManager->full_name,
            'owner_role' => $areaManager->role,
            'area_name' => 'DKI Jakarta',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Keagungan',
            'type' => 'ukm',
            'name' => 'UKM Area Manager 1',
            'address' => 'Jl. Keagungan',
            'business_type' => 'Retail',
            'phone_number' => '081300000402',
            'status' => 'draft',
            'created_at' => now()->subDays(2),
            'updated_at' => now()->subDays(2),
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_am_own_mitra_001',
            'owner_id' => $areaManager->id,
            'owner_name' => $areaManager->full_name,
            'owner_role' => $areaManager->role,
            'area_name' => 'DKI Jakarta',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Glodok',
            'type' => 'mitra',
            'name' => 'Mitra Area Manager 1',
            'address' => 'Jl. Glodok',
            'business_type' => 'Mitra',
            'phone_number' => '081300000403',
            'status' => 'draft',
            'created_at' => now()->subDay(),
            'updated_at' => now()->subDay(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_am_team_001',
            'network_profile_id' => 'net_am_team_ukm_001',
            'title' => 'Visit Tim 1',
            'note' => 'Dihitung ke tim.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now()->subDay(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_am_team_002',
            'network_profile_id' => 'net_fgg_001',
            'title' => 'Visit Tim 2',
            'note' => 'Masuk kunjungan tim.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now(),
        ]);

        Sanctum::actingAs($areaManager);

        $this->getJson('/api/performance/summary')
            ->assertOk()
            ->assertJsonPath('data.role', 'areaManager')
            ->assertJsonPath('data.metrics.0.key', 'area_manager_team_new_ukm')
            ->assertJsonPath('data.metrics.0.actual_value', 3)
            ->assertJsonPath('data.metrics.0.target_value', 100)
            ->assertJsonPath('data.metrics.1.key', 'area_manager_new_mitra')
            ->assertJsonPath('data.metrics.1.actual_value', 2)
            ->assertJsonPath('data.metrics.1.target_value', 20)
            ->assertJsonPath('data.metrics.2.key', 'area_manager_team_follow_up_visit')
            ->assertJsonPath('data.metrics.2.actual_value', 3)
            ->assertJsonPath('data.metrics.2.target_value', 100);
    }

    public function test_area_manager_summary_respects_exclude_rule_for_team_metrics(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $fgg = User::query()->findOrFail('usr_fgg_001');

        $areaManager = User::query()->create([
            'id' => 'usr_area_target_exclude_001',
            'employee_code' => 'EMP-AM-TARGET-EX-001',
            'full_name' => 'Area Target Exclude',
            'phone_number' => '081300000999',
            'area_name' => 'DKI Jakarta (kecuali Mangga Besar)',
            'work_location' => 'DKI Jakarta',
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

        PerformanceTarget::query()->create([
            'user_id' => $areaManager->id,
            'metric_key' => 'area_manager_team_new_ukm',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 100,
        ]);
        PerformanceTarget::query()->create([
            'user_id' => $areaManager->id,
            'metric_key' => 'area_manager_team_follow_up_visit',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 100,
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_target_allowed_001',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => 'Keagungan',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Keagungan',
            'type' => 'ukm',
            'name' => 'UKM Allowed Area',
            'address' => 'Jl. Keagungan',
            'business_type' => 'Retail',
            'phone_number' => '081300000901',
            'status' => 'draft',
            'created_at' => now()->subDay(),
            'updated_at' => now()->subDay(),
        ]);

        NetworkProfile::query()->create([
            'id' => 'net_target_excluded_001',
            'owner_id' => $fgg->id,
            'owner_name' => $fgg->full_name,
            'owner_role' => $fgg->role,
            'area_name' => 'Mangga Besar',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Kota Administrasi Jakarta Barat',
            'territory_district' => 'Taman Sari',
            'territory_subdistrict' => 'Mangga Besar',
            'type' => 'ukm',
            'name' => 'UKM Excluded Area',
            'address' => 'Jl. Mangga Besar',
            'business_type' => 'Retail',
            'phone_number' => '081300000902',
            'status' => 'draft',
            'created_at' => now()->subDay(),
            'updated_at' => now()->subDay(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_target_allowed_001',
            'network_profile_id' => 'net_target_allowed_001',
            'title' => 'Visit Allowed',
            'note' => 'Masuk hitungan.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now(),
        ]);

        NetworkFollowUp::query()->create([
            'id' => 'fu_target_excluded_001',
            'network_profile_id' => 'net_target_excluded_001',
            'title' => 'Visit Excluded',
            'note' => 'Tidak boleh dihitung.',
            'actor_id' => $fgg->id,
            'actor_name' => $fgg->full_name,
            'created_at' => now(),
        ]);

        Sanctum::actingAs($areaManager);

        $this->getJson('/api/performance/summary')
            ->assertOk()
            ->assertJsonPath('data.metrics.0.actual_value', 2)
            ->assertJsonPath('data.metrics.2.actual_value', 2);
    }

    public function test_latest_active_target_carries_forward_when_current_month_target_is_missing(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $fgg = User::query()->findOrFail('usr_fgg_001');

        PerformanceTarget::query()->create([
            'user_id' => $fgg->id,
            'metric_key' => 'fgg_new_ukm',
            'period_year' => (int) now()->subMonth()->format('Y'),
            'period_month' => (int) now()->subMonth()->format('m'),
            'target_value' => 60,
        ]);

        Sanctum::actingAs($fgg);

        $this->getJson('/api/performance/summary')
            ->assertOk()
            ->assertJsonPath('data.metrics.0.key', 'fgg_new_ukm')
            ->assertJsonPath('data.metrics.0.target_value', 60);
    }

    public function test_latest_active_target_value_is_used_immediately_in_current_month(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $fgg = User::query()->findOrFail('usr_fgg_001');

        PerformanceTarget::query()->create([
            'user_id' => $fgg->id,
            'metric_key' => 'fgg_new_ukm',
            'period_year' => (int) now()->subMonth()->format('Y'),
            'period_month' => (int) now()->subMonth()->format('m'),
            'target_value' => 50,
        ]);

        PerformanceTarget::query()->create([
            'user_id' => $fgg->id,
            'metric_key' => 'fgg_new_ukm',
            'period_year' => (int) now()->format('Y'),
            'period_month' => (int) now()->format('m'),
            'target_value' => 75,
        ]);

        Sanctum::actingAs($fgg);

        $this->getJson('/api/performance/summary')
            ->assertOk()
            ->assertJsonPath('data.metrics.0.key', 'fgg_new_ukm')
            ->assertJsonPath('data.metrics.0.target_value', 75);
    }
}
