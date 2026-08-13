<?php

namespace App\Support\Survey;

final class SurveyType
{
    public const KIOS = 'kios';
    public const HARGA = 'harga';

    public const ALL = [
        self::KIOS,
        self::HARGA,
    ];

    public const LABELS = [
        self::KIOS => 'Survey Kios',
        self::HARGA => 'Survey Harga',
    ];

    public static function label(?string $type): string
    {
        return self::LABELS[$type] ?? '-';
    }
}
