<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Admin\IndonesiaTerritoryMasterService;
use App\Services\Admin\TerritoryCatalogService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Http\Request;

class TerritoryController extends Controller
{
    public function provinces(
        IndonesiaTerritoryMasterService $service,
        TerritoryCatalogService $fallbackCatalog,
    ): JsonResponse
    {
        return response()->json([
            'data' => $service->hasData()
                ? $service->provinces()->values()->all()
                : $this->remoteProvinces() ?? $this->fallbackProvinces($fallbackCatalog),
        ]);
    }

    public function cities(
        Request $request,
        IndonesiaTerritoryMasterService $service,
        TerritoryCatalogService $fallbackCatalog,
    ): JsonResponse {
        $provinceCode = $request->query('province_code');

        return response()->json([
            'data' => $service->hasData()
                ? $service->cities($provinceCode)->values()->all()
                : $this->remoteCities(is_scalar($provinceCode) ? (string) $provinceCode : null)
                    ?? $this->fallbackCities($fallbackCatalog, is_scalar($provinceCode) ? (string) $provinceCode : null),
        ]);
    }

    public function districts(
        Request $request,
        IndonesiaTerritoryMasterService $service,
        TerritoryCatalogService $fallbackCatalog,
    ): JsonResponse {
        $cityCode = $request->query('city_code');

        return response()->json([
            'data' => $service->hasData()
                ? $service->districts($cityCode)->values()->all()
                : $this->remoteDistricts(is_scalar($cityCode) ? (string) $cityCode : null)
                    ?? $this->fallbackDistricts($fallbackCatalog, is_scalar($cityCode) ? (string) $cityCode : null),
        ]);
    }

    public function subdistricts(
        Request $request,
        IndonesiaTerritoryMasterService $service,
        TerritoryCatalogService $fallbackCatalog,
    ): JsonResponse {
        $districtCode = $request->query('district_code');

        return response()->json([
            'data' => $service->hasData()
                ? $service->subdistricts($districtCode)->values()->all()
                : $this->remoteSubdistricts(is_scalar($districtCode) ? (string) $districtCode : null)
                    ?? $this->fallbackSubdistricts($fallbackCatalog, is_scalar($districtCode) ? (string) $districtCode : null),
        ]);
    }

    /**
     * @return array<int, array{code:string,name:string}>|null
     */
    private function remoteProvinces(): ?array
    {
        return $this->remoteData('provinces', 'https://wilayah.id/api/provinces.json');
    }

    /**
     * @return array<int, array{code:string,name:string,province_code?:string}>|null
     */
    private function remoteCities(?string $provinceCode): ?array
    {
        if ($provinceCode === null || $provinceCode === '') {
            return [];
        }

        return $this->remoteData(
            'regencies_' . $provinceCode,
            'https://wilayah.id/api/regencies/' . rawurlencode($provinceCode) . '.json',
            fn (array $row): array => [
                'code' => (string) ($row['code'] ?? ''),
                'name' => (string) ($row['name'] ?? ''),
                'province_code' => $provinceCode,
            ],
        );
    }

    /**
     * @return array<int, array{code:string,name:string,city_code?:string}>|null
     */
    private function remoteDistricts(?string $cityCode): ?array
    {
        if ($cityCode === null || $cityCode === '') {
            return [];
        }

        return $this->remoteData(
            'districts_' . $cityCode,
            'https://wilayah.id/api/districts/' . rawurlencode($cityCode) . '.json',
            fn (array $row): array => [
                'code' => (string) ($row['code'] ?? ''),
                'name' => (string) ($row['name'] ?? ''),
                'city_code' => $cityCode,
            ],
        );
    }

    /**
     * @return array<int, array{code:string,name:string,district_code?:string}>|null
     */
    private function remoteSubdistricts(?string $districtCode): ?array
    {
        if ($districtCode === null || $districtCode === '') {
            return [];
        }

        return $this->remoteData(
            'villages_' . $districtCode,
            'https://wilayah.id/api/villages/' . rawurlencode($districtCode) . '.json',
            fn (array $row): array => [
                'code' => (string) ($row['code'] ?? ''),
                'name' => (string) ($row['name'] ?? ''),
                'district_code' => $districtCode,
            ],
        );
    }

    /**
     * @return array<int, array<string, string>>|null
     */
    private function remoteData(string $cacheKey, string $url, ?callable $mapper = null): ?array
    {
        try {
            return Cache::remember(
                'territory_remote_' . sha1($cacheKey),
                now()->addDay(),
                function () use ($url, $mapper): ?array {
                    $response = Http::acceptJson()
                        ->connectTimeout(10)
                        ->timeout(30)
                        ->get($url);

                    if (! $response->successful()) {
                        return null;
                    }

                    $rows = $response->json('data');
                    if (! is_array($rows)) {
                        return null;
                    }

                    return $this->sortByName(
                        collect($rows)
                            ->filter(fn ($row): bool => is_array($row))
                            ->map(fn (array $row): array => $mapper
                                ? $mapper($row)
                                : [
                                    'code' => (string) ($row['code'] ?? ''),
                                    'name' => (string) ($row['name'] ?? ''),
                                ])
                            ->filter(fn (array $row): bool => ($row['code'] ?? '') !== '' && ($row['name'] ?? '') !== '')
                            ->values()
                            ->all(),
                    );
                },
            );
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * @return array<int, array{code:string,name:string}>
     */
    private function fallbackProvinces(TerritoryCatalogService $catalogService): array
    {
        $rows = [];

        foreach ($catalogService->build() as $provinceName => $provinceNode) {
            $rows[] = [
                'code' => $this->fallbackCode('province', $provinceName),
                'name' => $provinceName,
            ];
        }

        return $this->sortByName($rows);
    }

    /**
     * @return array<int, array{code:string,name:string,province_code:string,province_name:string}>
     */
    private function fallbackCities(TerritoryCatalogService $catalogService, ?string $provinceCode): array
    {
        $rows = [];

        foreach ($catalogService->build() as $provinceName => $provinceNode) {
            $effectiveProvinceCode = $this->fallbackCode('province', $provinceName);
            if ($provinceCode !== null && $provinceCode !== '' && $provinceCode !== $effectiveProvinceCode) {
                continue;
            }

            foreach (($provinceNode['cities'] ?? []) as $cityName => $cityNode) {
                $rows[] = [
                    'code' => $this->fallbackCode('city', $provinceName, $cityName),
                    'name' => $cityName,
                    'province_code' => $effectiveProvinceCode,
                    'province_name' => $provinceName,
                ];
            }
        }

        return $this->sortByName($rows);
    }

    /**
     * @return array<int, array{code:string,name:string,province_code:string,province_name:string,city_code:string,city_name:string}>
     */
    private function fallbackDistricts(TerritoryCatalogService $catalogService, ?string $cityCode): array
    {
        $rows = [];

        foreach ($catalogService->build() as $provinceName => $provinceNode) {
            $provinceCode = $this->fallbackCode('province', $provinceName);
            foreach (($provinceNode['cities'] ?? []) as $cityName => $cityNode) {
                $effectiveCityCode = $this->fallbackCode('city', $provinceName, $cityName);
                if ($cityCode !== null && $cityCode !== '' && $cityCode !== $effectiveCityCode) {
                    continue;
                }

                foreach (($cityNode['districts'] ?? []) as $districtName => $subdistricts) {
                    $rows[] = [
                        'code' => $this->fallbackCode('district', $provinceName, $cityName, $districtName),
                        'name' => $districtName,
                        'province_code' => $provinceCode,
                        'province_name' => $provinceName,
                        'city_code' => $effectiveCityCode,
                        'city_name' => $cityName,
                    ];
                }
            }
        }

        return $this->sortByName($rows);
    }

    /**
     * @return array<int, array{code:string,name:string,province_code:string,province_name:string,city_code:string,city_name:string,district_code:string,district_name:string}>
     */
    private function fallbackSubdistricts(TerritoryCatalogService $catalogService, ?string $districtCode): array
    {
        $rows = [];

        foreach ($catalogService->build() as $provinceName => $provinceNode) {
            $provinceCode = $this->fallbackCode('province', $provinceName);
            foreach (($provinceNode['cities'] ?? []) as $cityName => $cityNode) {
                $cityCode = $this->fallbackCode('city', $provinceName, $cityName);
                foreach (($cityNode['districts'] ?? []) as $districtName => $subdistricts) {
                    $effectiveDistrictCode = $this->fallbackCode('district', $provinceName, $cityName, $districtName);
                    if ($districtCode !== null && $districtCode !== '' && $districtCode !== $effectiveDistrictCode) {
                        continue;
                    }

                    foreach ($subdistricts as $subdistrictName) {
                        $rows[] = [
                            'code' => $this->fallbackCode('subdistrict', $provinceName, $cityName, $districtName, $subdistrictName),
                            'name' => $subdistrictName,
                            'province_code' => $provinceCode,
                            'province_name' => $provinceName,
                            'city_code' => $cityCode,
                            'city_name' => $cityName,
                            'district_code' => $effectiveDistrictCode,
                            'district_name' => $districtName,
                        ];
                    }
                }
            }
        }

        return $this->sortByName($rows);
    }

    private function fallbackCode(string $level, string ...$parts): string
    {
        return 'fallback_' . substr(sha1($level . '|' . implode('|', $parts)), 0, 16);
    }

    /**
     * @param array<int, array<string, string>> $rows
     * @return array<int, array<string, string>>
     */
    private function sortByName(array $rows): array
    {
        usort(
            $rows,
            fn (array $left, array $right): int => strnatcasecmp($left['name'] ?? '', $right['name'] ?? ''),
        );

        return $rows;
    }
}
