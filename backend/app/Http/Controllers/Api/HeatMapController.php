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
        ]);

        $radiusMeters = (int) ($validated['radius_meters'] ?? 1000);
        $latitude = (float) $validated['latitude'];
        $longitude = (float) $validated['longitude'];

        $profiles = $networkService
            ->scopeForHeatMap($request->user())
            ->when(
                isset($validated['type']),
                fn ($query) => $query->where('type', $validated['type'])
            )
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
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

        return response()->json([
            'data' => [
                'user_location' => [
                    'latitude' => $latitude,
                    'longitude' => $longitude,
                    'recorded_at' => now()->toIso8601String(),
                ],
                'radius_meters' => $radiusMeters,
                'points' => $profiles
                    ->map(fn (array $item) => FieldApiData::heatMapPoint($item['profile'], $item['distance']))
                    ->values(),
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
}
