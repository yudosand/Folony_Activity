<?php

namespace App\Support\Territory;

final class TerritoryScope
{
    public const ALL_AREAS = 'all';
    public const PROVINCE = 'province';
    public const CITY = 'city';
    public const DISTRICT = 'district';
    public const SUBDISTRICT = 'subdistrict';

    public const ALL = [
        self::ALL_AREAS,
        self::PROVINCE,
        self::CITY,
        self::DISTRICT,
        self::SUBDISTRICT,
    ];
}
