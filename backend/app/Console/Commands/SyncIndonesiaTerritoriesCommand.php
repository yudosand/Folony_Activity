<?php

namespace App\Console\Commands;

use App\Models\IndonesiaTerritory;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

class SyncIndonesiaTerritoriesCommand extends Command
{
    protected $signature = 'territory:sync-indonesia {--chunk=500 : Jumlah object id yang diambil per request}';

    protected $description = 'Sinkronkan master wilayah Indonesia dari Geoportal BPS.';

    private const BPS_DESA_QUERY_URL = 'https://geoportal.bps.go.id/server/rest/services/wilkerstat/desa/MapServer/0/query';

    public function handle(): int
    {
        $chunkSize = max(100, (int) $this->option('chunk'));

        $this->info('Mengambil daftar object id wilayah desa dari Geoportal BPS...');

        $objectIdsResponse = $this->bpsRequest([
            'where' => '1=1',
            'returnIdsOnly' => 'true',
            'f' => 'pjson',
        ]);

        if (! $objectIdsResponse->successful()) {
            $this->error('Gagal mengambil object id dari Geoportal BPS.');

            return self::FAILURE;
        }

        $objectIds = collect($objectIdsResponse->json('objectIds', []))
            ->filter(fn ($id) => is_numeric($id))
            ->map(fn ($id) => (int) $id)
            ->values();

        if ($objectIds->isEmpty()) {
            $this->error('Geoportal BPS tidak mengembalikan object id wilayah.');

            return self::FAILURE;
        }

        $provinces = [];
        $cities = [];
        $districts = [];
        $subdistricts = [];

        $bar = $this->output->createProgressBar((int) ceil($objectIds->count() / $chunkSize));
        $bar->start();

        foreach ($objectIds->chunk($chunkSize) as $chunk) {
            $response = $this->bpsRequest([
                'objectIds' => $chunk->implode(','),
                'outFields' => implode(',', [
                    'PROVNO',
                    'KABKOTNO',
                    'KECNO',
                    'DESANO',
                    'PROVINSI',
                    'KABKOT',
                    'KECAMATAN',
                    'DESA',
                    'IDDESA',
                ]),
                'returnGeometry' => 'false',
                'f' => 'pjson',
            ]);

            if (! $response->successful()) {
                $bar->finish();
                $this->newLine(2);
                $this->error('Gagal mengambil detail wilayah dari Geoportal BPS.');

                return self::FAILURE;
            }

            foreach ($response->json('features', []) as $feature) {
                $attributes = $feature['attributes'] ?? [];

                $provinceCode = $this->clean($attributes['PROVNO'] ?? null);
                $cityCodeSuffix = $this->clean($attributes['KABKOTNO'] ?? null);
                $districtCodeSuffix = $this->clean($attributes['KECNO'] ?? null);
                $subdistrictCodeSuffix = $this->clean($attributes['DESANO'] ?? null);
                $subdistrictCode = $this->clean($attributes['IDDESA'] ?? null);
                $provinceName = $this->clean($attributes['PROVINSI'] ?? null);
                $cityName = $this->clean($attributes['KABKOT'] ?? null);
                $districtName = $this->clean($attributes['KECAMATAN'] ?? null);
                $subdistrictName = $this->clean($attributes['DESA'] ?? null);

                if ($provinceCode === null || $provinceName === null) {
                    continue;
                }

                $cityCode = $provinceCode . ($cityCodeSuffix ?? '');
                $districtCode = $cityCode . ($districtCodeSuffix ?? '');
                $effectiveSubdistrictCode = $subdistrictCode ?? ($districtCode . ($subdistrictCodeSuffix ?? ''));

                $provinces[$provinceCode] = [
                    'code' => $provinceCode,
                    'level' => IndonesiaTerritory::LEVEL_PROVINCE,
                    'name' => $provinceName,
                    'normalized_name' => $this->normalize($provinceName),
                    'parent_code' => null,
                    'province_code' => $provinceCode,
                    'city_code' => null,
                    'district_code' => null,
                    'province_name' => $provinceName,
                    'city_name' => null,
                    'district_name' => null,
                ];

                if ($cityName !== null && $cityCodeSuffix !== null) {
                    $cities[$cityCode] = [
                        'code' => $cityCode,
                        'level' => IndonesiaTerritory::LEVEL_CITY,
                        'name' => $cityName,
                        'normalized_name' => $this->normalize($cityName),
                        'parent_code' => $provinceCode,
                        'province_code' => $provinceCode,
                        'city_code' => $cityCode,
                        'district_code' => null,
                        'province_name' => $provinceName,
                        'city_name' => $cityName,
                        'district_name' => null,
                    ];
                }

                if ($districtName !== null && $cityName !== null && $districtCodeSuffix !== null) {
                    $districts[$districtCode] = [
                        'code' => $districtCode,
                        'level' => IndonesiaTerritory::LEVEL_DISTRICT,
                        'name' => $districtName,
                        'normalized_name' => $this->normalize($districtName),
                        'parent_code' => $cityCode,
                        'province_code' => $provinceCode,
                        'city_code' => $cityCode,
                        'district_code' => $districtCode,
                        'province_name' => $provinceName,
                        'city_name' => $cityName,
                        'district_name' => $districtName,
                    ];
                }

                if ($subdistrictName !== null && $districtName !== null && $cityName !== null) {
                    $subdistricts[$effectiveSubdistrictCode] = [
                        'code' => $effectiveSubdistrictCode,
                        'level' => IndonesiaTerritory::LEVEL_SUBDISTRICT,
                        'name' => $subdistrictName,
                        'normalized_name' => $this->normalize($subdistrictName),
                        'parent_code' => $districtCode,
                        'province_code' => $provinceCode,
                        'city_code' => $cityCode,
                        'district_code' => $districtCode,
                        'province_name' => $provinceName,
                        'city_name' => $cityName,
                        'district_name' => $districtName,
                    ];
                }
            }

            $bar->advance();
        }

        $bar->finish();
        $this->newLine(2);
        $this->info('Menyimpan master wilayah ke database...');

        DB::transaction(function () use ($provinces, $cities, $districts, $subdistricts): void {
            $timestamp = Carbon::now();
            $rows = array_map(
                fn (array $row) => [
                    ...$row,
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ],
                array_values([
                    ...$provinces,
                    ...$cities,
                    ...$districts,
                    ...$subdistricts,
                ]),
            );

            IndonesiaTerritory::query()->delete();
            foreach (array_chunk($rows, 1000) as $chunkRows) {
                IndonesiaTerritory::query()->insert($chunkRows);
            }
        });

        $this->info(sprintf(
            'Selesai: %d provinsi, %d kota/kabupaten, %d kecamatan, %d kelurahan/desa.',
            count($provinces),
            count($cities),
            count($districts),
            count($subdistricts),
        ));

        return self::SUCCESS;
    }

    private function clean(mixed $value): ?string
    {
        if (! is_scalar($value)) {
            return null;
        }

        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalize(string $value): string
    {
        return mb_strtolower(preg_replace('/\s+/', ' ', trim($value)));
    }

    private function bpsRequest(array $query): Response
    {
        return Http::acceptJson()
            ->withHeaders([
                'User-Agent' => 'FolonyActivity/1.0 TerritorySync',
            ])
            ->connectTimeout(30)
            ->timeout(180)
            ->retry(3, 2000)
            ->get(self::BPS_DESA_QUERY_URL, $query);
    }
}
