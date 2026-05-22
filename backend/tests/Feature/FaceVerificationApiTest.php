<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FaceVerificationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_enroll_face_profile_and_read_it_back(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $payload = [
            'samples' => [
                $this->sample('sample-1'),
                $this->sample('sample-2'),
                $this->sample('sample-3'),
            ],
            'biometric_template' => $this->signature('match'),
        ];

        $this->postJson('/api/face/profile', $payload)
            ->assertCreated()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.samples_count', 3);

        $this->getJson('/api/face/profile')
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.samples_count', 3);
    }

    public function test_user_with_face_profile_can_pass_mvp_face_verification_gate(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $this->postJson('/api/face/profile', [
            'samples' => [
                $this->sample('sample-1'),
                $this->sample('sample-2'),
                $this->sample('sample-3'),
            ],
            'biometric_template' => $this->signature('match'),
        ])->assertCreated();

        $this->postJson('/api/face/verify', [
            'action' => 'checkIn',
            'capture' => $this->sample('capture-1'),
            'signature' => $this->signature('match'),
            'liveness_score' => 100,
        ])->assertCreated()
            ->assertJsonPath('data.verified', true)
            ->assertJsonPath('data.decision', 'verified')
            ->assertJsonPath('data.profile.status', 'active')
            ->assertJsonPath('data.match_score', 100);
    }

    public function test_user_without_enrollment_is_rejected_by_mvp_face_verification_gate(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $this->postJson('/api/face/verify', [
            'action' => 'checkIn',
            'capture' => $this->sample('capture-1'),
            'signature' => $this->signature('match'),
            'liveness_score' => 100,
        ])->assertOk()
            ->assertJsonPath('data.verified', false)
            ->assertJsonPath('data.decision', 'rejected')
            ->assertJsonPath('data.profile.status', 'pending');
    }

    public function test_user_with_low_similarity_is_rejected_by_face_match_threshold(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $this->postJson('/api/face/profile', [
            'samples' => [
                $this->sample('sample-1'),
                $this->sample('sample-2'),
                $this->sample('sample-3'),
            ],
            'biometric_template' => $this->signature('match'),
        ])->assertCreated();

        $this->postJson('/api/face/verify', [
            'action' => 'checkIn',
            'capture' => $this->sample('capture-1'),
            'signature' => $this->signature('mismatch'),
            'liveness_score' => 100,
        ])->assertOk()
            ->assertJsonPath('data.verified', false)
            ->assertJsonPath('data.decision', 'rejected');
    }

    public function test_user_with_borderline_scores_is_asked_to_retry(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_001'));

        $this->postJson('/api/face/profile', [
            'samples' => [
                $this->sample('sample-1'),
                $this->sample('sample-2'),
                $this->sample('sample-3'),
            ],
            'biometric_template' => $this->signature('match'),
        ])->assertCreated();

        $this->postJson('/api/face/verify', [
            'action' => 'checkIn',
            'capture' => $this->sample('capture-1'),
            'signature' => $this->signature('borderline'),
            'liveness_score' => 60,
        ])->assertOk()
            ->assertJsonPath('data.verified', false)
            ->assertJsonPath('data.decision', 'retry');
    }

    private function sample(string $id): array
    {
        return [
            'id' => $id,
            'file_name' => $id . '.jpg',
            'mime_type' => 'image/jpeg',
            'url' => 'https://cdn.example.test/' . $id . '.jpg',
            'thumbnail_url' => 'https://cdn.example.test/' . $id . '-thumb.jpg',
            'size_in_bytes' => 120045,
        ];
    }

    private function signature(string $variant): array
    {
        if ($variant === 'borderline') {
            return array_fill(0, 127, 0.088388) + [127 => -0.088388];
        }

        if ($variant === 'mismatch') {
            return array_fill(0, 128, -0.088388);
        }

        return array_fill(0, 128, 0.088388);
    }
}
