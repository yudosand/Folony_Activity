<?php

namespace App\Support\Performance;

use App\Support\Workflow\UserRole;

final class PerformanceMetric
{
    public const FGG_NEW_UKM = 'fgg_new_ukm';
    public const FGG_FOLLOW_UP_VISIT = 'fgg_follow_up_visit';
    public const AREA_MANAGER_TEAM_NEW_UKM = 'area_manager_team_new_ukm';
    public const AREA_MANAGER_NEW_MITRA = 'area_manager_new_mitra';
    public const AREA_MANAGER_TEAM_FOLLOW_UP_VISIT = 'area_manager_team_follow_up_visit';

    public const ALL = [
        self::FGG_NEW_UKM,
        self::FGG_FOLLOW_UP_VISIT,
        self::AREA_MANAGER_TEAM_NEW_UKM,
        self::AREA_MANAGER_NEW_MITRA,
        self::AREA_MANAGER_TEAM_FOLLOW_UP_VISIT,
    ];

    public const DEFINITIONS = [
        self::FGG_NEW_UKM => [
            'label' => 'UKM Baru',
            'description' => 'Jumlah UKM baru yang dibuat FGG pada bulan aktif.',
            'unit' => 'UKM',
            'roles' => [UserRole::FGG],
        ],
        self::FGG_FOLLOW_UP_VISIT => [
            'label' => 'Kunjungan',
            'description' => 'Jumlah follow-up baru yang disimpan FGG pada bulan aktif.',
            'unit' => 'kunjungan',
            'roles' => [UserRole::FGG],
        ],
        self::AREA_MANAGER_TEAM_NEW_UKM => [
            'label' => 'UKM Baru Tim',
            'description' => 'Akumulasi UKM baru dari seluruh FGG di wilayah Area Manager ditambah UKM baru buatan Area Manager sendiri.',
            'unit' => 'UKM',
            'roles' => [UserRole::AREA_MANAGER],
        ],
        self::AREA_MANAGER_NEW_MITRA => [
            'label' => 'Mitra Baru',
            'description' => 'Jumlah mitra baru yang dibuat langsung oleh Area Manager pada bulan aktif.',
            'unit' => 'mitra',
            'roles' => [UserRole::AREA_MANAGER],
        ],
        self::AREA_MANAGER_TEAM_FOLLOW_UP_VISIT => [
            'label' => 'Kunjungan Tim',
            'description' => 'Akumulasi follow-up baru dari seluruh FGG di wilayah Area Manager pada bulan aktif.',
            'unit' => 'kunjungan',
            'roles' => [UserRole::AREA_MANAGER],
        ],
    ];

    public static function forRole(string $role): array
    {
        return array_values(array_filter(
            self::ALL,
            static fn (string $metric) => in_array($role, self::DEFINITIONS[$metric]['roles'] ?? [], true),
        ));
    }

    public static function definition(string $metric): array
    {
        return self::DEFINITIONS[$metric] ?? [
            'label' => $metric,
            'description' => '',
            'unit' => 'item',
            'roles' => [],
        ];
    }
}
