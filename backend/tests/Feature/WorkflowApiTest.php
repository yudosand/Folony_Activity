<?php

namespace Tests\Feature;

use App\Models\Announcement;
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
            'attachments' => [[
                'id' => 'leave_workflow_attachment_001',
                'file_name' => 'kontrol-kesehatan.jpg',
                'mime_type' => 'image/jpeg',
                'url' => 'https://cdn.example.test/kontrol-kesehatan.jpg',
                'thumbnail_url' => 'https://cdn.example.test/kontrol-kesehatan-thumb.jpg',
                'size_in_bytes' => 88000,
            ]],
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.requester_id', 'usr_001')
            ->assertJsonPath('data.status', 'pending');

        $this->assertCount(2, $response->json('data.approval_steps'));
        $this->assertSame('usr_spv_001', $response->json('data.approval_steps.0.approver_id'));
        $this->assertSame('usr_mgt_001', $response->json('data.approval_steps.1.approver_id'));
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

    public function test_authenticated_user_can_read_active_announcements(): void
    {
        $this->seed(WorkflowDemoSeeder::class);

        Announcement::query()->create([
            'title' => 'Briefing Operasional',
            'body' => 'Briefing dilakukan jam 08:15.',
            'is_active' => true,
            'published_at' => now()->subMinute(),
        ]);
        Announcement::query()->create([
            'title' => 'Draft Internal',
            'body' => 'Tidak boleh tampil di aplikasi.',
            'is_active' => false,
            'published_at' => now()->subMinute(),
        ]);

        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $response = $this->getJson('/api/announcements');

        $response
            ->assertOk()
            ->assertJsonPath('data.0.title', 'Briefing Operasional')
            ->assertJsonMissing(['title' => 'Draft Internal']);
    }

    public function test_authenticated_user_can_update_profile_photo(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $response = $this->postJson('/api/profile/photo', [
            'profile_photo' => [
                'id' => 'profile_photo_001',
                'file_name' => 'nadia-profile.jpg',
                'mime_type' => 'image/jpeg',
                'url' => 'https://cdn.example.test/nadia-profile.jpg',
                'thumbnail_url' => 'https://cdn.example.test/nadia-profile-thumb.jpg',
                'size_in_bytes' => 128000,
            ],
        ]);

        $response
            ->assertOk()
            ->assertJsonPath('data.profile_photo.id', 'profile_photo_001');

        $this->assertSame(
            'profile_photo_001',
            User::query()->findOrFail('usr_001')->profile_photo_attachment['id'] ?? null
        );
    }

    public function test_authenticated_user_can_delete_profile_photo(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $user = User::query()->findOrFail('usr_001');
        $user->update([
            'profile_photo_attachment' => [
                'id' => 'profile_photo_001',
                'file_name' => 'nadia-profile.jpg',
                'mime_type' => 'image/jpeg',
                'url' => 'https://cdn.example.test/nadia-profile.jpg',
            ],
        ]);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/profile/photo')
            ->assertOk()
            ->assertJsonPath('data.profile_photo', null);

        $this->assertNull(User::query()->findOrFail('usr_001')->profile_photo_attachment);
    }
}
