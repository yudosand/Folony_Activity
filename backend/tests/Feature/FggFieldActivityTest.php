<?php

namespace Tests\Feature;

use App\Models\EmployeeActivity;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FggFieldActivityTest extends TestCase
{
    use RefreshDatabase;

    public function test_field_timeline_reports_only_successful_operations_with_filters_and_hr_access(): void
    {
        config(['fgg.environment' => 'staging']);
        $actor = User::factory()->create(['role' => 'fgg', 'full_name' => 'Nadia Pengiriman']);
        $hr = User::factory()->create(['role' => 'hr']);
        foreach ([['receive', '152', 'succeeded', 'staging'], ['send', '7297', 'succeeded', 'staging'],
            ['send', 'UNKNOWN-99', 'unknown', 'staging'], ['send', 'PROD-99', 'succeeded', 'production']] as [$action, $target, $state, $env]) {
            DB::table('fgg_operations')->insert(['user_id' => $actor->id, 'member_id' => '11', 'hub_id' => 'HUB12',
                'environment' => $env, 'action' => $action, 'target' => $target, 'state' => $state,
                'latitude' => -6.2, 'longitude' => 106.8, 'accuracy_meters' => 8,
                'captured_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        }
        $this->actingAs($actor)->get('/admin/network-activities')->assertForbidden();
        $this->actingAs($hr)->get('/admin/network-activities')->assertOk()
            ->assertSee('Nadia Pengiriman')->assertSee('Terima DST')->assertSee('Kirim Pesanan')
            ->assertSee('HUB12')->assertDontSee('UNKNOWN-99')->assertDontSee('PROD-99')
            ->assertSee('GPS -6.200000, 106.800000')->assertViewHas('days', fn ($days) => $days->total() === 1)
            ->assertViewHas('summary', fn ($s) => $s['shipping'] === 2 && $s['total'] === 2);
        $this->get('/admin/network-activities?search=7297')->assertOk()->assertViewHas('days', fn ($days) => $days->first()['count'] === 2);
        $this->get('/admin/network-activities?owner_role=areaManager')->assertOk()->assertDontSee('Pesanan 7297');
        $this->get('/admin/network-activities?date_until=2000-01-01')->assertOk()->assertDontSee('Pesanan 7297');
        $detail = route('admin.network.activities.show', ['employee' => $actor->id, 'date' => now()->format('Y-m-d')]);
        $this->get($detail)->assertOk()->assertSee('Pesanan 7297')->assertSee('DST 152')
            ->assertSee('Buka di Google Maps')->assertSee('GPS perangkat')->assertDontSee('UNKNOWN-99')->assertDontSee('PROD-99');
        $this->actingAs($actor)->get($detail)->assertForbidden();
        $this->actingAs($hr);
        $this->get('/admin/employee-activities')->assertOk()->assertDontSee('Nadia Pengiriman');
    }

    public function test_migration_removes_only_generated_duplicates_preserving_operation_and_manual_work(): void
    {
        $actor = User::factory()->create();
        $id = DB::table('fgg_operations')->insertGetId(['user_id' => $actor->id, 'member_id' => '11', 'hub_id' => 'HUB12',
            'environment' => 'staging', 'action' => 'receive', 'target' => '152', 'state' => 'succeeded',
            'created_at' => now(), 'updated_at' => now()]);
        foreach (['fgg-'.$id => 'FGG HUB12 · Menerima DST 152', 'manual' => 'FGG HUB12 · Menerima DST 152'] as $request => $note) {
            EmployeeActivity::create(['user_id' => $actor->id, 'request_id' => $request, 'note' => $note,
                'started_at' => now(), 'is_finished' => false]);
        }
        $migration = require database_path('migrations/2026_09_16_000002_move_fgg_employee_activity_reports.php');
        $migration->up();
        $migration->up();
        $this->assertDatabaseCount('fgg_operations', 1);
        $this->assertDatabaseCount('employee_activities', 1);
        $this->assertDatabaseHas('employee_activities', ['request_id' => 'manual']);
    }
}
