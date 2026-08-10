<?php

namespace Tests\Feature;

use App\Models\IndonesiaTerritory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class TerritoryApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_territory_endpoints_return_master_data(): void
    {
        IndonesiaTerritory::query()->create([
            'code' => '31',
            'level' => IndonesiaTerritory::LEVEL_PROVINCE,
            'name' => 'DKI Jakarta',
            'normalized_name' => 'dki jakarta',
            'province_code' => '31',
            'province_name' => 'DKI Jakarta',
        ]);

        IndonesiaTerritory::query()->create([
            'code' => '3174',
            'level' => IndonesiaTerritory::LEVEL_CITY,
            'name' => 'Jakarta Barat',
            'normalized_name' => 'jakarta barat',
            'parent_code' => '31',
            'province_code' => '31',
            'city_code' => '3174',
            'province_name' => 'DKI Jakarta',
            'city_name' => 'Jakarta Barat',
        ]);

        IndonesiaTerritory::query()->create([
            'code' => '3174010',
            'level' => IndonesiaTerritory::LEVEL_DISTRICT,
            'name' => 'Grogol Petamburan',
            'normalized_name' => 'grogol petamburan',
            'parent_code' => '3174',
            'province_code' => '31',
            'city_code' => '3174',
            'district_code' => '3174010',
            'province_name' => 'DKI Jakarta',
            'city_name' => 'Jakarta Barat',
            'district_name' => 'Grogol Petamburan',
        ]);

        IndonesiaTerritory::query()->create([
            'code' => '3174010001',
            'level' => IndonesiaTerritory::LEVEL_SUBDISTRICT,
            'name' => 'Grogol',
            'normalized_name' => 'grogol',
            'parent_code' => '3174010',
            'province_code' => '31',
            'city_code' => '3174',
            'district_code' => '3174010',
            'province_name' => 'DKI Jakarta',
            'city_name' => 'Jakarta Barat',
            'district_name' => 'Grogol Petamburan',
        ]);

        $this->getJson('/api/territories/provinces')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '31',
                'name' => 'DKI Jakarta',
            ]);

        $this->getJson('/api/territories/cities?province_code=31')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '3174',
                'name' => 'Jakarta Barat',
            ]);

        $this->getJson('/api/territories/districts?city_code=3174')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '3174010',
                'name' => 'Grogol Petamburan',
            ]);

        $this->getJson('/api/territories/subdistricts?district_code=3174010')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '3174010001',
                'name' => 'Grogol',
            ]);
    }

    public function test_public_territory_endpoints_return_fallback_catalog_when_master_is_empty(): void
    {
        Cache::flush();
        Http::fake([
            'wilayah.id/*' => Http::response(['data' => []], 500),
        ]);

        $province = $this->getJson('/api/territories/provinces')
            ->assertOk()
            ->assertJsonFragment([
                'name' => 'DKI Jakarta',
            ])
            ->json('data.0');

        $this->assertIsArray($province);

        $city = $this->getJson('/api/territories/cities?province_code=' . urlencode($province['code']))
            ->assertOk()
            ->assertJsonFragment([
                'name' => 'Jakarta Selatan',
            ])
            ->json('data.0');

        $this->assertIsArray($city);

        $district = $this->getJson('/api/territories/districts?city_code=' . urlencode($city['code']))
            ->assertOk()
            ->json('data.0');

        $this->assertIsArray($district);

        $this->getJson('/api/territories/subdistricts?district_code=' . urlencode($district['code']))
            ->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['code', 'name', 'province_code', 'province_name', 'city_code', 'city_name', 'district_code', 'district_name'],
                ],
            ]);
    }

    public function test_public_territory_endpoints_use_remote_wilayah_id_when_master_is_empty(): void
    {
        Cache::flush();
        Http::fake([
            'https://wilayah.id/api/provinces.json' => Http::response([
                'data' => [
                    ['code' => '73', 'name' => 'Sulawesi Selatan'],
                ],
            ]),
            'https://wilayah.id/api/regencies/73.json' => Http::response([
                'data' => [
                    ['code' => '73.71', 'name' => 'Kota Makassar'],
                ],
            ]),
            'https://wilayah.id/api/districts/73.71.json' => Http::response([
                'data' => [
                    ['code' => '73.71.01', 'name' => 'Mariso'],
                ],
            ]),
            'https://wilayah.id/api/villages/73.71.01.json' => Http::response([
                'data' => [
                    ['code' => '73.71.01.1001', 'name' => 'Bontorannu'],
                ],
            ]),
        ]);

        $this->getJson('/api/territories/provinces')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '73',
                'name' => 'Sulawesi Selatan',
            ]);

        $this->getJson('/api/territories/cities?province_code=73')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '73.71',
                'name' => 'Kota Makassar',
            ]);

        $this->getJson('/api/territories/districts?city_code=73.71')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '73.71.01',
                'name' => 'Mariso',
            ]);

        $this->getJson('/api/territories/subdistricts?district_code=73.71.01')
            ->assertOk()
            ->assertJsonFragment([
                'code' => '73.71.01.1001',
                'name' => 'Bontorannu',
            ]);
    }
}
