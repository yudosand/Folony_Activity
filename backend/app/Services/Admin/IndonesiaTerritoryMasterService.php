<?php

namespace App\Services\Admin;

use App\Models\IndonesiaTerritory;
use Illuminate\Support\Collection;

class IndonesiaTerritoryMasterService
{
    public function hasData(): bool
    {
        return IndonesiaTerritory::query()->exists();
    }

    public function provinces(): Collection
    {
        return IndonesiaTerritory::query()
            ->where('level', IndonesiaTerritory::LEVEL_PROVINCE)
            ->orderBy('name')
            ->get(['code', 'name']);
    }

    public function cities(?string $provinceCode = null): Collection
    {
        return IndonesiaTerritory::query()
            ->where('level', IndonesiaTerritory::LEVEL_CITY)
            ->when($provinceCode, fn ($query) => $query->where('province_code', $provinceCode))
            ->orderBy('name')
            ->get(['code', 'name', 'province_code', 'province_name']);
    }

    public function districts(?string $cityCode = null): Collection
    {
        return IndonesiaTerritory::query()
            ->where('level', IndonesiaTerritory::LEVEL_DISTRICT)
            ->when($cityCode, fn ($query) => $query->where('city_code', $cityCode))
            ->orderBy('name')
            ->get(['code', 'name', 'province_code', 'province_name', 'city_code', 'city_name']);
    }

    public function subdistricts(?string $districtCode = null): Collection
    {
        return IndonesiaTerritory::query()
            ->where('level', IndonesiaTerritory::LEVEL_SUBDISTRICT)
            ->when($districtCode, fn ($query) => $query->where('district_code', $districtCode))
            ->orderBy('name')
            ->get([
                'code',
                'name',
                'province_code',
                'province_name',
                'city_code',
                'city_name',
                'district_code',
                'district_name',
            ]);
    }

    public function catalog(): array
    {
        $catalog = [];

        $subdistricts = IndonesiaTerritory::query()
            ->where('level', IndonesiaTerritory::LEVEL_SUBDISTRICT)
            ->orderBy('province_name')
            ->orderBy('city_name')
            ->orderBy('district_name')
            ->orderBy('name')
            ->get([
                'province_code',
                'province_name',
                'city_code',
                'city_name',
                'district_code',
                'district_name',
                'code',
                'name',
            ]);

        foreach ($subdistricts as $row) {
            if ($row->province_code === null || $row->city_code === null || $row->district_code === null) {
                continue;
            }

            $catalog[$row->province_code] ??= [
                'code' => $row->province_code,
                'name' => $row->province_name,
                'cities' => [],
            ];

            $catalog[$row->province_code]['cities'][$row->city_code] ??= [
                'code' => $row->city_code,
                'name' => $row->city_name,
                'districts' => [],
            ];

            $catalog[$row->province_code]['cities'][$row->city_code]['districts'][$row->district_code] ??= [
                'code' => $row->district_code,
                'name' => $row->district_name,
                'subdistricts' => [],
            ];

            $catalog[$row->province_code]['cities'][$row->city_code]['districts'][$row->district_code]['subdistricts'][] = [
                'code' => $row->code,
                'name' => $row->name,
            ];
        }

        return $catalog;
    }
}
