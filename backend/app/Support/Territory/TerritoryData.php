<?php

namespace App\Support\Territory;

use App\Models\NetworkProfile;
use App\Models\User;
use Illuminate\Support\Arr;

final class TerritoryData
{
    public const PROFILE_FIELDS = [
        'territory_province',
        'territory_city',
        'territory_district',
        'territory_subdistrict',
    ];

    public static function userAssignment(User $user): array
    {
        $assignment = self::primaryIncludeAssignment(self::userAssignments($user));

        if ($assignment !== null) {
            return $assignment;
        }

        return [
            'rule_type' => TerritoryRuleType::INCLUDE,
            'territory_scope' => $user->territory_scope,
            'territory_province' => self::clean($user->territory_province),
            'territory_city' => self::clean($user->territory_city),
            'territory_district' => self::clean($user->territory_district),
            'territory_subdistrict' => self::clean($user->territory_subdistrict),
        ];
    }

    public static function userAssignments(User $user): array
    {
        $rawAssignments = $user->territory_assignments;
        if (is_array($rawAssignments) && $rawAssignments !== []) {
            return array_values(array_filter(array_map(
                fn ($assignment) => is_array($assignment) ? self::normalizeAssignment($assignment) : null,
                $rawAssignments,
            )));
        }

        $fallback = self::normalizeAssignment([
            'territory_scope' => $user->territory_scope,
            'territory_province' => $user->territory_province,
            'territory_city' => $user->territory_city,
            'territory_district' => $user->territory_district,
            'territory_subdistrict' => $user->territory_subdistrict,
        ]);

        return self::isValidAssignment($fallback) ? [$fallback] : [];
    }

    public static function profileTerritory(NetworkProfile $profile): array
    {
        return [
            'territory_province' => self::clean($profile->territory_province),
            'territory_city' => self::clean($profile->territory_city),
            'territory_district' => self::clean($profile->territory_district),
            'territory_subdistrict' => self::clean($profile->territory_subdistrict),
        ];
    }

    public static function payloadTerritory(array $payload): array
    {
        return [
            'territory_province' => self::clean(Arr::get($payload, 'territory_province')),
            'territory_city' => self::clean(Arr::get($payload, 'territory_city')),
            'territory_district' => self::clean(Arr::get($payload, 'territory_district')),
            'territory_subdistrict' => self::clean(Arr::get($payload, 'territory_subdistrict')),
        ];
    }

    public static function syncAssignmentPayload(array $payload): array
    {
        $assignments = self::payloadAssignments($payload);
        $assignment = self::primaryIncludeAssignment($assignments) ?? [
            'rule_type' => TerritoryRuleType::INCLUDE,
            'territory_scope' => null,
            'territory_province' => null,
            'territory_city' => null,
            'territory_district' => null,
            'territory_subdistrict' => null,
        ];

        $payload['territory_province'] = $assignment['territory_province'];
        $payload['territory_city'] = $assignment['territory_city'];
        $payload['territory_district'] = $assignment['territory_district'];
        $payload['territory_subdistrict'] = $assignment['territory_subdistrict'];
        $payload['territory_scope'] = $assignment['territory_scope'];
        $payload['territory_assignments'] = $assignments;
        $payload['area_name'] = self::displayAssignmentsLabel($assignments);

        return $payload;
    }

    public static function assignmentsFromPayload(array $payload): array
    {
        $province = self::clean(Arr::get($payload, 'territory_province'));
        $city = self::clean(Arr::get($payload, 'territory_city'));
        $districts = array_values(array_filter(array_map(
            fn ($value) => self::clean(is_scalar($value) ? (string) $value : null),
            Arr::wrap(Arr::get($payload, 'territory_districts')),
        )));
        $subdistricts = array_values(array_filter(array_map(
            fn ($value) => self::clean(is_scalar($value) ? (string) $value : null),
            Arr::wrap(Arr::get($payload, 'territory_subdistricts')),
        )));

        if ($subdistricts !== [] && count($districts) === 1) {
            return array_values(array_filter(array_map(
                fn (string $subdistrict) => self::normalizeAssignment([
                    'territory_scope' => TerritoryScope::SUBDISTRICT,
                    'territory_province' => $province,
                    'territory_city' => $city,
                    'territory_district' => $districts[0],
                    'territory_subdistrict' => $subdistrict,
                ]),
                $subdistricts,
            )));
        }

        if ($districts !== []) {
            return array_values(array_filter(array_map(
                fn (string $district) => self::normalizeAssignment([
                    'territory_scope' => TerritoryScope::DISTRICT,
                    'territory_province' => $province,
                    'territory_city' => $city,
                    'territory_district' => $district,
                ]),
                $districts,
            )));
        }

        if ($city !== null) {
            return [self::normalizeAssignment([
                'territory_scope' => TerritoryScope::CITY,
                'territory_province' => $province,
                'territory_city' => $city,
            ])];
        }

        if ($province !== null) {
            return [self::normalizeAssignment([
                'territory_scope' => TerritoryScope::PROVINCE,
                'territory_province' => $province,
            ])];
        }

        return [];
    }

    public static function rulesFromPayloadArray(array $rules): array
    {
        $normalized = [];

        foreach ($rules as $rule) {
            if (! is_array($rule)) {
                continue;
            }

            $normalizedRule = self::normalizeAssignment($rule);
            if (self::isValidAssignment($normalizedRule)) {
                $normalized[self::assignmentFingerprint($normalizedRule)] = $normalizedRule;
            }
        }

        return array_values($normalized);
    }

    public static function displayLabel(array $territory): ?string
    {
        if (Arr::get($territory, 'territory_scope') === TerritoryScope::ALL_AREAS) {
            return 'Semua provinsi';
        }

        foreach ([
            Arr::get($territory, 'territory_subdistrict'),
            Arr::get($territory, 'territory_district'),
            Arr::get($territory, 'territory_city'),
            Arr::get($territory, 'territory_province'),
        ] as $value) {
            $clean = self::clean($value);
            if ($clean !== null) {
                return $clean;
            }
        }

        return null;
    }

    public static function scopedField(?string $scope): ?string
    {
        return match ($scope) {
            TerritoryScope::ALL_AREAS => null,
            TerritoryScope::PROVINCE => 'territory_province',
            TerritoryScope::CITY => 'territory_city',
            TerritoryScope::DISTRICT => 'territory_district',
            TerritoryScope::SUBDISTRICT => 'territory_subdistrict',
            default => null,
        };
    }

    public static function hasStructuredTerritory(array $territory): bool
    {
        foreach (self::PROFILE_FIELDS as $field) {
            if (filled(Arr::get($territory, $field))) {
                return true;
            }
        }

        return false;
    }

    public static function isAssigned(User $user): bool
    {
        return self::includeAssignments(self::userAssignments($user)) !== [];
    }

    public static function covers(User $user, array $territory): bool
    {
        $territory = self::payloadTerritory($territory);
        $assignments = self::userAssignments($user);

        return self::assignmentsCoverTerritory($assignments, $territory);
    }

    public static function coversProfile(User $user, NetworkProfile $profile): bool
    {
        $territory = self::profileTerritory($profile);
        if (self::hasStructuredTerritory($territory)) {
            return self::covers($user, $territory);
        }

        $assignments = self::userAssignments($user);

        foreach (self::excludeAssignments($assignments) as $assignment) {
            if (($assignment['territory_scope'] ?? null) === TerritoryScope::ALL_AREAS) {
                return false;
            }

            $scopeField = self::scopedField($assignment['territory_scope'] ?? null);
            if ($scopeField === null) {
                continue;
            }

            if (self::matchesValue(Arr::get($assignment, $scopeField), $profile->area_name)) {
                return false;
            }
        }

        foreach (self::includeAssignments($assignments) as $assignment) {
            if (($assignment['territory_scope'] ?? null) === TerritoryScope::ALL_AREAS) {
                return true;
            }

            $scopeField = self::scopedField($assignment['territory_scope'] ?? null);
            if ($scopeField === null) {
                continue;
            }

            if (self::matchesValue(Arr::get($assignment, $scopeField), $profile->area_name)) {
                return true;
            }
        }

        return false;
    }

    public static function messageForOutsideArea(string $profileType): string
    {
        $label = $profileType === 'mitra' ? 'Mitra ini' : 'UKM ini';

        return $label . ' diluar area kerja anda.';
    }

    public static function assignmentHint(User $user): string
    {
        $assignments = self::userAssignments($user);
        $scope = self::primaryIncludeAssignment($assignments)['territory_scope'] ?? $user->territory_scope;
        $label = self::displayAssignmentsLabel($assignments) ?? 'wilayah yang belum diatur HR';

        return match ($scope) {
            TerritoryScope::ALL_AREAS => 'Area kerja user mencakup semua provinsi.',
            TerritoryScope::PROVINCE => 'Area kerja user berada di level provinsi: ' . $label . '.',
            TerritoryScope::CITY => 'Area kerja user berada di level kota/kabupaten: ' . $label . '.',
            TerritoryScope::DISTRICT => 'Area kerja user berada di level kecamatan: ' . $label . '.',
            TerritoryScope::SUBDISTRICT => 'Area kerja user berada di level kelurahan: ' . $label . '.',
            default => 'Area kerja user belum diatur oleh HR.',
        };
    }

    private static function matchesValue(?string $left, ?string $right): bool
    {
        return self::normalize($left) !== null
            && self::normalize($left) === self::normalize($right);
    }

    public static function includeAssignments(array $assignments): array
    {
        return array_values(array_filter(
            $assignments,
            fn (array $assignment) => ($assignment['rule_type'] ?? TerritoryRuleType::INCLUDE) === TerritoryRuleType::INCLUDE,
        ));
    }

    public static function excludeAssignments(array $assignments): array
    {
        return array_values(array_filter(
            $assignments,
            fn (array $assignment) => ($assignment['rule_type'] ?? TerritoryRuleType::INCLUDE) === TerritoryRuleType::EXCLUDE,
        ));
    }

    public static function assignmentsCoverTerritory(array $assignments, array $territory): bool
    {
        $includes = self::includeAssignments($assignments);
        if ($includes === []) {
            return false;
        }

        $matchesInclude = false;
        foreach ($includes as $assignment) {
            if (self::assignmentCoversTerritory($assignment, $territory)) {
                $matchesInclude = true;
                break;
            }
        }

        if (! $matchesInclude) {
            return false;
        }

        foreach (self::excludeAssignments($assignments) as $assignment) {
            if (self::assignmentCoversTerritory($assignment, $territory)) {
                return false;
            }
        }

        return true;
    }

    private static function assignmentCoversTerritory(array $assignment, array $territory): bool
    {
        $scope = Arr::get($assignment, 'territory_scope');

        if (! in_array($scope, TerritoryScope::ALL, true)) {
            return false;
        }

        return match ($scope) {
            TerritoryScope::ALL_AREAS => true,
            TerritoryScope::PROVINCE => self::matchesValue(
                $assignment['territory_province'],
                $territory['territory_province'],
            ),
            TerritoryScope::CITY => self::matchesValue($assignment['territory_city'], $territory['territory_city'])
                && self::optionalParentMatches($assignment['territory_province'], $territory['territory_province']),
            TerritoryScope::DISTRICT => self::matchesValue(
                $assignment['territory_district'],
                $territory['territory_district'],
            ) && self::optionalParentMatches($assignment['territory_city'], $territory['territory_city'])
                && self::optionalParentMatches($assignment['territory_province'], $territory['territory_province']),
            TerritoryScope::SUBDISTRICT => self::matchesValue(
                $assignment['territory_subdistrict'],
                $territory['territory_subdistrict'],
            ) && self::optionalParentMatches($assignment['territory_district'], $territory['territory_district'])
                && self::optionalParentMatches($assignment['territory_city'], $territory['territory_city'])
                && self::optionalParentMatches($assignment['territory_province'], $territory['territory_province']),
            default => false,
        };
    }

    private static function normalizeAssignment(array $assignment): array
    {
        $province = self::clean(Arr::get($assignment, 'territory_province'));
        $city = self::clean(Arr::get($assignment, 'territory_city'));
        $district = self::clean(Arr::get($assignment, 'territory_district'));
        $subdistrict = self::clean(Arr::get($assignment, 'territory_subdistrict'));
        $scope = Arr::get($assignment, 'territory_scope');

        if (! in_array($scope, TerritoryScope::ALL, true)) {
            $scope = self::resolveScope($province, $city, $district, $subdistrict);
        }

        if ($scope === TerritoryScope::ALL_AREAS) {
            $province = null;
            $city = null;
            $district = null;
            $subdistrict = null;
        }

        return [
            'rule_type' => in_array(Arr::get($assignment, 'rule_type'), TerritoryRuleType::ALL, true)
                ? Arr::get($assignment, 'rule_type')
                : TerritoryRuleType::INCLUDE,
            'territory_scope' => $scope,
            'territory_province' => $province,
            'territory_city' => $city,
            'territory_district' => $district,
            'territory_subdistrict' => $subdistrict,
        ];
    }

    private static function isValidAssignment(array $assignment): bool
    {
        $scope = Arr::get($assignment, 'territory_scope');

        if (! in_array($scope, TerritoryScope::ALL, true)) {
            return false;
        }

        if ($scope === TerritoryScope::ALL_AREAS) {
            return true;
        }

        $field = self::scopedField($scope);

        return $field !== null && filled(Arr::get($assignment, $field));
    }

    public static function displayAssignmentsLabel(array $assignments): ?string
    {
        $includes = self::includeAssignments($assignments);
        if ($includes === []) {
            return null;
        }

        $labels = array_values(array_unique(array_filter(array_map(
            fn (array $assignment) => self::displayLabel($assignment),
            $includes,
        ))));

        if ($labels === []) {
            return null;
        }

        $summary = count($labels) === 1
            ? $labels[0]
            : $labels[0] . ' +' . (count($labels) - 1) . ' wilayah';

        $excludes = self::excludeAssignments($assignments);
        $excludeLabels = array_values(array_unique(array_filter(array_map(
            fn (array $assignment) => self::displayLabel($assignment),
            $excludes,
        ))));

        if ($excludeLabels === []) {
            return $summary;
        }

        $excludeSummary = count($excludeLabels) === 1
            ? $excludeLabels[0]
            : $excludeLabels[0] . ' +' . (count($excludeLabels) - 1) . ' wilayah';

        return $summary . ' (kecuali ' . $excludeSummary . ')';
    }

    private static function payloadAssignments(array $payload): array
    {
        $rawAssignments = Arr::get($payload, 'territory_assignments');
        if (is_array($rawAssignments) && $rawAssignments !== []) {
            return self::rulesFromPayloadArray($rawAssignments);
        }

        return self::assignmentsFromPayload($payload);
    }

    private static function primaryIncludeAssignment(array $assignments): ?array
    {
        $includes = self::includeAssignments($assignments);

        return $includes[0] ?? null;
    }

    private static function resolveScope(
        ?string $province,
        ?string $city,
        ?string $district,
        ?string $subdistrict,
    ): ?string {
        if ($subdistrict !== null) {
            return TerritoryScope::SUBDISTRICT;
        }

        if ($district !== null) {
            return TerritoryScope::DISTRICT;
        }

        if ($city !== null) {
            return TerritoryScope::CITY;
        }

        if ($province !== null) {
            return TerritoryScope::PROVINCE;
        }

        return null;
    }

    private static function assignmentFingerprint(array $assignment): string
    {
        return implode('|', [
            $assignment['rule_type'] ?? TerritoryRuleType::INCLUDE,
            $assignment['territory_scope'] ?? '',
            $assignment['territory_province'] ?? '',
            $assignment['territory_city'] ?? '',
            $assignment['territory_district'] ?? '',
            $assignment['territory_subdistrict'] ?? '',
        ]);
    }

    private static function optionalParentMatches(?string $left, ?string $right): bool
    {
        if (blank($left)) {
            return true;
        }

        return self::matchesValue($left, $right);
    }

    private static function normalize(?string $value): ?string
    {
        $clean = self::clean($value);

        if ($clean === null) {
            return null;
        }

        return mb_strtolower(preg_replace('/\s+/', ' ', $clean));
    }

    private static function clean(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '' || $trimmed === '-' || mb_strtolower($trimmed) === 'null') {
            return null;
        }

        return $trimmed;
    }
}
