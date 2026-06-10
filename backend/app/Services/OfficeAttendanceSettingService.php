<?php

namespace App\Services;

use App\Models\AppSetting;

class OfficeAttendanceSettingService
{
    private const KEY_LATITUDE = 'attendance.office_latitude';
    private const KEY_LONGITUDE = 'attendance.office_longitude';
    private const KEY_RADIUS = 'attendance.office_radius_meters';

    private const DEFAULT_LATITUDE = -6.159692890088879;
    private const DEFAULT_LONGITUDE = 106.81804453790896;
    private const DEFAULT_RADIUS = 1000;

    public function current(): array
    {
        $rows = AppSetting::query()
            ->whereIn('key', [
                self::KEY_LATITUDE,
                self::KEY_LONGITUDE,
                self::KEY_RADIUS,
            ])
            ->pluck('value', 'key');

        return [
            'latitude' => isset($rows[self::KEY_LATITUDE])
                ? (float) $rows[self::KEY_LATITUDE]
                : self::DEFAULT_LATITUDE,
            'longitude' => isset($rows[self::KEY_LONGITUDE])
                ? (float) $rows[self::KEY_LONGITUDE]
                : self::DEFAULT_LONGITUDE,
            'radius_meters' => isset($rows[self::KEY_RADIUS])
                ? (int) $rows[self::KEY_RADIUS]
                : self::DEFAULT_RADIUS,
        ];
    }

    public function update(float $latitude, float $longitude, int $radiusMeters): void
    {
        AppSetting::query()->updateOrCreate(
            ['key' => self::KEY_LATITUDE],
            ['value' => (string) $latitude],
        );

        AppSetting::query()->updateOrCreate(
            ['key' => self::KEY_LONGITUDE],
            ['value' => (string) $longitude],
        );

        AppSetting::query()->updateOrCreate(
            ['key' => self::KEY_RADIUS],
            ['value' => (string) $radiusMeters],
        );
    }
}
