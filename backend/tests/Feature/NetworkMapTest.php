<?php

namespace Tests\Feature;

use App\Models\NetworkProfile;
use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NetworkMapTest extends TestCase
{
    use RefreshDatabase;

    public function test_hr_map_uses_filters_and_loads_all_pages_without_invalid_coordinates(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $template = NetworkProfile::firstOrFail()->getAttributes();
        $rows = [];
        for ($i = 0; $i < 1003; $i++) {
            $rows[] = array_merge($template, ['id' => sprintf('map_%04d', $i), 'name' => 'Map fixture '.$i,
                'latitude' => $i === 1002 ? null : -6.2, 'longitude' => 106.8,
                'type' => 'ukm', 'status' => 'draft', 'area_name' => 'Map Area']);
        }
        foreach (array_chunk($rows, 100) as $chunk) NetworkProfile::insert($chunk);
        $this->getJson('/admin/network/map-points')->assertRedirect('/admin/login');
        $staff = User::where('role', 'staff')->firstOrFail();
        $this->actingAs($staff)->getJson('/admin/network/map-points')->assertForbidden();
        $hr = User::where('email', 'hr@hex.local')->firstOrFail();
        $filter = '/admin/network/map-points?search=Map%20fixture&type=ukm&status=draft&area_name=Map%20Area';
        $response = $this->actingAs($hr)->getJson($filter)->assertOk()->assertJsonCount(1000, 'data')
            ->assertJsonPath('meta.mapped', 1002)->assertJsonPath('meta.unmapped', 1);
        $this->getJson($filter.'&after='.$response->json('meta.next_cursor'))->assertOk()
            ->assertJsonCount(2, 'data')->assertJsonPath('meta.next_cursor', null);
        $this->getJson('/admin/network/map-points?search=Map%20fixture&type=mitra')->assertOk()->assertJsonCount(0, 'data');
        $this->get('/admin/network?search=Map%20fixture')->assertOk()->assertSee('Peta Jaringan')
            ->assertSee('network-satellite-map.js')->assertSee('data-points-url');
    }
}
