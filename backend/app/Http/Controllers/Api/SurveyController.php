<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SurveyCommodityOption;
use App\Models\SurveyProductOption;
use App\Models\SurveyResponse;
use App\Support\Survey\SurveyApiData;
use App\Support\Survey\SurveyType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SurveyController extends Controller
{
    public function options(): JsonResponse
    {
        return response()->json([
            'data' => SurveyApiData::options(),
        ]);
    }

    public function storeKios(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'photo' => ['required', 'array'],
            'photo.id' => ['required', 'string'],
            'photo.file_name' => ['required', 'string'],
            'photo.mime_type' => ['required', 'string'],
            'photo.url' => ['required', 'string'],
            'photo.thumbnail_url' => ['nullable', 'string'],
            'photo.size_in_bytes' => ['nullable', 'integer'],
            'territory_province' => ['nullable', 'string', 'max:255'],
            'territory_city' => ['nullable', 'string', 'max:255'],
            'territory_district' => ['nullable', 'string', 'max:255'],
            'territory_subdistrict' => ['nullable', 'string', 'max:255'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'location_accuracy_meters' => ['nullable', 'numeric', 'min:0'],
            'location_address' => ['nullable', 'string', 'max:1000'],
            'kiosk_name' => ['required', 'string', 'max:255'],
            'kiosk_address' => ['required', 'string', 'max:1000'],
            'phone_number' => ['required', 'string', 'max:32'],
            'owner_name' => ['required', 'string', 'max:255'],
            'product_ids' => ['nullable', 'array'],
            'product_ids.*' => ['string'],
            'other_product' => ['nullable', 'string', 'max:500'],
            'building_types' => ['required', 'array', 'min:1'],
            'building_types.*' => ['string', 'max:100'],
            'kiosk_sizes' => ['required', 'array', 'min:1'],
            'kiosk_sizes.*' => ['string', 'max:100'],
        ]);

        $selectedProducts = SurveyProductOption::query()
            ->whereIn('id', $payload['product_ids'] ?? [])
            ->orderBy('name')
            ->get(['id', 'name'])
            ->map(fn (SurveyProductOption $option): array => [
                'id' => $option->id,
                'name' => $option->name,
            ])
            ->values()
            ->all();

        $response = $this->createResponse($request, SurveyType::KIOS, $payload, [
            'kiosk_name' => $payload['kiosk_name'],
            'kiosk_address' => $payload['kiosk_address'],
            'phone_number' => $payload['phone_number'],
            'owner_name' => $payload['owner_name'],
            'products' => $selectedProducts,
            'other_product' => trim((string) ($payload['other_product'] ?? '')),
            'building_types' => array_values($payload['building_types']),
            'kiosk_sizes' => array_values($payload['kiosk_sizes']),
        ]);

        return response()->json([
            'data' => SurveyApiData::response($response),
        ], 201);
    }

    public function storePrices(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'photo' => ['required', 'array'],
            'photo.id' => ['required', 'string'],
            'photo.file_name' => ['required', 'string'],
            'photo.mime_type' => ['required', 'string'],
            'photo.url' => ['required', 'string'],
            'photo.thumbnail_url' => ['nullable', 'string'],
            'photo.size_in_bytes' => ['nullable', 'integer'],
            'market_name' => ['required', 'string', 'max:255'],
            'territory_province' => ['nullable', 'string', 'max:255'],
            'territory_city' => ['nullable', 'string', 'max:255'],
            'territory_district' => ['nullable', 'string', 'max:255'],
            'territory_subdistrict' => ['nullable', 'string', 'max:255'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'location_accuracy_meters' => ['nullable', 'numeric', 'min:0'],
            'location_address' => ['nullable', 'string', 'max:1000'],
            'commodity_prices' => ['required', 'array', 'min:1'],
            'commodity_prices.*.commodity_id' => [
                'required',
                'string',
                Rule::exists('survey_commodity_options', 'id'),
            ],
            'commodity_prices.*.commodity_name' => ['required', 'string', 'max:255'],
            'commodity_prices.*.unit' => ['nullable', 'string', 'max:64'],
            'commodity_prices.*.lowest_price' => ['required', 'numeric', 'min:0'],
            'commodity_prices.*.highest_price' => ['required', 'numeric', 'min:0'],
        ]);

        foreach ($payload['commodity_prices'] as $index => $item) {
            if ((float) $item['lowest_price'] > (float) $item['highest_price']) {
                throw ValidationException::withMessages([
                    "commodity_prices.$index.lowest_price" => 'Harga terendah tidak boleh lebih besar dari harga tertinggi.',
                ]);
            }
        }

        $response = $this->createResponse($request, SurveyType::HARGA, $payload, [
            'market_name' => $payload['market_name'],
            'commodity_prices' => collect($payload['commodity_prices'])
                ->map(fn (array $item): array => [
                    'commodity_id' => $item['commodity_id'],
                    'commodity_name' => $item['commodity_name'],
                    'unit' => $item['unit'] ?? null,
                    'lowest_price' => (float) $item['lowest_price'],
                    'highest_price' => (float) $item['highest_price'],
                ])
                ->values()
                ->all(),
        ]);

        return response()->json([
            'data' => SurveyApiData::response($response),
        ], 201);
    }

    private function createResponse(
        Request $request,
        string $type,
        array $payload,
        array $surveyPayload,
    ): SurveyResponse {
        $user = $request->user();
        $latitude = (float) $payload['latitude'];
        $longitude = (float) $payload['longitude'];
        $coordinateLabel = number_format($latitude, 6, '.', '') . ', ' . number_format($longitude, 6, '.', '');
        $locationAddress = trim((string) ($payload['location_address'] ?? ''));
        $readableArea = $locationAddress !== '' ? $locationAddress : $coordinateLabel;

        return SurveyResponse::query()->create([
            'id' => (string) Str::uuid(),
            'type' => $type,
            'user_id' => $user->id,
            'user_name' => $user->full_name,
            'user_role' => $user->role,
            'area_name' => $user->area_name,
            'territory_province' => filled($payload['territory_province'] ?? null)
                ? $payload['territory_province']
                : 'Lokasi GPS',
            'territory_city' => filled($payload['territory_city'] ?? null)
                ? $payload['territory_city']
                : $readableArea,
            'territory_district' => filled($payload['territory_district'] ?? null)
                ? $payload['territory_district']
                : ($locationAddress !== '' ? 'Alamat GPS' : 'Koordinat Survey'),
            'territory_subdistrict' => filled($payload['territory_subdistrict'] ?? null)
                ? $payload['territory_subdistrict']
                : 'GPS',
            'latitude' => $latitude,
            'longitude' => $longitude,
            'location_accuracy_meters' => Arr::get($payload, 'location_accuracy_meters'),
            'photo_attachment' => Arr::get($payload, 'photo', []),
            'payload' => array_merge($surveyPayload, [
                'location_address' => $locationAddress,
            ]),
            'submitted_at' => now(),
        ]);
    }
}
