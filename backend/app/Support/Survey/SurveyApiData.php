<?php

namespace App\Support\Survey;

use App\Models\SurveyCommodityOption;
use App\Models\SurveyProductOption;
use App\Models\SurveyResponse;

class SurveyApiData
{
    public static function options(): array
    {
        return [
            'products' => SurveyProductOption::query()
                ->where('is_active', true)
                ->orderBy('name')
                ->get()
                ->map(fn (SurveyProductOption $option): array => [
                    'id' => $option->id,
                    'name' => $option->name,
                ])
                ->values()
                ->all(),
            'commodities' => SurveyCommodityOption::query()
                ->where('is_active', true)
                ->orderBy('name')
                ->get()
                ->map(fn (SurveyCommodityOption $option): array => [
                    'id' => $option->id,
                    'name' => $option->name,
                    'unit' => $option->unit,
                ])
                ->values()
                ->all(),
            'building_types' => [
                'Permanen',
                'Semi permanen',
                'Non permanen',
                'Ruko',
                'Lapak terbuka',
            ],
            'kiosk_sizes' => [
                'Kurang dari 5 meter',
                '5 - 10 Meter',
                '10 - 15 Meter',
            ],
        ];
    }

    public static function response(SurveyResponse $response): array
    {
        return [
            'id' => $response->id,
            'type' => $response->type,
            'type_label' => SurveyType::label($response->type),
            'user_id' => $response->user_id,
            'user_name' => $response->user_name,
            'user_role' => $response->user_role,
            'area_name' => $response->area_name,
            'territory_province' => $response->territory_province,
            'territory_city' => $response->territory_city,
            'territory_district' => $response->territory_district,
            'territory_subdistrict' => $response->territory_subdistrict,
            'photo' => $response->photo_attachment,
            'payload' => $response->payload ?? [],
            'submitted_at' => optional($response->submitted_at)->toIso8601String(),
        ];
    }
}
