<?php

namespace Tests\Feature;

use App\Models\Supplier;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SupplierTest extends TestCase
{
    use RefreshDatabase;

    private function payload(array $overrides = []): array
    {
        return array_replace([
            'name' => 'Supplier Tepung', 'phone_number' => '081234567890',
            'pic_name' => 'Bapak Supplier',
            'territory_province' => 'DKI JAKARTA', 'territory_city' => 'KOTA JAKARTA SELATAN',
            'territory_district' => 'TEBET', 'address' => 'Jalan Contoh 12',
            'location_source' => 'manual', 'items' => ['Tepung', 'Minyak'], 'notes' => 'Kirim setiap Senin',
        ], $overrides);
    }

    public function test_allowed_mobile_roles_can_create_and_pic_cannot_be_spoofed(): void
    {
        $other = User::factory()->create();
        foreach (['spv', 'management', 'areaManager'] as $role) {
            $user = User::factory()->create(['role' => $role]);
            $created = $this->actingAs($user, 'sanctum')->postJson('/api/suppliers', $this->payload([
                'created_by' => $other->id, 'creator' => ['full_name' => 'Forged'],
                'items' => ['  Tepung  ', 'Minyak'],
            ]))->assertCreated()->assertJsonPath('data.created_by', $user->id)
                ->assertJsonPath('data.items', ['Tepung', 'Minyak']);
            $this->assertDatabaseHas('suppliers', ['id' => $created->json('data.id'), 'created_by' => $user->id]);
        }
    }

    public function test_mobile_users_only_see_their_own_records_even_for_management(): void
    {
        $first = User::factory()->create(['role' => 'spv']);
        $second = User::factory()->create(['role' => 'management']);
        $id = $this->actingAs($first, 'sanctum')->postJson('/api/suppliers', $this->payload())->json('data.id');
        $this->getJson('/api/suppliers/'.$id)->assertOk();
        $this->actingAs($second, 'sanctum')->getJson('/api/suppliers?scope=all&created_by='.$first->id)
            ->assertOk()->assertJsonCount(0, 'data')->assertJsonPath('meta.total', 0);
        $this->getJson('/api/suppliers/'.$id)->assertNotFound();
        $this->postJson('/api/suppliers', $this->payload(['name' => 'Supplier Kedua']))->assertCreated();
        $this->getJson('/api/suppliers')->assertJsonCount(1, 'data')->assertJsonPath('data.0.name', 'Supplier Kedua');
    }

    public function test_disallowed_roles_guests_and_inactive_accounts_cannot_use_supplier_api(): void
    {
        $this->getJson('/api/suppliers')->assertUnauthorized();
        $this->postJson('/api/suppliers', $this->payload())->assertUnauthorized();
        foreach (['staff', 'fgg', 'hr'] as $role) {
            $this->actingAs(User::factory()->create(['role' => $role]), 'sanctum')->getJson('/api/suppliers')->assertForbidden();
            $this->postJson('/api/suppliers', $this->payload())->assertForbidden();
        }
        $this->actingAs(User::factory()->create(['role' => 'spv', 'is_active' => false]), 'sanctum')
            ->postJson('/api/suppliers', $this->payload())->assertForbidden();
        $this->assertDatabaseCount('suppliers', 0);
    }

    public function test_validation_rejects_invalid_items_regions_and_coordinates(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'areaManager']), 'sanctum');
        foreach ([['items' => []], ['items' => ['  ']], ['items' => ['Tepung', 'tepung']], ['items' => array_fill(0, 51, 'barang')],
            ['pic_name' => ''], ['territory_province' => ''], ['territory_city' => ''], ['territory_district' => ''], ['phone_number' => 'hello'],
            ['latitude' => -6.2], ['longitude' => 106.8], ['location_source' => 'gps'], ['location_source' => 'map'],
            ['latitude' => 91, 'longitude' => 106], ['latitude' => -6, 'longitude' => 181]] as $invalid) {
            $this->postJson('/api/suppliers', $this->payload($invalid))->assertUnprocessable();
        }
        $this->assertDatabaseCount('suppliers', 0);
        $this->postJson('/api/suppliers', $this->payload(['location_source' => 'gps', 'latitude' => -6.2, 'longitude' => 106.8]))
            ->assertCreated()->assertJsonPath('data.latitude', -6.2);
    }

    public function test_gps_and_map_can_save_without_manual_address_and_preserve_contact_pic(): void
    {
        $user = User::factory()->create(['role' => 'spv']);
        $this->actingAs($user, 'sanctum');
        foreach (['gps', 'map'] as $source) {
            $data = $this->payload(['location_source' => $source, 'latitude' => -6.2, 'longitude' => 106.8]);
            foreach (['territory_province', 'territory_city', 'territory_district', 'address'] as $field) unset($data[$field]);
            $result = $this->postJson('/api/suppliers', $data)->assertCreated()
                ->assertJsonPath('data.pic_name', 'Bapak Supplier')->assertJsonPath('data.created_by', $user->id);
            $this->assertDatabaseHas('suppliers', ['id' => $result->json('data.id'), 'territory_province' => null, 'address' => null]);
            $this->getJson('/api/suppliers/'.$result->json('data.id'))->assertOk();
        }
    }

    public function test_needs_search_filters_table_and_map_with_regions_and_literal_wildcards(): void
    {
        $owner = User::factory()->create(['role' => 'spv']);
        foreach ([['name' => 'Alpha', 'items' => ['Beras', 'Minyak Sawit'], 'latitude' => -6.2, 'longitude' => 106.8],
            ['name' => 'Bravo', 'items' => ['Minyak Kelapa']],
            ['name' => 'Charlie', 'items' => ['Minyak Jagung'], 'territory_province' => 'BALI', 'latitude' => -8, 'longitude' => 115],
            ['name' => 'Delta', 'items' => ['Tepung 100%']]] as $row) {
            $supplier = new Supplier($this->payload($row));
            $supplier->created_by = $owner->id;
            $supplier->save();
        }
        $this->actingAs(User::factory()->create(['role' => 'hr']));
        $filter = '?'.http_build_query(['needs' => 'MINYAK', 'province' => 'DKI JAKARTA']);
        $this->get('/admin/suppliers'.$filter)->assertOk()->assertSee('Alpha')->assertSee('Bravo')->assertDontSee('Charlie')->assertDontSee('Delta');
        $this->getJson('/admin/suppliers/map-points'.$filter)->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Alpha')->assertJsonPath('meta.total', 2)->assertJsonPath('meta.unmapped', 1);
        $this->get('/admin/suppliers?needs=100%25')->assertOk()->assertSee('Delta')->assertDontSee('Alpha');
        $this->getJson('/admin/suppliers/map-points?needs=unknown')->assertJsonCount(0, 'data');
        $this->getJson('/admin/suppliers/map-points?needs[]=invalid')->assertUnprocessable();
        // Legacy suppliers still display when the new PIC has not been entered.
        Supplier::where('name', 'Alpha')->update(['pic_name' => null]);
        $this->get('/admin/suppliers/'.Supplier::where('name', 'Alpha')->value('id'))->assertOk()->assertSee('Belum diisi');
    }

    public function test_hr_sees_all_creators_can_filter_and_create_with_hr_pic(): void
    {
        $spv = User::factory()->create(['role' => 'spv', 'full_name' => 'PIC Supervisor']);
        $id = $this->actingAs($spv, 'sanctum')->postJson('/api/suppliers', $this->payload())->json('data.id');
        $hr = User::factory()->create(['role' => 'hr', 'full_name' => 'PIC HR']);
        $this->actingAs($hr)->get('/admin/suppliers')->assertOk()->assertSee('PIC Supervisor')->assertSee('Supplier Tepung')->assertSee('Peta Supplier');
        $this->get('/admin/suppliers/create')->assertOk()->assertSee('Tambah barang')->assertSee('Gunakan lokasi saya');
        $this->get('/admin/suppliers/'.$id)->assertOk()->assertSee('Kirim setiap Senin')->assertSee('Minyak');
        $this->get('/admin/suppliers?province=BALI')->assertOk()->assertDontSee('Supplier Tepung');
        $this->post('/admin/suppliers', $this->payload(['created_by' => $spv->id, 'name' => 'Supplier HR', 'territory_province' => 'BALI']))->assertRedirect();
        $this->assertDatabaseHas('suppliers', ['name' => 'Supplier HR', 'created_by' => $hr->id]);
        $this->get('/admin/suppliers')->assertSee('Supplier HR')->assertSee('Supplier Tepung')->assertSee('PIC HR');
        $this->actingAs($spv)->get('/admin/suppliers')->assertForbidden();
        $this->get('/admin/suppliers/map-points')->assertForbidden();
        $this->post('/admin/suppliers', $this->payload())->assertForbidden();
    }

    public function test_cabai_filter_and_pagination_keep_table_and_map_consistent(): void
    {
        $owner = User::factory()->create(['role' => 'spv']);
        for ($i = 0; $i < 27; $i++) {
            Supplier::forceCreate(array_merge($this->payload([
                'name' => 'Cabai supplier '.$i, 'items' => ['Bawang Bombay', 'Cabai Merah'],
                'latitude' => -6.2, 'longitude' => 106.8,
            ]), ['created_by' => $owner->id]));
        }
        Supplier::forceCreate(array_merge($this->payload([
            'name' => 'Bawang saja', 'items' => ['Bawang Putih'],
            'latitude' => -6.2, 'longitude' => 106.8,
        ]), ['created_by' => $owner->id]));
        $this->actingAs(User::factory()->create(['role' => 'hr']));
        $page = $this->get('/admin/suppliers?needs=Cabai&province=DKI%20JAKARTA')->assertOk()
            ->assertSee('27 supplier')->assertDontSee('Bawang saja')
            ->assertSee('aria-label="Halaman daftar"', false)
            ->assertSee('needs=Cabai&amp;province=DKI%20JAKARTA&amp;page=2', false);
        $this->assertCount(25, $page->viewData('suppliers'));
        $last = $this->get('/admin/suppliers?needs=Cabai&province=DKI%20JAKARTA&page=2')
            ->assertOk()->assertDontSee('Bawang saja');
        $this->assertCount(2, $last->viewData('suppliers'));
        $this->getJson('/admin/suppliers/map-points?needs=Cabai&province=DKI%20JAKARTA')
            ->assertOk()->assertJsonCount(27, 'data')->assertJsonPath('meta.total', 27);
    }

    public function test_pagination_and_map_filters_cover_all_matching_points_and_count_unmapped(): void
    {
        $owner = User::factory()->create(['role' => 'spv']);
        $rows = [];
        for ($i = 0; $i < 1002; $i++) {
            $rows[] = array_merge($this->payload(), ['id' => (string) Str::uuid(), 'created_by' => $owner->id,
                'items' => json_encode(['Tepung']), 'latitude' => $i === 1001 ? null : -6.2,
                'longitude' => $i === 1001 ? null : 106.8, 'created_at' => now(), 'updated_at' => now()]);
        }
        foreach (array_chunk($rows, 50) as $chunk) Supplier::insert($chunk);
        $this->actingAs($owner, 'sanctum')->getJson('/api/suppliers')->assertJsonCount(20, 'data')->assertJsonPath('meta.total', 1002)->assertJsonPath('meta.has_more', true);
        $this->getJson('/api/suppliers?page=51')->assertJsonCount(2, 'data')->assertJsonPath('meta.has_more', false);
        $this->actingAs(User::factory()->create(['role' => 'hr']));
        $filter = '/admin/suppliers/map-points?province=DKI%20JAKARTA&district=TEBET';
        $result = $this->getJson($filter)->assertOk()->assertJsonCount(1000, 'data')->assertJsonPath('meta.unmapped', 1)->assertJsonPath('meta.mapped', 1001);
        $this->getJson($filter.'&after='.$result->json('meta.next_cursor'))->assertJsonCount(1, 'data')->assertJsonPath('meta.next_cursor', null);
        $this->getJson('/admin/suppliers/map-points?city=BOGOR')->assertJsonCount(0, 'data');
    }
}
