<?php

namespace App\Support\Workflow;

final class UserRole
{
    public const HR = 'hr';
    public const STAFF = 'staff';
    public const SPV = 'spv';
    public const AREA_MANAGER = 'areaManager';
    public const MANAGEMENT = 'management';
    public const FGG = 'fgg';

    public const ALL = [
        self::HR,
        self::STAFF,
        self::SPV,
        self::AREA_MANAGER,
        self::MANAGEMENT,
        self::FGG,
    ];

    public const LABELS = [
        self::HR => 'HR',
        self::STAFF => 'Staff',
        self::SPV => 'SPV',
        self::AREA_MANAGER => 'Area Manager',
        self::MANAGEMENT => 'Management',
        self::FGG => 'FGG',
    ];

    public static function label(?string $role): string
    {
        if ($role === null || $role === '') {
            return '-';
        }

        return self::LABELS[$role] ?? $role;
    }

    /**
     * @return array<string, string>
     */
    public static function adminOptions(): array
    {
        return array_filter(
            self::LABELS,
            fn (string $role): bool => $role !== self::HR,
            ARRAY_FILTER_USE_KEY,
        );
    }
}
