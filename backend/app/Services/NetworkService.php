<?php

namespace App\Services;

use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Support\Territory\TerritoryData;
use App\Support\Territory\TerritoryScope;
use App\Support\Workflow\UserRole;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class NetworkService
{
    public function create(array $payload, User $owner): NetworkProfile
    {
        $territory = TerritoryData::payloadTerritory($payload);

        $profileId = Arr::get($payload, 'id', (string) Str::uuid());
        $existing = NetworkProfile::query()
            ->where('id', $profileId)
            ->first();

        if ($existing) {
            return $this->update($existing, $payload, $owner);
        }

        $profile = NetworkProfile::query()->create([
            'id' => $profileId,
            'owner_id' => $owner->id,
            'owner_name' => $owner->full_name,
            'owner_role' => $owner->role,
            'area_name' => TerritoryData::displayLabel($territory),
            'territory_province' => $territory['territory_province'],
            'territory_city' => $territory['territory_city'],
            'territory_district' => $territory['territory_district'],
            'territory_subdistrict' => $territory['territory_subdistrict'],
            'type' => $payload['type'],
            'name' => $payload['name'],
            'address' => $payload['address'],
            'business_type' => $payload['business_type'],
            'phone_number' => $payload['phone_number'],
            'status' => $payload['status'],
            'reference_name' => Arr::get($payload, 'reference_name'),
            'note' => Arr::get($payload, 'note'),
            'photo_attachment' => Arr::get($payload, 'photo'),
            'personality_metrics' => Arr::get($payload, 'personality_metrics', []),
            'documents' => Arr::get($payload, 'documents', []),
            'latitude' => Arr::get($payload, 'latitude'),
            'longitude' => Arr::get($payload, 'longitude'),
        ]);

        return $this->refresh($profile);
    }

    public function update(NetworkProfile $profile, array $payload, User $actor): NetworkProfile
    {
        $this->assertEditable($profile, $actor);
        $territory = TerritoryData::payloadTerritory($payload + TerritoryData::profileTerritory($profile));
        if ($profile->owner_id !== $actor->id) {
            $this->assertWithinTerritory($actor, $territory, $payload['type'] ?? $profile->type);
        }

        $profile->update([
            'owner_id' => $actor->id,
            'owner_name' => $actor->full_name,
            'owner_role' => $actor->role,
            'area_name' => TerritoryData::displayLabel($territory),
            'type' => $payload['type'] ?? $profile->type,
            'name' => $payload['name'] ?? $profile->name,
            'address' => $payload['address'] ?? $profile->address,
            'territory_province' => $territory['territory_province'],
            'territory_city' => $territory['territory_city'],
            'territory_district' => $territory['territory_district'],
            'territory_subdistrict' => $territory['territory_subdistrict'],
            'business_type' => $payload['business_type'] ?? $profile->business_type,
            'phone_number' => $payload['phone_number'] ?? $profile->phone_number,
            'status' => $payload['status'] ?? $profile->status,
            'reference_name' => Arr::exists($payload, 'reference_name')
                ? Arr::get($payload, 'reference_name')
                : $profile->reference_name,
            'note' => Arr::exists($payload, 'note')
                ? Arr::get($payload, 'note')
                : $profile->note,
            'photo_attachment' => Arr::exists($payload, 'photo')
                ? Arr::get($payload, 'photo')
                : $profile->photo_attachment,
            'personality_metrics' => Arr::get($payload, 'personality_metrics', $profile->personality_metrics ?? []),
            'documents' => Arr::get($payload, 'documents', $profile->documents ?? []),
            'latitude' => Arr::exists($payload, 'latitude')
                ? Arr::get($payload, 'latitude')
                : $profile->latitude,
            'longitude' => Arr::exists($payload, 'longitude')
                ? Arr::get($payload, 'longitude')
                : $profile->longitude,
        ]);

        return $this->refresh($profile);
    }

    public function delete(NetworkProfile $profile, User $actor): void
    {
        $this->assertEditable($profile, $actor);
        $profile->delete();
    }

    public function appendFollowUp(
        NetworkProfile $profile,
        array $payload,
        User $actor,
    ): NetworkProfile {
        $this->assertViewable($profile, $actor);

        $followUpId = Arr::get($payload, 'id', (string) Str::uuid());
        $existingFollowUp = NetworkFollowUp::query()
            ->where('id', $followUpId)
            ->first();

        if ($existingFollowUp !== null) {
            if ($existingFollowUp->network_profile_id !== $profile->id) {
                throw ValidationException::withMessages([
                    'id' => 'ID follow-up sudah dipakai pada data jaringan lain.',
                ]);
            }

            if (Arr::has($payload, 'next_status')) {
                $profile->update([
                    'status' => Arr::get($payload, 'next_status'),
                ]);
            }

            return $this->refresh($profile);
        }

        NetworkFollowUp::query()->create([
            'id' => $followUpId,
            'network_profile_id' => $profile->id,
            'title' => $payload['title'],
            'note' => $payload['note'],
            'visit_started_at' => Arr::get($payload, 'visit_started_at'),
            'visit_finished_at' => Arr::get($payload, 'visit_finished_at'),
            'visit_duration_seconds' => Arr::get($payload, 'visit_duration_seconds'),
            'photo_attachment' => Arr::get($payload, 'photo'),
            'actor_id' => $actor->id,
            'actor_name' => $actor->full_name,
            'created_at' => Arr::get($payload, 'created_at', now()),
        ]);

        if (Arr::has($payload, 'next_status')) {
            $profile->update([
                'status' => Arr::get($payload, 'next_status'),
            ]);
        }

        return $this->refresh($profile);
    }

    public function queryOwned(User $owner, ?string $type = null, ?string $search = null, ?string $scope = null)
    {
        $scope = in_array($scope, ['mine', 'area', 'all'], true) ? $scope : 'all';
        $query = NetworkProfile::query();

        if ($type !== null && $type !== '') {
            $query->where('type', $type);
        }

        if ($scope === 'mine') {
            $query->where('owner_id', $owner->id);
        } elseif ($owner->role === UserRole::FGG && TerritoryData::isAssigned($owner)) {
            $query->where(function ($builder) use ($owner, $scope): void {
                if ($scope === 'area') {
                    $builder->where('owner_id', '!=', $owner->id)
                        ->where(function ($territory) use ($owner): void {
                            $this->applyTerritoryScope($territory, $owner);
                        });
                    return;
                }

                $builder->where('owner_id', $owner->id)
                    ->orWhere(function ($territory) use ($owner): void {
                        $this->applyTerritoryScope($territory, $owner);
                    });
            });
        } elseif ($owner->role === UserRole::AREA_MANAGER && TerritoryData::isAssigned($owner)) {
            $query->where(function ($builder) use ($owner, $scope): void {
                if ($scope === 'area') {
                    $builder->where('owner_id', '!=', $owner->id)
                        ->where(function ($territory) use ($owner): void {
                            $this->applyTerritoryScope($territory, $owner);
                        });
                    return;
                }

                $builder->where('owner_id', $owner->id)
                    ->orWhere(function ($territory) use ($owner): void {
                        $this->applyTerritoryScope($territory, $owner);
                    });
            });
        } elseif ($owner->role === UserRole::MANAGEMENT && TerritoryData::isAssigned($owner)) {
            $query->where(function ($builder) use ($owner, $scope): void {
                if ($scope === 'area') {
                    $builder->where('owner_id', '!=', $owner->id)
                        ->where(function ($territory) use ($owner): void {
                            $this->applyTerritoryScope($territory, $owner);
                        });
                    return;
                }

                $builder->where('owner_id', $owner->id)
                    ->orWhere(function ($territory) use ($owner): void {
                        $this->applyTerritoryScope($territory, $owner);
                    });
            });
        } else {
            if ($scope === 'area') {
                $query->whereRaw('1 = 0');
            } else {
                $query->where('owner_id', $owner->id);
            }
        }

        if ($search !== null && $search !== '') {
            $query->where(function ($builder) use ($search): void {
                $builder
                    ->where('name', 'like', '%' . $search . '%')
                    ->orWhere('address', 'like', '%' . $search . '%');
            });
        }

        return $query->orderByDesc('created_at');
    }

    public function queryTeamUkm(User $areaManager, ?string $search = null)
    {
        $query = NetworkProfile::query()
            ->where('type', 'ukm')
            ->where('owner_role', UserRole::FGG)
            ->orderByDesc('created_at');

        if (TerritoryData::isAssigned($areaManager)) {
            $this->applyTerritoryScope($query, $areaManager);
        } else {
            $query->where('area_name', $areaManager->area_name);
        }

        if ($search !== null && $search !== '') {
            $query->where(function ($builder) use ($search): void {
                $builder
                    ->where('name', 'like', '%' . $search . '%')
                    ->orWhere('address', 'like', '%' . $search . '%');
            });
        }

        return $query;
    }

    public function applyTerritoryScopeToQuery($query, User $actor): void
    {
        $this->applyTerritoryScope($query, $actor);
    }

    public function scopeForHeatMap(User $actor)
    {
        return NetworkProfile::query();
    }

    private function refresh(NetworkProfile $profile): NetworkProfile
    {
        return NetworkProfile::query()
            ->with('followUps')
            ->findOrFail($profile->id);
    }

    private function assertEditable(NetworkProfile $profile, User $actor): void
    {
        if ($profile->owner_id === $actor->id) {
            return;
        }

        if (($actor->role === UserRole::FGG || $actor->role === UserRole::AREA_MANAGER)
            && TerritoryData::isAssigned($actor)
            && TerritoryData::coversProfile($actor, $profile)) {
            return;
        }

        abort(403, 'Data jaringan ini bukan milik area kerja user aktif.');
    }

    private function assertViewable(NetworkProfile $profile, User $actor): void
    {
        if ($profile->owner_id === $actor->id) {
            return;
        }

        $isAreaScope = ($actor->role === UserRole::FGG || $actor->role === UserRole::AREA_MANAGER || $actor->role === UserRole::MANAGEMENT)
            && TerritoryData::isAssigned($actor)
            && TerritoryData::coversProfile($actor, $profile);

        if ($isAreaScope) {
            return;
        }

        $canVisitHeatMapPoint = in_array($actor->role, [UserRole::FGG, UserRole::AREA_MANAGER, UserRole::MANAGEMENT], true)
            && $profile->latitude !== null
            && $profile->longitude !== null;

        if ($canVisitHeatMapPoint) {
            return;
        }

        abort(403, 'Data jaringan ini tidak bisa diakses user aktif.');
    }

    private function applyTerritoryScope($query, User $actor): void
    {
        $assignments = TerritoryData::userAssignments($actor);
        $includes = $this->mostSpecificIncludeAssignments(TerritoryData::includeAssignments($assignments));
        $excludes = TerritoryData::excludeAssignments($assignments);

        if ($includes === []) {
            $query->whereRaw('1 = 0');
            return;
        }

        if (collect($excludes)->contains(fn (array $assignment) => ($assignment['territory_scope'] ?? null) === TerritoryScope::ALL_AREAS)) {
            $query->whereRaw('1 = 0');
            return;
        }

        $query->where(function ($builder) use ($includes): void {
            foreach ($includes as $assignment) {
                $this->applyAssignmentClause($builder, $assignment, 'orWhere');
            }
        });

        if ($excludes !== []) {
            $query->where(function ($builder) use ($excludes): void {
                foreach ($excludes as $assignment) {
                    $this->applyAssignmentClause($builder, $assignment, 'whereNot');
                }
            });
        }
    }

    private function applyAssignmentClause($builder, array $assignment, string $method = 'orWhere'): void
    {
        $scopeField = TerritoryData::scopedField($assignment['territory_scope'] ?? null);
        $legacyLabel = $scopeField === null ? null : ($assignment[$scopeField] ?? null);

        if (($assignment['territory_scope'] ?? null) === TerritoryScope::ALL_AREAS) {
            $builder->{$method === 'whereNot' ? 'whereRaw' : 'orWhereRaw'}('1 = 1');
            return;
        }

        $builder->{$method}(function ($group) use ($assignment, $scopeField, $legacyLabel): void {
            $group->where(function ($structured) use ($assignment): void {
                $this->whereStructuredTerritoryMatchesAssignment($structured, $assignment);
            });

            if ($scopeField !== null && filled($legacyLabel)) {
                $group->orWhere(function ($legacy) use ($assignment): void {
                    $this->whereLegacyTerritoryTextMatchesAssignment($legacy, $assignment);
                });
            }
        });
    }

    private function whereStructuredTerritoryMatchesAssignment($query, array $assignment): void
    {
        $hasStructuredConstraint = false;
        foreach (TerritoryData::PROFILE_FIELDS as $field) {
            if (filled($assignment[$field] ?? null)) {
                $hasStructuredConstraint = true;
                break;
            }
        }

        if (! $hasStructuredConstraint) {
            $query->whereRaw('1 = 0');
            return;
        }

        if (filled($assignment['territory_province'])) {
            $query->where(function ($column) use ($assignment): void {
                $this->whereColumnMatchesAny($column, 'territory_province', $assignment['territory_province']);
            });
        }
        if (filled($assignment['territory_city'])) {
            $query->where(function ($column) use ($assignment): void {
                $this->whereColumnMatchesAny($column, 'territory_city', $assignment['territory_city']);
            });
        }
        if (filled($assignment['territory_district'])) {
            $query->where(function ($column) use ($assignment): void {
                $this->whereColumnMatchesAny($column, 'territory_district', $assignment['territory_district']);
            });
        }
        if (filled($assignment['territory_subdistrict'])) {
            $query->where(function ($column) use ($assignment): void {
                $this->whereColumnMatchesAny($column, 'territory_subdistrict', $assignment['territory_subdistrict']);
            });
        }
    }

    private function whereLegacyTerritoryTextMatchesAssignment($query, array $assignment): void
    {
        $query->where(function ($source) use ($assignment): void {
            $source->where(function ($text) use ($assignment): void {
                $this->whereStructuredTerritoryIsCompatibleOrBlank($text, $assignment);
                $this->whereLegacyTextColumnsHaveValue($text);

                $text->where(function ($matches) use ($assignment): void {
                    foreach ($this->assignmentSearchLabels($assignment) as $label) {
                        foreach ($this->labelVariants($label) as $variant) {
                            $matches
                                ->orWhere('address', 'like', '%' . $variant . '%')
                                ->orWhere('note', 'like', '%' . $variant . '%');
                        }
                    }
                });
            });

            $source->orWhere(function ($areaFallback) use ($assignment): void {
                $this->whereLegacyTextDoesNotConflictWithAssignment($areaFallback, $assignment);
                $this->whereStructuredCityDoesNotConflictWithAssignment($areaFallback, $assignment);
                $this->whereLegacyAreaNameMatchesAssignment($areaFallback, $assignment);
            });
        });
    }

    private function whereStructuredCityDoesNotConflictWithAssignment($query, array $assignment): void
    {
        $conflictingLabels = $this->conflictingJakartaCityLabels($assignment);
        if ($conflictingLabels === []) {
            return;
        }

        $query->where(function ($safe) use ($conflictingLabels): void {
            foreach (['territory_city'] as $field) {
                $safe->where(function ($column) use ($field, $conflictingLabels): void {
                    $column
                        ->whereNull($field)
                        ->orWhere($field, '')
                        ->orWhere($field, '-')
                        ->orWhere(function ($text) use ($field, $conflictingLabels): void {
                            foreach ($conflictingLabels as $label) {
                                foreach ($this->labelVariants($label) as $variant) {
                                    $text->where($field, 'not like', '%' . $variant . '%');
                                }
                            }
                        });
                });
            }
        });
    }

    private function whereLegacyAreaNameMatchesAssignment($query, array $assignment): void
    {
        $query->where(function ($area) use ($assignment): void {
            foreach ($this->assignmentSearchLabels($assignment) as $label) {
                foreach ($this->labelVariants($label) as $variant) {
                    $area->orWhere('area_name', 'like', '%' . $variant . '%');
                }
            }
        });
    }

    private function whereStructuredTerritoryIsCompatibleOrBlank($query, array $assignment): void
    {
        $compatibleLabels = $this->assignmentCompatibleLabels($assignment);

        $query->where(function ($compatible) use ($assignment, $compatibleLabels): void {
            foreach (TerritoryData::PROFILE_FIELDS as $field) {
                if (! filled($assignment[$field] ?? null)) {
                    continue;
                }

                $compatible->where(function ($column) use ($field, $assignment, $compatibleLabels): void {
                    $column
                        ->whereNull($field)
                        ->orWhere($field, '')
                        ->orWhere($field, '-')
                        ->orWhere(function ($matches) use ($field, $assignment): void {
                            $this->whereColumnMatchesAny($matches, $field, (string) $assignment[$field]);
                        })
                        ->orWhere(function ($matches) use ($field, $compatibleLabels): void {
                            foreach ($compatibleLabels as $index => $label) {
                                foreach ($this->labelVariants($label) as $variantIndex => $variant) {
                                    $method = $index === 0 && $variantIndex === 0 ? 'where' : 'orWhere';
                                    $matches->{$method}($field, $variant);
                                }
                            }
                        });
                });
            }
        });
    }

    private function whereLegacyTextColumnsHaveValue($query): void
    {
        $query->where(function ($text): void {
            foreach (['address', 'note'] as $field) {
                $text->orWhere(function ($column) use ($field): void {
                    $column
                        ->whereNotNull($field)
                        ->where($field, '!=', '')
                        ->where($field, '!=', '-');
                });
            }
        });
    }

    private function whereLegacyTextColumnsAreBlank($query): void
    {
        $query->where(function ($blank): void {
            foreach (['address', 'note'] as $field) {
                $blank->where(function ($column) use ($field): void {
                    $column
                        ->whereNull($field)
                        ->orWhere($field, '')
                        ->orWhere($field, '-');
                });
            }
        });
    }

    private function whereLegacyTextDoesNotConflictWithAssignment($query, array $assignment): void
    {
        $conflictingLabels = $this->conflictingJakartaCityLabels($assignment);
        if ($conflictingLabels === []) {
            return;
        }

        $query->where(function ($safe) use ($conflictingLabels): void {
            foreach (['address', 'note'] as $field) {
                $safe->where(function ($column) use ($field, $conflictingLabels): void {
                    $column
                        ->whereNull($field)
                        ->orWhere($field, '')
                        ->orWhere($field, '-')
                        ->orWhere(function ($text) use ($field, $conflictingLabels): void {
                            foreach ($conflictingLabels as $label) {
                                foreach ($this->labelVariants($label) as $variant) {
                                    $text->where($field, 'not like', '%' . $variant . '%');
                                }
                            }
                        });
                });
            }
        });
    }

    /**
     * Data import lama kadang punya area_name stale, sementara address/note
     * masih membuktikan kota Jakarta sebenarnya. Ini mencegah Jakarta Barat
     * bocor ke user Jakarta Selatan, tapi tetap mengizinkan alamat generik
     * seperti "Jl. Kyai Tapa" memakai fallback area_name.
     *
     * @return list<string>
     */
    private function conflictingJakartaCityLabels(array $assignment): array
    {
        $currentCity = $assignment['territory_city'] ?? null;
        if (! is_string($currentCity) || trim($currentCity) === '') {
            return [];
        }

        $currentKey = $this->jakartaCityDirectionKey($currentCity);
        if ($currentKey === null) {
            return [];
        }

        $directions = [
            'barat' => 'Jakarta Barat',
            'pusat' => 'Jakarta Pusat',
            'selatan' => 'Jakarta Selatan',
            'timur' => 'Jakarta Timur',
            'utara' => 'Jakarta Utara',
        ];
        unset($directions[$currentKey]);

        return array_values($directions);
    }

    private function jakartaCityDirectionKey(string $city): ?string
    {
        $normalized = $this->normalizeLabelKey($city);
        foreach (['barat', 'pusat', 'selatan', 'timur', 'utara'] as $direction) {
            if (str_contains($normalized, 'jakarta ' . $direction)) {
                return $direction;
            }
        }

        return null;
    }

    /**
     * Data lama bisa menyimpan beberapa include bertingkat sekaligus
     * (contoh: DKI Jakarta + Jakarta Selatan + Pasar Minggu). Untuk area
     * kerja aplikasi, rule yang lebih spesifik harus menang supaya user
     * Pasar Minggu tidak ikut melihat seluruh DKI/Jakarta Selatan.
     *
     * @param list<array<string, mixed>> $assignments
     * @return list<array<string, mixed>>
     */
    private function mostSpecificIncludeAssignments(array $assignments): array
    {
        if ($assignments === []) {
            return [];
        }

        $ranked = array_values(array_filter(
            $assignments,
            fn (array $assignment): bool => $this->scopeSpecificityRank($assignment['territory_scope'] ?? null) >= 0,
        ));

        if ($ranked === []) {
            return [];
        }

        $maxRank = max(array_map(
            fn (array $assignment): int => $this->scopeSpecificityRank($assignment['territory_scope'] ?? null),
            $ranked,
        ));

        return array_values(array_filter(
            $ranked,
            fn (array $assignment): bool => $this->scopeSpecificityRank($assignment['territory_scope'] ?? null) === $maxRank,
        ));
    }

    /**
     * @param array<string, mixed> $child
     * @param array<string, mixed> $parent
     */
    private function assignmentIsMoreSpecificInside(array $child, array $parent): bool
    {
        $childScope = $child['territory_scope'] ?? null;
        $parentScope = $parent['territory_scope'] ?? null;

        if ($parentScope === TerritoryScope::ALL_AREAS) {
            return $childScope !== TerritoryScope::ALL_AREAS;
        }

        if (! $this->scopeIsMoreSpecific($childScope, $parentScope)) {
            return false;
        }

        foreach ([
            'territory_province',
            'territory_city',
            'territory_district',
            'territory_subdistrict',
        ] as $field) {
            if (! filled($parent[$field] ?? null)) {
                continue;
            }

            if (! $this->labelsEquivalent((string) $parent[$field], (string) ($child[$field] ?? ''))) {
                return false;
            }
        }

        return true;
    }

    private function scopeIsMoreSpecific(?string $childScope, ?string $parentScope): bool
    {
        return $this->scopeSpecificityRank($childScope) > $this->scopeSpecificityRank($parentScope);
    }

    private function scopeSpecificityRank(?string $scope): int
    {
        return match ($scope) {
            TerritoryScope::ALL_AREAS => 0,
            TerritoryScope::PROVINCE => 1,
            TerritoryScope::CITY => 2,
            TerritoryScope::DISTRICT => 3,
            TerritoryScope::SUBDISTRICT => 4,
            default => -1,
        };
    }

    private function whereColumnMatchesAny($query, string $column, string $label): void
    {
        foreach ($this->labelVariants($label) as $index => $variant) {
            $method = $index === 0 ? 'where' : 'orWhere';
            $query->{$method}($column, $variant);
        }
    }

    private function labelsEquivalent(string $left, string $right): bool
    {
        $leftKeys = array_map(
            fn (string $variant) => $this->normalizeLabelKey($variant),
            $this->labelVariants($left),
        );
        $rightKeys = array_map(
            fn (string $variant) => $this->normalizeLabelKey($variant),
            $this->labelVariants($right),
        );

        return array_intersect($leftKeys, $rightKeys) !== [];
    }

    /**
     * @return list<string>
     */
    private function assignmentSearchLabels(array $assignment): array
    {
        $labels = [];
        foreach ([
            $assignment['territory_subdistrict'] ?? null,
            $assignment['territory_district'] ?? null,
            $assignment['territory_city'] ?? null,
            $assignment['territory_province'] ?? null,
            TerritoryData::displayLabel($assignment),
        ] as $label) {
            if (is_string($label) && ! in_array(trim($label), ['', '-'], true)) {
                foreach ($this->labelVariants($label) as $variant) {
                    $labels[$this->normalizeLabelKey($variant)] = $variant;
                }
                break;
            }
        }

        return array_values($labels);
    }

    /**
     * Import CSV historis kadang menaruh nama kecamatan/kelurahan pada kolom
     * struktur yang tidak konsisten. Selama teks legacy tetap match area user,
     * kolom struktur dianggap kompatibel bila berisi salah satu label hierarki
     * area yang sama.
     *
     * @return list<string>
     */
    private function assignmentCompatibleLabels(array $assignment): array
    {
        $labels = [];

        foreach (TerritoryData::PROFILE_FIELDS as $field) {
            $label = $assignment[$field] ?? null;
            if (! is_string($label) || in_array(trim($label), ['', '-'], true)) {
                continue;
            }

            foreach ($this->labelVariants($label) as $variant) {
                $labels[$this->normalizeLabelKey($variant)] = $variant;
            }
        }

        return array_values($labels);
    }

    private function whereStructuredTerritoryIsBlank($query): void
    {
        $query->where(function ($blank): void {
            foreach (TerritoryData::PROFILE_FIELDS as $field) {
                $blank->where(function ($column) use ($field): void {
                    $column
                        ->whereNull($field)
                        ->orWhere($field, '')
                        ->orWhere($field, '-');
                });
            }
        });
    }

    /**
     * CSV historis memakai beberapa bentuk nama wilayah yang berbeda dari data
     * master, jadi query area kerja perlu toleran tanpa mengubah data mentah.
     *
     * @return list<string>
     */
    private function labelVariants(string $label): array
    {
        $clean = trim($label);
        if ($clean === '') {
            return [];
        }

        $variants = [$clean];
        $withoutAdmin = preg_replace('/^(kota administrasi|kabupaten|kota)\s+/i', '', $clean);
        if (is_string($withoutAdmin) && trim($withoutAdmin) !== '') {
            $variants[] = trim($withoutAdmin);
        }

        $base = trim((string) $withoutAdmin);
        if (preg_match('/^jakarta\s+(barat|pusat|selatan|timur|utara)$/i', $base)) {
            $variants[] = 'Kota ' . $base;
            $variants[] = 'Kota Administrasi ' . $base;
        }

        if (preg_match('/^dki\s+jakarta$/i', $clean)) {
            $variants[] = 'Daerah Khusus Ibukota Jakarta';
            $variants[] = 'Daerah Khusus ibukota Jakarta';
        }

        if (preg_match('/^daerah\s+khusus\s+ibukota\s+jakarta$/i', $clean)) {
            $variants[] = 'DKI Jakarta';
        }

        $unique = [];
        foreach ($variants as $variant) {
            $trimmed = trim($variant);
            if ($trimmed !== '') {
                $unique[$this->normalizeLabelKey($trimmed)] ??= $trimmed;
            }
        }

        return array_values($unique);
    }

    private function normalizeLabelKey(string $label): string
    {
        return mb_strtolower(preg_replace('/\s+/', ' ', trim($label)) ?? trim($label));
    }

    private function assertWithinTerritory(User $actor, array $territory, string $profileType): void
    {
        // FGG dan Area Manager boleh input jaringan di wilayah mana saja.
        // Data tetap dikembalikan ke user lain berdasarkan wilayah data.
        return;
    }
}
