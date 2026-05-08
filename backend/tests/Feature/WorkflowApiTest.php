<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkflowApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_leave_request_can_be_created_with_approval_steps(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $response = $this->postJson('/api/leave', [
            'requester_id' => 'usr_001',
            'category' => 'izinPerHari',
            'compensation_option' => 'tidakPotongGaji',
            'start_at' => now()->startOfDay()->toIso8601String(),
            'end_at' => now()->addDay()->startOfDay()->toIso8601String(),
            'duration_value' => 1,
            'reason' => 'Kontrol kesehatan keluarga',
            'delegate_to' => 'Tim Operasional',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.requester_id', 'usr_001')
            ->assertJsonPath('data.status', 'pending');

        $this->assertCount(2, $response->json('data.approval_steps'));
    }

    public function test_management_inbox_returns_pending_leave_after_spv_approval(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_mgt_001'));

        $response = $this->getJson('/api/approvals/inbox?approver_id=usr_mgt_001&module=leave');

        $response
            ->assertOk()
            ->assertJsonPath('data.0.module', 'leave')
            ->assertJsonPath('data.0.reference_id', 'leave_001');
    }

    public function test_management_can_approve_leave_using_composite_identifier(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_mgt_001'));

        $response = $this->postJson('/api/approvals/leave::leave_001/approve', [
            'approver_id' => 'usr_mgt_001',
            'note' => 'Disetujui management.',
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('data.module', 'leave')
            ->assertJsonPath('data.reference_id', 'leave_001')
            ->assertJsonPath('data.status', 'approved');
    }

    public function test_auth_login_returns_token_and_user_payload(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        $response = $this->postJson('/api/auth/login', [
            'identifier' => '084444444444',
            'password' => '123456',
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('data.user.id', 'usr_area_001')
            ->assertJsonPath('data.user.role', 'areaManager');
        $this->assertNotEmpty($response->json('data.token'));
    }
}
