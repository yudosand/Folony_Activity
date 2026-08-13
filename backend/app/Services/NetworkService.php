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
        $query = NetworkProfile::query()
            ->with('followUps')
            ->orderByDesc('created_at');

        if ($owner->role === UserRole::FGG && TerritoryData::isAssigned($owner)) {
            $query
                ->where('type', 'ukm')
                ->where(function ($builder) use ($owner): void {
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
                        $territory->where('owner_role', '!=', UserRole::FGG);
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

        if ($type !== null && $type !== '') {
            $query->where('type', $type);
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

    public function queryTeamUkm(User $areaManager, ?string $search = null)
    {
        $query = NetworkProfile::query()
            ->with('followUps')
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
        $query = NetworkProfile::query()->with('followUps');

        if (($actor->role === UserRole::AREA_MANAGER || $actor->role === UserRole::FGG || $actor->role === UserRole::MANAGEMENT)
            && TerritoryData::isAssigned($actor)) {
            if ($actor->role === UserRole::FGG) {
                $query->where('type', 'ukm');
            }

            return $query->where(function ($builder) use ($actor): void {
                $builder
                    ->where('owner_id', $actor->id)
                    ->orWhere(function ($territory) use ($actor): void {
                        $this->applyTerritoryScope($territory, $actor);
                    });
            });
        }

        return $query->where('owner_id', $actor->id);
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
            if ($actor->role === UserRole::FGG && $profile->type !== 'ukm') {
                abort(403, 'FGG hanya bisa mengelola data UKM di area kerjanya.');
            }

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
            if ($actor->role === UserRole::FGG && $profile->type !== 'ukm') {
                abort(403, 'FGG hanya bisa membuka data UKM di area kerjanya.');
            }

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

        $builder->{$method}(function ($group) use ($assignment, $scopeField, $legacyLabel): void {
            $group->where(function ($structured) use ($assignment): void {
                if (filled($assignment['territory_province'])) {
                    $structured->where('territory_province', $assignment['territory_province']);
                }
                if (filled($assignment['territory_city'])) {
                    $structured->where('territory_city', $assignment['territory_city']);
                }
                if (filled($assignment['territory_district'])) {
                    $structured->where('territory_district', $assignment['territory_district']);
                }
                if (filled($assignment['territory_subdistrict'])) {
                    $structured->where('territory_subdistrict', $assignment['territory_subdistrict']);
                }
            });

            if ($scopeField !== null && filled($legacyLabel)) {
                $group->orWhere(function ($legacy) use ($scopeField, $legacyLabel): void {
                    $legacy
                        ->whereNull($scopeField)
                        ->where('area_name', $legacyLabel);
                });
            }
        });
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
