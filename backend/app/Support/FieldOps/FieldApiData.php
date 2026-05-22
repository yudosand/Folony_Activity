<?php

namespace App\Support\FieldOps;

use App\Models\AttendanceRecord;
use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use Illuminate\Support\Carbon;

class FieldApiData
{
    public static function networkProfile(NetworkProfile $profile): array
    {
        return [
            'id' => $profile->id,
            'owner_id' => $profile->owner_id,
            'owner_name' => $profile->owner_name,
            'owner_role' => $profile->owner_role,
            'area_name' => $profile->area_name,
            'type' => $profile->type,
            'name' => $profile->name,
            'address' => $profile->address,
            'territory_province' => $profile->territory_province,
            'territory_city' => $profile->territory_city,
            'territory_district' => $profile->territory_district,
            'territory_subdistrict' => $profile->territory_subdistrict,
            'business_type' => $profile->business_type,
            'phone_number' => $profile->phone_number,
            'status' => $profile->status,
            'created_at' => self::dateTime($profile->created_at),
            'reference_name' => $profile->reference_name,
            'note' => $profile->note,
            'photo' => $profile->photo_attachment,
            'personality_metrics' => $profile->personality_metrics ?? [],
            'documents' => $profile->documents ?? [],
            'follow_ups' => $profile->followUps
                ->map(fn (NetworkFollowUp $followUp) => self::networkFollowUp($followUp))
                ->values()
                ->all(),
            'latitude' => $profile->latitude,
            'longitude' => $profile->longitude,
        ];
    }

    public static function networkFollowUp(NetworkFollowUp $followUp): array
    {
        return [
            'id' => $followUp->id,
            'title' => $followUp->title,
            'note' => $followUp->note,
            'actor_id' => $followUp->actor_id,
            'actor_name' => $followUp->actor_name,
            'created_at' => self::dateTime($followUp->created_at),
        ];
    }

    public static function attendanceRecord(AttendanceRecord $record): array
    {
        return [
            'id' => $record->id,
            'user_id' => $record->user_id,
            'work_date' => self::dateTime($record->work_date),
            'action' => $record->action,
            'status' => $record->status,
            'recorded_at' => self::dateTime($record->recorded_at),
            'location' => $record->location ?? [],
            'verification' => $record->verification,
            'note' => $record->note,
        ];
    }

    public static function heatMapPoint(NetworkProfile $profile, float $distanceMeter): array
    {
        return [
            'id' => $profile->id,
            'type' => $profile->type,
            'name' => $profile->name,
            'address' => $profile->address,
            'phone_number' => $profile->phone_number,
            'status' => $profile->status,
            'note' => $profile->followUps->first()?->note ?? $profile->note,
            'distance_meter' => (int) round($distanceMeter),
            'latitude' => $profile->latitude,
            'longitude' => $profile->longitude,
            'owner_name' => $profile->owner_name,
        ];
    }

    private static function dateTime(Carbon|string|null $value): ?string
    {
        if ($value instanceof Carbon) {
            return $value->toIso8601String();
        }

        if (is_string($value) && $value !== '') {
            return Carbon::parse($value)->toIso8601String();
        }

        return null;
    }
}
