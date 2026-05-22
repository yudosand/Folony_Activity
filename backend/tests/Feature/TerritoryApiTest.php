<?php

namespace Tests\Feature;

use App\Models\IndonesiaTerritory;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
}
