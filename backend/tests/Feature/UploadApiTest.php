<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UploadApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_upload_attachment(): void
    {
        Storage::fake('public');
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::query()->findOrFail('usr_area_001'));

        $response = $this->post('/api/uploads/attachments', [
            'label' => 'Bukti meeting',
            'file' => UploadedFile::fake()->create(
                'meeting.jpg',
                120,
                'image/jpeg',
            ),
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('data.file_name', 'Bukti meeting')
            ->assertJsonPath('data.mime_type', 'image/jpeg');
    }
}
