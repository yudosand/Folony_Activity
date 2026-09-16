<?php

namespace Tests\Feature;

use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Services\FieldActivityReport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FieldActivityDailyTest extends TestCase
{
    use RefreshDatabase;

    public function test_groups_by_identity_and_date_without_losing_records_after_500_and_paginates_days(): void
    {
        config(['fgg.environment' => 'staging']);
        $hr = User::factory()->create(['role' => 'hr']);
        $actors = User::factory()->count(2)->create(['role' => 'fgg', 'full_name' => 'Nama Sama']);
        $rows = [];
        for ($i = 0; $i < 502; $i++) {
            $rows[] = ['user_id' => $actors[0]->id, 'member_id' => '11', 'hub_id' => 'HUB12',
                'environment' => 'staging', 'action' => 'receive', 'target' => (string) $i, 'state' => 'succeeded',
                'created_at' => '2026-09-16 09:00:00', 'updated_at' => '2026-09-16 09:00:00'];
        }
        foreach (array_chunk($rows, 100) as $chunk) {
            DB::table('fgg_operations')->insert($chunk);
        }
        for ($i = 1; $i <= 31; $i++) {
            $row = $rows[0];
            $row['user_id'] = $actors[1]->id;
            $row['target'] = 'other-'.$i;
            $row['updated_at'] = sprintf('2026-08-%02d 09:00:00', $i);
            DB::table('fgg_operations')->insert($row);
        }
        $this->actingAs($hr)->get('/admin/network-activities')->assertOk()
            ->assertViewHas('days', fn ($days) => $days->total() === 32 && $days->count() === 30
                && $days->first()['count'] === 502 && $days->first()['duration_seconds'] === null);
        $this->get('/admin/network-activities?page=2')->assertOk()->assertViewHas('days', fn ($days) => $days->count() === 2);
        $url = route('admin.network.activities.show', ['employee' => $actors[0]->id, 'date' => '2026-09-16']);
        $this->get($url)->assertOk()->assertViewHas('events', fn ($events) => $events->count() === 502)
            ->assertSee('Koordinat tidak tersedia')->assertSee('Belum tercatat');
        $this->get(str_replace('2026-09-16', '2026-02-30', $url))->assertNotFound();
        $this->get(str_replace('2026-09-16', '2026-09-17', $url))->assertNotFound();
    }

    public function test_route_is_chronological_and_work_duration_merges_overlapping_visits(): void
    {
        $actor = User::factory()->create(['role' => 'fgg']);
        $profile = NetworkProfile::create(['id' => 'route-profile', 'owner_id' => $actor->id, 'owner_name' => $actor->full_name,
            'owner_role' => 'fgg', 'area_name' => 'Jakarta', 'type' => 'ukm', 'name' => 'Toko Rute', 'address' => 'Jalan Rute',
            'business_type' => 'Retail', 'phone_number' => '0812', 'status' => 'draft', 'latitude' => -6.2, 'longitude' => 106.8]);
        foreach ([['late', '10:15:00', '10:45:00'], ['early', '10:00:00', '10:30:00']] as [$id, $start, $end]) {
            NetworkFollowUp::create(['id' => $id, 'network_profile_id' => $profile->id, 'title' => $id, 'note' => 'Catatan',
                'actor_id' => $actor->id, 'actor_name' => $actor->full_name, 'created_at' => '2026-09-15 '.$end,
                'visit_started_at' => '2026-09-15 '.$start, 'visit_finished_at' => '2026-09-15 '.$end, 'visit_duration_seconds' => 1800]);
        }
        $report = app(FieldActivityReport::class);
        $events = $report->events($actor->id, '2026-09-15');
        $this->assertSame(['early', 'late'], $events->pluck('event_id')->all());
        $this->assertSame(2700, $report->day($events, '2026-09-15')['duration_seconds']);
        $this->assertSame('Lokasi profil', $events->first()['location_source']);
        $this->actingAs(User::factory()->create(['role' => 'hr']))
            ->get(route('admin.network.activities.show', ['employee' => $actor->id, 'date' => '2026-09-15']))
            ->assertOk()->assertSee('45m')->assertSee('15 Sep 2026 10:00:00')->assertSee('field-activity-route.js');
    }
}
