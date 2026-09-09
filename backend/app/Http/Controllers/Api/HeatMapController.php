<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NetworkProfile;
use App\Services\NetworkService;
use App\Support\FieldOps\FieldApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HeatMapController extends Controller
{
    public function __invoke(Request $request, NetworkService $networkService): JsonResponse
    {
        $validated = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_meters' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'type' => ['nullable', 'in:ukm,mitra'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:1000'],
        ]);

        $radiusMeters = (int) ($validated['radius_meters'] ?? 1000);
        $latitude = (float) $validated['latitude'];
        $longitude = (float) $validated['longitude'];
        $page = max(1, (int) ($validated['page'] ?? 1));
        $perPage = min(1000, max(1, (int) ($validated['per_page'] ?? 1000)));
        $bounds = $this->boundsForRadius($latitude, $longitude, $radiusMeters);

        $profiles = $networkService
            ->scopeForHeatMap($request->user())
            ->select([
                'id',
                'owner_name',
                'type',
                'name',
                'address',
                'phone_number',
                'status',
                'note',
                'latitude',
                'longitude',
            ])
            ->when(
                isset($validated['type']),
                fn ($query) => $query->where('type', $validated['type'])
            )
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->whereBetween('latitude', [$bounds['min_latitude'], $bounds['max_latitude']])
            ->whereBetween('longitude', [$bounds['min_longitude'], $bounds['max_longitude']])
            ->get()
            ->map(function (NetworkProfile $profile) use ($latitude, $longitude) {
                $distance = $this->distanceInMeters(
                    $latitude,
                    $longitude,
                    (float) $profile->latitude,
                    (float) $profile->longitude,
                );

                return [
                    'profile' => $profile,
                    'distance' => $distance,
                ];
            })
            ->filter(fn (array $item) => $item['distance'] <= $radiusMeters)
            ->sortBy('distance')
            ->values();
        $total = $profiles->count();
        $pageProfiles = $profiles
            ->skip(($page - 1) * $perPage)
            ->take($perPage)
            ->values();

        return response()->json([
            'data' => [
                'user_location' => [
                    'latitude' => $latitude,
                    'longitude' => $longitude,
                    'recorded_at' => now()->toIso8601String(),
                ],
                'radius_meters' => $radiusMeters,
                'points' => $pageProfiles
                    ->map(fn (array $item) => FieldApiData::heatMapPoint($item['profile'], $item['distance']))
                    ->values(),
            ],
            'meta' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'count' => $pageProfiles->count(),
                'total' => $total,
                'has_more' => ($page * $perPage) < $total,
                'next_page' => ($page * $perPage) < $total ? $page + 1 : null,
            ],
        ]);
    }

    private function distanceInMeters(
        float $latitudeOne,
        float $longitudeOne,
        float $latitudeTwo,
        float $longitudeTwo,
    ): float {
        $earthRadius = 6371000;
        $deltaLatitude = deg2rad($latitudeTwo - $latitudeOne);
        $deltaLongitude = deg2rad($longitudeTwo - $longitudeOne);
        $start = deg2rad($latitudeOne);
        $end = deg2rad($latitudeTwo);

        $a = sin($deltaLatitude / 2) ** 2
            + cos($start) * cos($end) * sin($deltaLongitude / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadius * $c;
    }

    /**
     * @return array{min_latitude:float,max_latitude:float,min_longitude:float,max_longitude:float}
     */
    private function boundsForRadius(float $latitude, float $longitude, int $radiusMeters): array
    {
        $latitudeDelta = $radiusMeters / 111320;
        $longitudeMeters = max(1, 111320 * cos(deg2rad($latitude)));
        $longitudeDelta = $radiusMeters / $longitudeMeters;

        return [
            'min_latitude' => max(-90, $latitude - $latitudeDelta),
            'max_latitude' => min(90, $latitude + $latitudeDelta),
            'min_longitude' => max(-180, $longitude - $longitudeDelta),
            'max_longitude' => min(180, $longitude + $longitudeDelta),
        ];
    }
}
