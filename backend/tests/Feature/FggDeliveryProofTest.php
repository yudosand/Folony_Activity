<?php

namespace Tests\Feature;

use App\Models\FggAccount;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class FggDeliveryProofTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    private array $payload;

    protected function setUp(): void
    {
        parent::setUp();
        config(['fgg.environment' => 'staging']);
        Storage::fake('local');
        Http::preventStrayRequests();
        $this->operator = User::factory()->create(['role' => 'fgg']);
        FggAccount::create(['user_id' => $this->operator->id, 'environment' => 'staging',
            'member_id' => '11', 'hub_id' => 'HUB12', 'name' => 'Operator', 'token' => 'test-token',
            'hubs' => [['id' => 'HUB12', 'name' => 'Hub']]]);
        $this->payload = ['transaction_id' => 123, 'buktiFoto' => base64_encode(file_get_contents(public_path('favicon.png'))),
            'latitude' => -6.2, 'longitude' => 106.8, 'accuracy_meters' => 12, 'captured_at' => now()->toIso8601String()];
    }

    public function test_successful_proof_is_preserved_on_duplicate_and_viewable_only_by_hr(): void
    {
        Http::fake(['https://dev.foodukm.com/app/api_hub_kirim_pesanan' => Http::response(['statusCode' => 1])]);
        $this->actingAs($this->operator)->postJson('/api/fgg/actions/send', $this->payload)->assertOk();
        $op = DB::table('fgg_operations')->first();
        Storage::disk('local')->assertExists($op->proof_path);
        $this->assertSame(base64_decode($this->payload['buktiFoto']), Storage::disk('local')->get($op->proof_path));
        $otherImage = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aH1cAAAAASUVORK5CYII=';
        $this->postJson('/api/fgg/actions/send', [...$this->payload, 'buktiFoto' => $otherImage])->assertOk();
        Http::assertSentCount(1);
        $this->assertSame($op->proof_path, DB::table('fgg_operations')->value('proof_path'));
        $this->assertCount(1, Storage::disk('local')->allFiles());
        $url = route('admin.network.activities.proof', $op->id);
        $this->get($url)->assertForbidden();
        $this->actingAs(User::factory()->create(['role' => 'hr']));
        $this->get(route('admin.network.activities.show', ['employee' => $this->operator->id, 'date' => now()->toDateString()]))
            ->assertOk()->assertSee($url)->assertSee('Buka foto bukti pengiriman');
        $response = $this->get($url)->assertOk()->assertHeader('Content-Type', 'image/png');
        $this->assertSame(base64_decode($this->payload['buktiFoto']), $response->streamedContent());
        foreach ([['state' => 'unknown'], ['state' => 'succeeded', 'environment' => 'production'],
            ['environment' => 'staging', 'proof_path' => null]] as $change) {
            DB::table('fgg_operations')->where('id', $op->id)->update($change);
            $this->get($url)->assertNotFound();
        }
    }

    public function test_storage_failure_never_sends_order_and_allows_retry(): void
    {
        $manager = Storage::getFacadeRoot();
        Storage::shouldReceive('disk')->with('local')->once()->andReturn(new class
        {
            public function put($path, $bytes): bool
            {
                return false;
            }
        });
        $this->actingAs($this->operator)->postJson('/api/fgg/actions/send', $this->payload)->assertStatus(503);
        Http::assertNothingSent();
        $this->assertDatabaseHas('fgg_operations', ['state' => 'rejected', 'proof_path' => null]);
        Storage::swap($manager);
        Http::fake(['https://dev.foodukm.com/app/api_hub_kirim_pesanan' => Http::response(['statusCode' => 1])]);
        $this->postJson('/api/fgg/actions/send', $this->payload)->assertOk();
        Storage::disk('local')->assertExists(DB::table('fgg_operations')->value('proof_path'));
    }

    public function test_unknown_upstream_result_keeps_proof_but_does_not_allow_resending(): void
    {
        Http::fake(['https://dev.foodukm.com/app/api_hub_kirim_pesanan' => Http::response([], 500)]);
        $this->actingAs($this->operator)->postJson('/api/fgg/actions/send', $this->payload)->assertStatus(502);
        $op = DB::table('fgg_operations')->first();
        $this->assertSame('unknown', $op->state);
        Storage::disk('local')->assertExists($op->proof_path);
        $this->postJson('/api/fgg/actions/send', $this->payload)->assertStatus(409);
        Http::assertSentCount(1);
        $this->actingAs(User::factory()->create(['role' => 'hr']))->get(route('admin.network.activities.proof', $op->id))->assertNotFound();
    }
}
