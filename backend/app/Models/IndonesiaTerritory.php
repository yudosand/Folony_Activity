<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class IndonesiaTerritory extends Model
{
    public const LEVEL_PROVINCE = 'province';
    public const LEVEL_CITY = 'city';
    public const LEVEL_DISTRICT = 'district';
    public const LEVEL_SUBDISTRICT = 'subdistrict';

    public const LEVELS = [
        self::LEVEL_PROVINCE,
        self::LEVEL_CITY,
        self::LEVEL_DISTRICT,
        self::LEVEL_SUBDISTRICT,
    ];

    protected $fillable = [
        'code',
        'level',
        'name',
        'normalized_name',
        'parent_code',
        'province_code',
        'city_code',
        'district_code',
        'province_name',
        'city_name',
        'district_name',
    ];
}
