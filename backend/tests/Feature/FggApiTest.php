<?php

namespace Tests\Feature;

use App\Models\EmployeeActivity;
use App\Models\FggAccount;
use App\Models\User;
use App\Services\FieldActivityReport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FggApiTest extends TestCase
{
    use RefreshDatabase;

    private function gps(): array
    {
        return ['latitude' => -6.2, 'longitude' => 106.8, 'accuracy_meters' => 12, 'captured_at' => now()->toIso8601String()];
    }

    public function test_delivery_trip_persists_server_times_idempotently_and_reports_travel_duration(): void
    {
        $this->freezeTime();
        $user = User::factory()->create(['role' => 'fgg']);
        Sanctum::actingAs($user);
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        Http::fake(['https://dev.foodukm.com/app/api_hub_detail_pesanan*' => Http::response([
            'statusCode' => 1, 'result' => [['senders_address' => 'Jl. Tujuan 12', 'status' => 'orders_ready']]]),
            'https://dev.foodukm.com/app/api_hub_kirim_pesanan' => Http::response(['statusCode' => 1])]);
        $this->getJson('/api/fgg/trips/7297')->assertOk()->assertJsonPath('data', null);
        $this->postJson('/api/fgg/trips/7297', ['action' => 'arrive', ...$this->gps()])->assertStatus(409);
        $start = $this->postJson('/api/fgg/trips/7297', ['action' => 'start', ...$this->gps()])
            ->assertOk()->assertJsonPath('data.destination_address', 'Jl. Tujuan 12')->json('data.started_at');
        $png = base64_encode(file_get_contents(public_path('favicon.png')));
        $this->postJson('/api/fgg/actions/send', ['transaction_id' => 7297, 'buktiFoto' => $png, ...$this->gps()])->assertUnprocessable();
        Http::assertNotSent(fn ($r) => str_contains($r->url(), 'api_hub_kirim_pesanan'));
        $this->travel(10)->minutes();
        $this->postJson('/api/fgg/trips/7297', ['action' => 'start', ...$this->gps()])->assertOk()->assertJsonPath('data.started_at', $start);
        $this->getJson('/api/fgg/trips/7297')->assertOk()->assertJsonPath('data.started_at', $start);
        $arrive = $this->postJson('/api/fgg/trips/7297', ['action' => 'arrive', ...$this->gps()])
            ->assertOk()->assertJsonPath('data.duration_seconds', 600)->json('data.arrived_at');
        $this->travel(5)->minutes();
        $this->postJson('/api/fgg/trips/7297', ['action' => 'arrive', ...$this->gps()])->assertOk()->assertJsonPath('data.arrived_at', $arrive);
        $this->postJson('/api/fgg/actions/send', ['transaction_id' => 7297, 'buktiFoto' => $png, ...$this->gps()])->assertOk();
        $this->assertNotNull(DB::table('fgg_delivery_trips')->value('completed_at'));
        $events = app(FieldActivityReport::class)->events($user->id, now()->toDateString());
        $this->assertSame(600, $events->first()['duration_seconds']);
        $this->assertSame(600, app(FieldActivityReport::class)->day($events, now()->toDateString())['duration_seconds']);
        $this->assertDatabaseCount('fgg_delivery_trips', 1);
        Http::assertSent(fn ($r) => str_contains($r->url(), 'api_hub_kirim_pesanan') && ! isset($r['started_at']) && ! isset($r['destination_address']));
    }

    public function test_trip_rejects_missing_address_stale_gps_and_other_operators(): void
    {
        $user = User::factory()->create(['role' => 'fgg']);
        Sanctum::actingAs($user);
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        Http::fake(['*' => Http::response(['statusCode' => 1, 'result' => []])]);
        $this->postJson('/api/fgg/trips/123', ['action' => 'start', ...$this->gps()])->assertUnprocessable();
        $this->postJson('/api/fgg/trips/123', ['action' => 'start', ...$this->gps(), 'captured_at' => now()->subHour()->toIso8601String()])->assertUnprocessable();
        DB::table('fgg_delivery_trips')->insert(['environment' => 'staging', 'member_id' => '11', 'hub_id' => 'HUB12',
            'user_id' => 'other-user', 'target' => '123', 'destination_address' => 'Private destination', 'started_at' => now(),
            'start_location' => '{}', 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/fgg/trips/123')->assertStatus(409)->assertDontSee('Private destination');
        $this->postJson('/api/fgg/trips/123', ['action' => 'arrive', ...$this->gps()])->assertStatus(409);
    }

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        config(['fgg.environment' => 'staging']);
        Http::preventStrayRequests();
    }

    private function login(array $roles = [['id' => 'HUB12', 'name' => 'Hub test', 'userRole' => 'HUB']]): void
    {
        Http::fake(['https://dev.foodukm.com/app/api_login' => Http::response([
            'statusCode' => 1, 'result' => ['token' => 'upstream-test-token', 'idmember' => '11', 'name' => 'Operator', 'otherUser' => $roles],
        ])]);
        $this->postJson('/api/fgg/connect', ['fuserid' => 'operator', 'fpassword' => 'secret', 'idDevice' => 'test-device'])
            ->assertOk()->assertJsonPath('data.connected', true)->assertDontSee('upstream-test-token');
    }

    public function test_login_hub_selection_raw_auth_and_environment_isolation(): void
    {
        $this->getJson('/api/fgg/session')->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        $this->assertNotSame('upstream-test-token', DB::table('fgg_accounts')->value('token'));
        Http::assertSent(fn ($r) => $r->url() === 'https://dev.foodukm.com/app/api_login'
            && str_contains($r->header('Content-Type')[0], 'application/x-www-form-urlencoded') && $r['fpassword'] === 'secret');
        $this->getJson('/api/fgg/list/dst')->assertStatus(409);
        $this->postJson('/api/fgg/hub', ['hub_id' => 'OTHER'])->assertForbidden();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        Http::fake(['https://dev.foodukm.com/app/api_hub_list_dst*' => Http::response(['statusCode' => 1, 'result' => [['no_dst' => 152]], 'pagination' => 1, 'totalPage' => 2])]);
        $this->getJson('/api/fgg/list/dst?search=hello&pagination=1')->assertOk()->assertJsonPath('data.0.no_dst', 152)->assertJsonPath('total_pages', 2);
        Http::assertSent(fn ($r) => str_contains($r->url(), 'api_hub_list_dst') && $r->header('Authorization') === ['upstream-test-token'] && $r['search'] === 'hello');
        config(['fgg.environment' => 'production', 'app.env' => 'production', 'app.url' => 'https://absent.folony.co.id']);
        $this->getJson('/api/fgg/session')->assertOk()->assertJsonPath('data.connected', false);
        $this->getJson('/api/fgg/list/dst')->assertStatus(409);
    }

    public function test_cohub_and_multi_hub_cannot_get_shipping_access(): void
    {
        Sanctum::actingAs(User::factory()->create());
        Http::fake(['*' => Http::response(['statusCode' => 1, 'result' => ['token' => 'test', 'idmember' => 1,
            'otherUser' => [['id' => 'C1', 'userRole' => 'COHUB']]]])]);
        $this->postJson('/api/fgg/connect', ['fuserid' => 'operator', 'fpassword' => 'secret', 'idDevice' => 'device'])->assertForbidden();
        $this->assertDatabaseCount('fgg_accounts', 0);
    }

    public function test_multi_hub_selection_is_not_falsely_scoped(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login([['id' => 'H1', 'userRole' => 'HUB'], ['id' => 'H2', 'userRole' => 'HUB']]);
        $this->postJson('/api/fgg/hub', ['hub_id' => 'H2'])->assertStatus(409);
    }

    public function test_success_is_audited_once_and_does_not_end_current_work(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        EmployeeActivity::create(['request_id' => 'start', 'user_id' => $user->id, 'note' => 'Mulai', 'started_at' => now()->subHour(), 'is_finished' => false]);
        Http::fake(['https://dev.foodukm.com/app/api_hub_terima_dst' => Http::response(['statusCode' => 1])]);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertOk();
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertOk();
        $this->assertDatabaseCount('employee_activities', 1);
        $this->assertFalse(EmployeeActivity::latest('id')->first()->is_finished);
        $this->assertDatabaseHas('fgg_operations', ['target' => '152', 'state' => 'succeeded']);
        $this->assertDatabaseHas('fgg_operations', ['target' => '152', 'latitude' => -6.2, 'longitude' => 106.8, 'accuracy_meters' => 12]);
        $this->assertCount(1, Http::recorded(fn ($r) => str_contains($r->url(), 'api_hub_terima_dst')));
        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/fgg/session')->assertJsonPath('data.connected', false);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertStatus(409);
    }

    public function test_uncertain_transactions_are_not_replayed_and_invalid_photos_never_sent(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        $this->postJson('/api/fgg/actions/send', [...$this->gps(), 'transaction_id' => 1, 'buktiFoto' => base64_encode('not an image')])->assertUnprocessable();
        Http::fake(['https://dev.foodukm.com/app/api_hub_terima_dst' => Http::failedConnection()]);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertStatus(504);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertStatus(409);
        $this->assertDatabaseHas('fgg_operations', ['state' => 'unknown']);
        $this->assertDatabaseCount('employee_activities', 0);
    }

    public function test_expiry_disconnect_and_production_guard(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        FggAccount::first()->update(['token' => 'header.'.base64_encode(json_encode(['exp' => time() - 1])).'.sig']);
        $this->getJson('/api/fgg/session')->assertJsonPath('data.connected', false);
        $this->deleteJson('/api/fgg/session')->assertOk();
        $this->assertDatabaseCount('fgg_accounts', 0);
        config(['fgg.environment' => 'production', 'app.env' => 'staging']);
        $this->getJson('/api/fgg/session')->assertStatus(503);
    }

    public function test_delivery_uses_json_photo_and_production_host_when_configured(): void
    {
        Sanctum::actingAs(User::factory()->create());
        config(['fgg.environment' => 'production', 'app.env' => 'production', 'app.url' => 'https://absent.folony.co.id']);
        FggAccount::create(['user_id' => auth()->id(), 'environment' => 'production', 'member_id' => '11',
            'name' => 'Operator', 'token' => 'production-test-token', 'hubs' => [['id' => 'HUB12']], 'hub_id' => 'HUB12']);
        $photo = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4V8AAAAASUVORK5CYII=';
        Http::fake(['https://api.foodukm.com/app/api_hub_kirim_pesanan' => Http::response(['statusCode' => 1])]);
        $this->postJson('/api/fgg/actions/send', [...$this->gps(), 'transaction_id' => 123, 'buktiFoto' => $photo])->assertOk();
        Http::assertSent(fn ($r) => $r->url() === 'https://api.foodukm.com/app/api_hub_kirim_pesanan'
            && $r->header('Authorization') === ['production-test-token'] && $r['buktiFoto'] === $photo);
        $this->assertDatabaseCount('employee_activities', 0);
    }

    public function test_known_rejection_can_retry_without_recording_false_success(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        Http::fake(['https://dev.foodukm.com/app/api_hub_terima_dst' => Http::sequence()
            ->push(['statusCode' => 0])->push(['statusCode' => 1])]);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertUnprocessable();
        $this->assertDatabaseCount('employee_activities', 0);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertOk();
        $this->assertDatabaseCount('employee_activities', 0);
        $this->assertDatabaseHas('fgg_operations', ['target' => '152', 'state' => 'succeeded']);
    }

    public function test_fgg_auth_expiry_does_not_invalidate_folony_session(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        Http::fake(['https://dev.foodukm.com/app/api_hub_detail_pesanan*' => Http::response([], 401)]);
        $this->getJson('/api/fgg/detail/order/123')->assertStatus(409);
        $this->getJson('/api/fgg/session')->assertOk()->assertJsonPath('data.connected', false);
        $this->getJson('/api/employee-activities')->assertOk();
    }

    public function test_live_duplicate_response_is_explained_without_false_activity(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        Http::fake(['https://dev.foodukm.com/app/api_hub_terima_dst' => Http::response([
            'statusCode' => 2, 'message' => 'DST sudah pernah diterima HUB!', 'result' => [],
        ])]);
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152])->assertUnprocessable()
            ->assertJsonPath('message', 'DST sudah pernah diterima HUB. Muat ulang daftar kiriman.');
        $this->assertDatabaseCount('employee_activities', 0);
    }

    public function test_missing_stale_and_invalid_gps_prevent_upstream_transaction(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->login();
        $this->postJson('/api/fgg/hub', ['hub_id' => 'HUB12'])->assertOk();
        $this->postJson('/api/fgg/actions/receive', ['no_dst' => 152])->assertUnprocessable();
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152, 'latitude' => 91])->assertUnprocessable();
        $this->postJson('/api/fgg/actions/receive', [...$this->gps(), 'no_dst' => 152, 'captured_at' => now()->subHour()->toIso8601String()])->assertUnprocessable();
        $this->assertDatabaseCount('fgg_operations', 0);
        Http::assertNotSent(fn ($r) => str_contains($r->url(), 'api_hub_terima_dst'));
    }
}
