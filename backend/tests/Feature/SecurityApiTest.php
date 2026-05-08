<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SecurityApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_fgg_cannot_open_team_ukm_endpoint(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));

        $this->getJson('/api/network/team-ukm')
            ->assertForbidden();
    }

    public function test_user_cannot_update_network_profile_owned_by_another_user(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));

        $this->patchJson('/api/network/net_fgg_001', [
            'type' => 'ukm',
            'name' => 'Override tidak sah',
            'address' => 'Alamat override',
            'business_type' => 'Override',
            'phone_number' => '081300000000',
            'status' => 'draft',
        ])->assertForbidden();
    }

    public function test_upload_endpoint_requires_authentication(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $this->post('/api/uploads/attachments')
            ->assertUnauthorized();
    }
}
