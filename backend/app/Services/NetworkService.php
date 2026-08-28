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

    public function queryOwned(User $owner, ?string $type = null, ?string $search = null)
    {
        $query = NetworkProfile::query();

        if ($type !== null && $type !== '') {
            $query->where('type', $type);
        }

        if ($owner->role === UserRole::FGG && TerritoryData::isAssigned($owner)) {
            $query->where(function ($builder) use ($owner): void {
                $builder
                    ->where('owner_id', $owner->id)
                    ->orWhere(function ($territory) use ($owner): void {
                        $this->applyTerritoryScope($territory, $owner);
                    });
            });
        } elseif ($owner->role === UserRole::AREA_MANAGER && TerritoryData::isAssigned($owner)) {
            $query->where(function ($builder) use ($owner): void {
                $builder
                    ->where('owner_id', $owner->id)
                    ->orWhere(function ($territory) use ($owner): void {
                        $this->applyTerritoryScope($territory, $owner);
                    });
            });
        } elseif ($owner->role === UserRole::MANAGEMENT && TerritoryData::isAssigned($owner)) {
            $query->where(function ($builder) use ($owner): void {
                $builder
                    ->where('owner_id', $owner->id)
                    ->orWhere(function ($territory) use ($owner): void {
                        $this->applyTerritoryScope($territory, $owner);
                    });
            });
        } else {
            $query->where('owner_id', $owner->id);
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
        $includes = TerritoryData::includeAssignments($assignments);
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

        $builder->{$method}(function ($group) use ($assignment, $method, $scopeField, $legacyLabel): void {
            $group->where(function ($structured) use ($assignment): void {
                if (filled($assignment['territory_province'])) {
                    $structured->where(function ($column) use ($assignment): void {
                        $this->whereColumnMatchesAny($column, 'territory_province', $assignment['territory_province']);
                    });
                }
                if (filled($assignment['territory_city'])) {
                    $structured->where(function ($column) use ($assignment): void {
                        $this->whereColumnMatchesAny($column, 'territory_city', $assignment['territory_city']);
                    });
                }
                if (filled($assignment['territory_district'])) {
                    $structured->where(function ($column) use ($assignment): void {
                        $this->whereColumnMatchesAny($column, 'territory_district', $assignment['territory_district']);
                    });
                }
                if (filled($assignment['territory_subdistrict'])) {
                    $structured->where(function ($column) use ($assignment): void {
                        $this->whereColumnMatchesAny($column, 'territory_subdistrict', $assignment['territory_subdistrict']);
                    });
                }
            });

            if ($method !== 'whereNot' && $scopeField !== null && filled($legacyLabel)) {
                foreach ($this->assignmentSearchLabels($assignment) as $label) {
                    $group->orWhere(function ($text) use ($label): void {
                        $this->whereTerritoryTextMatches($text, $label);
                    });
                }
            }
        });
    }

    private function whereColumnMatchesAny($query, string $column, string $label): void
    {
        foreach ($this->labelVariants($label) as $index => $variant) {
            $method = $index === 0 ? 'where' : 'orWhere';
            $query->{$method}($column, $variant);
        }
    }

    /**
     * @return list<string>
     */
    private function assignmentSearchLabels(array $assignment): array
    {
        $labels = [];
        foreach ([
            TerritoryData::displayLabel($assignment),
            $assignment['territory_subdistrict'] ?? null,
            $assignment['territory_district'] ?? null,
            $assignment['territory_city'] ?? null,
            $assignment['territory_province'] ?? null,
        ] as $label) {
            if (is_string($label) && trim($label) !== '') {
                foreach ($this->labelVariants($label) as $variant) {
                    $labels[$this->normalizeLabelKey($variant)] = $variant;
                }
            }
        }

        return array_values($labels);
    }

    private function whereTerritoryTextMatches($query, string $label): void
    {
        $query->where(function ($variants) use ($label): void {
            foreach ($this->labelVariants($label) as $variant) {
                $variants
                    ->orWhere('area_name', $variant)
                    ->orWhere('territory_province', $variant)
                    ->orWhere('territory_city', $variant)
                    ->orWhere('territory_district', $variant)
                    ->orWhere('territory_subdistrict', $variant)
                    ->orWhere(function ($fallback) use ($variant): void {
                        $this->whereStructuredTerritoryIsBlank($fallback);
                        $fallback->where(function ($text) use ($variant): void {
                            $text
                                ->where('address', 'like', '%' . $variant . '%')
                                ->orWhere('note', 'like', '%' . $variant . '%');
                        });
                    });
            }
        });
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
        if (! in_array($actor->role, [UserRole::FGG, UserRole::AREA_MANAGER], true)) {
            return;
        }

        if (! TerritoryData::isAssigned($actor)) {
            throw ValidationException::withMessages([
                'territory' => TerritoryData::assignmentHint($actor),
            ]);
        }

        if (! TerritoryData::covers($actor, $territory)) {
            throw ValidationException::withMessages([
                'territory' => TerritoryData::messageForOutsideArea($profileType),
            ]);
        }
    }
}
