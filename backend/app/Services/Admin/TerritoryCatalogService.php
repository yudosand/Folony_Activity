<?php

namespace App\Services\Admin;

use App\Models\NetworkProfile;
use App\Models\User;

class TerritoryCatalogService
{
    public function __construct(
        private readonly IndonesiaTerritoryMasterService $masterService,
    ) {
    }

    public function build(): array
    {
        if ($this->masterService->hasData()) {
            return $this->masterService->catalog();
        }

        $catalog = [];

        foreach ($this->seedRows() as $row) {
            $this->append($catalog, $row);
        }

        User::query()
            ->select([
                'territory_province',
                'territory_city',
                'territory_district',
                'territory_subdistrict',
                'territory_assignments',
            ])
            ->where(function ($query): void {
                $query->whereNotNull('territory_province')
                    ->orWhereNotNull('territory_city')
                    ->orWhereNotNull('territory_district')
                    ->orWhereNotNull('territory_subdistrict')
                    ->orWhereNotNull('territory_assignments');
            })
            ->orderBy('territory_province')
            ->orderBy('territory_city')
            ->orderBy('territory_district')
            ->orderBy('territory_subdistrict')
            ->get()
            ->each(function (User $user) use (&$catalog): void {
                $this->append($catalog, [
                    'territory_province' => $user->territory_province,
                    'territory_city' => $user->territory_city,
                    'territory_district' => $user->territory_district,
                    'territory_subdistrict' => $user->territory_subdistrict,
                ]);

                foreach ($user->territory_assignments ?? [] as $assignment) {
                    if (is_array($assignment)) {
                        $this->append($catalog, $assignment);
                    }
                }
            });

        NetworkProfile::query()
            ->select([
                'territory_province',
                'territory_city',
                'territory_district',
                'territory_subdistrict',
            ])
            ->where(function ($query): void {
                $query->whereNotNull('territory_province')
                    ->orWhereNotNull('territory_city')
                    ->orWhereNotNull('territory_district')
                    ->orWhereNotNull('territory_subdistrict');
            })
            ->orderBy('territory_province')
            ->orderBy('territory_city')
            ->orderBy('territory_district')
            ->orderBy('territory_subdistrict')
            ->get()
            ->each(fn (NetworkProfile $profile) => $this->append($catalog, [
                'territory_province' => $profile->territory_province,
                'territory_city' => $profile->territory_city,
                'territory_district' => $profile->territory_district,
                'territory_subdistrict' => $profile->territory_subdistrict,
            ]));

        ksort($catalog, SORT_NATURAL | SORT_FLAG_CASE);
        foreach ($catalog as &$provinceNode) {
            ksort($provinceNode['cities'], SORT_NATURAL | SORT_FLAG_CASE);
            foreach ($provinceNode['cities'] as &$cityNode) {
                ksort($cityNode['districts'], SORT_NATURAL | SORT_FLAG_CASE);
                foreach ($cityNode['districts'] as &$subdistricts) {
                    natcasesort($subdistricts);
                    $subdistricts = array_values(array_unique($subdistricts));
                }
            }
        }

        return $catalog;
    }

    private function append(array &$catalog, array $row): void
    {
        $province = $this->clean($row['territory_province'] ?? null);
        $city = $this->clean($row['territory_city'] ?? null);
        $district = $this->clean($row['territory_district'] ?? null);
        $subdistrict = $this->clean($row['territory_subdistrict'] ?? null);

        if ($province === null) {
            return;
        }

        $provinceKey = $this->findExistingKey(array_keys($catalog), $province) ?? $province;
        $catalog[$provinceKey] ??= ['cities' => []];

        if ($city === null) {
            return;
        }

        $cityKey = $this->findExistingKey(array_keys($catalog[$provinceKey]['cities']), $city) ?? $city;
        $catalog[$provinceKey]['cities'][$cityKey] ??= ['districts' => []];

        if ($district === null) {
            return;
        }

        $districtKey = $this->findExistingKey(
            array_keys($catalog[$provinceKey]['cities'][$cityKey]['districts']),
            $district,
        ) ?? $district;
        $catalog[$provinceKey]['cities'][$cityKey]['districts'][$districtKey] ??= [];

        if ($subdistrict === null) {
            return;
        }

        $existingSubdistrict = $this->findExistingKey(
            $catalog[$provinceKey]['cities'][$cityKey]['districts'][$districtKey],
            $subdistrict,
        );
        $catalog[$provinceKey]['cities'][$cityKey]['districts'][$districtKey][] =
            $existingSubdistrict ?? $subdistrict;
    }

    private function clean(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalize(?string $value): ?string
    {
        $clean = $this->clean($value);

        return $clean === null
            ? null
            : mb_strtolower(preg_replace('/\s+/', ' ', $clean));
    }

    private function findExistingKey(array $values, string $candidate): ?string
    {
        $normalizedCandidate = $this->normalize($candidate);
        foreach ($values as $value) {
            if ($this->normalize((string) $value) === $normalizedCandidate) {
                return (string) $value;
            }
        }

        return null;
    }

    private function seedRows(): array
    {
        return [
            [
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Jakarta Barat',
                'territory_district' => 'Grogol Petamburan',
                'territory_subdistrict' => 'Grogol',
            ],
            [
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Jakarta Barat',
                'territory_district' => 'Grogol Petamburan',
                'territory_subdistrict' => 'Tanjung Duren Utara',
            ],
            [
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Jakarta Barat',
                'territory_district' => 'Grogol Petamburan',
                'territory_subdistrict' => 'Tanjung Duren Selatan',
            ],
            [
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Jakarta Selatan',
                'territory_district' => 'Pasar Minggu',
                'territory_subdistrict' => 'Pejaten Timur',
            ],
            [
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Jakarta Selatan',
                'territory_district' => 'Pasar Minggu',
                'territory_subdistrict' => 'Pejaten Barat',
            ],
            [
                'territory_province' => 'DKI Jakarta',
                'territory_city' => 'Jakarta Selatan',
                'territory_district' => 'Jagakarsa',
                'territory_subdistrict' => 'Jagakarsa',
            ],
        ];
    }
}
