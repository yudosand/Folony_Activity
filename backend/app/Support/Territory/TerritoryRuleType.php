<?php

namespace App\Support\Territory;

final class TerritoryRuleType
{
    public const INCLUDE = 'include';
    public const EXCLUDE = 'exclude';

    public const ALL = [
        self::INCLUDE,
        self::EXCLUDE,
    ];
}
