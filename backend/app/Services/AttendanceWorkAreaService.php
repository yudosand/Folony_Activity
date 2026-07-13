<?php

namespace App\Services;

use App\Models\AttendanceWorkArea;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;

class AttendanceWorkAreaService
{
    public function areaForUser(User $user): AttendanceWorkArea
    {
        $area = $user->attendanceWorkArea;
        if ($area instanceof AttendanceWorkArea && $area->is_active) {
            return $area;
        }

        $fallback = AttendanceWorkArea::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->first();

        if ($fallback instanceof AttendanceWorkArea) {
            return $fallback;
        }

        return AttendanceWorkArea::query()->updateOrCreate(
            ['id' => 'work_area_ho'],
            [
                'name' => 'Kantor Pusat',
                'latitude' => -6.1596929,
                'longitude' => 106.8180445,
                'radius_meters' => 1000,
                'is_active' => true,
            ],
        );
    }

    /**
     * @return array{id:string,name:string,latitude:float,longitude:float,radius_meters:int}
     */
    public function apiPayloadForUser(User $user): array
    {
        $area = $this->areaForUser($user);

        return [
            'id' => $area->id,
            'name' => $area->name,
            'latitude' => (float) $area->latitude,
            'longitude' => (float) $area->longitude,
            'radius_meters' => (int) $area->radius_meters,
        ];
    }

    public function assertLocationWithinUserArea(User $user, array $location): array
    {
        $area = $this->areaForUser($user);
        $latitude = (float) Arr::get($location, 'latitude', 0);
        $longitude = (float) Arr::get($location, 'longitude', 0);
        $distanceMeters = $this->distanceMeters(
            (float) $area->latitude,
            (float) $area->longitude,
            $latitude,
            $longitude,
        );
        $radiusMeters = (int) $area->radius_meters;

        if ($distanceMeters > $radiusMeters) {
            throw ValidationException::withMessages([
                'location' => 'Anda tidak berada di area kantor.',
            ]);
        }

        return [
            'work_area_id' => $area->id,
            'work_area_name' => $area->name,
            'work_area_latitude' => (float) $area->latitude,
            'work_area_longitude' => (float) $area->longitude,
            'radius_meters' => $radiusMeters,
            'distance_meters' => round($distanceMeters, 2),
            'within_radius' => true,
        ];
    }

    private function distanceMeters(
        float $fromLatitude,
        float $fromLongitude,
        float $toLatitude,
        float $toLongitude,
    ): float {
        $earthRadiusMeters = 6371000;
        $latitudeDelta = deg2rad($toLatitude - $fromLatitude);
        $longitudeDelta = deg2rad($toLongitude - $fromLongitude);

        $a = sin($latitudeDelta / 2) ** 2
            + cos(deg2rad($fromLatitude))
            * cos(deg2rad($toLatitude))
            * sin($longitudeDelta / 2) ** 2;

        return $earthRadiusMeters * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
