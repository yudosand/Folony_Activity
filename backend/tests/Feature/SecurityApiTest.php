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

    public function test_login_rejects_invalid_credentials_and_requires_known_identifier(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $this->postJson('/api/auth/login', [
            'identifier' => 'asal-sekali',
            'password' => '123456',
        ])->assertStatus(422);

        $this->postJson('/api/auth/login', [
            'identifier' => 'Nadia Staff',
            'password' => '123456',
        ])->assertStatus(422);

        $this->postJson('/api/auth/login', [
            'identifier' => 'EMP-STF-001',
            'password' => '123456',
        ])->assertOk()
            ->assertJsonPath('data.user.id', 'usr_001');
    }

    public function test_fgg_cannot_open_team_ukm_endpoint(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_fgg_001'));

        $this->getJson('/api/network/team-ukm')
            ->assertForbidden();
    }

    public function test_staff_cannot_update_network_profile_owned_by_other_area(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $this->patchJson('/api/network/net_fgg_001', [
            'type' => 'ukm',
            'name' => 'Override tidak sah',
            'address' => 'Alamat override',
            'territory_province' => 'DKI Jakarta',
            'territory_city' => 'Jakarta Selatan',
            'territory_district' => 'Pasar Minggu',
            'territory_subdistrict' => 'Pejaten Timur',
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

    public function test_me_endpoint_requires_authentication_and_ignores_user_id_fallback(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $this->getJson('/api/me?user_id=usr_001')
            ->assertUnauthorized();
    }

    public function test_authenticated_user_can_change_password(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $user = User::query()->findOrFail('usr_001');
        Sanctum::actingAs($user);

        $this->postJson('/api/auth/change-password', [
            'current_password' => '123456',
            'new_password' => '654321',
            'new_password_confirmation' => '654321',
        ])->assertOk()
            ->assertJsonPath('data.password_changed', true);

        $this->postJson('/api/auth/logout')->assertOk();

        $this->postJson('/api/auth/login', [
            'identifier' => 'EMP-STF-001',
            'password' => '654321',
        ])->assertOk()
            ->assertJsonPath('data.user.id', 'usr_001');
    }

    public function test_change_password_rejects_wrong_current_password(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $user = User::query()->findOrFail('usr_001');
        Sanctum::actingAs($user);

        $this->postJson('/api/auth/change-password', [
            'current_password' => 'salah-total',
            'new_password' => '654321',
            'new_password_confirmation' => '654321',
        ])->assertStatus(422);
    }

    public function test_authenticated_user_can_register_push_token(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $user = User::query()->findOrFail('usr_001');
        Sanctum::actingAs($user);

        $this->postJson('/api/devices/push-token', [
            'token' => 'fcm-token-001',
            'platform' => 'android',
            'device_name' => 'pixel-test',
            'app_version' => '0.1.0+1',
        ])->assertOk()
            ->assertJsonPath('data.registered', true);

        $this->assertDatabaseHas('push_device_tokens', [
            'user_id' => 'usr_001',
            'platform' => 'android',
            'token' => 'fcm-token-001',
        ]);
    }
}
