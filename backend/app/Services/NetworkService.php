<?php

namespace App\Services;

use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Support\Workflow\UserRole;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class NetworkService
{
    public function create(array $payload, User $owner): NetworkProfile
    {
        $profileId = Arr::get($payload, 'id', (string) Str::uuid());
        $existing = NetworkProfile::query()
            ->where('id', $profileId)
            ->where('owner_id', $owner->id)
            ->first();

        if ($existing) {
            return $this->update($existing, $payload, $owner);
        }

        $profile = NetworkProfile::query()->create([
            'id' => $profileId,
            'owner_id' => $owner->id,
            'owner_name' => $owner->full_name,
            'owner_role' => $owner->role,
            'area_name' => $owner->area_name,
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

        $profile->update([
            'type' => $payload['type'] ?? $profile->type,
            'name' => $payload['name'] ?? $profile->name,
            'address' => $payload['address'] ?? $profile->address,
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

        NetworkFollowUp::query()->create([
            'id' => Arr::get($payload, 'id', (string) Str::uuid()),
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
            ->where('owner_id', $owner->id)
            ->orderByDesc('created_at');

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
            ->where('area_name', $areaManager->area_name)
            ->orderByDesc('created_at');

        if ($search !== null && $search !== '') {
            $query->where(function ($builder) use ($search): void {
                $builder
                    ->where('name', 'like', '%' . $search . '%')
                    ->orWhere('address', 'like', '%' . $search . '%');
            });
        }

        return $query;
    }

    public function scopeForHeatMap(User $actor)
    {
        $query = NetworkProfile::query()->with('followUps');

        if ($actor->role === UserRole::AREA_MANAGER) {
            return $query->where(function ($builder) use ($actor): void {
                $builder
                    ->where('owner_id', $actor->id)
                    ->orWhere(function ($inner) use ($actor): void {
                        $inner
                            ->where('owner_role', UserRole::FGG)
                            ->where('area_name', $actor->area_name);
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
        abort_if($profile->owner_id !== $actor->id, 403, 'Data jaringan ini bukan milik user aktif.');
    }

    private function assertViewable(NetworkProfile $profile, User $actor): void
    {
        if ($profile->owner_id === $actor->id) {
            return;
        }

        $isAreaManagerScope = $actor->role === UserRole::AREA_MANAGER
            && $profile->owner_role === UserRole::FGG
            && $profile->area_name === $actor->area_name;

        abort_if(! $isAreaManagerScope, 403, 'Data jaringan ini tidak bisa diakses user aktif.');
    }
}
