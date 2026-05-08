<?php

namespace App\Support\Workflow;

final class UserRole
{
    public const STAFF = 'staff';
    public const SPV = 'spv';
    public const AREA_MANAGER = 'areaManager';
    public const MANAGEMENT = 'management';
    public const FGG = 'fgg';

    public const ALL = [
        self::STAFF,
        self::SPV,
        self::AREA_MANAGER,
        self::MANAGEMENT,
        self::FGG,
    ];
}
