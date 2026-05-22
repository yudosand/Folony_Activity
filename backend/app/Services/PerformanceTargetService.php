<?php

namespace App\Services;

use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\PerformanceTarget;
use App\Models\User;
use App\Support\Performance\PerformanceMetric;
use App\Support\Workflow\UserRole;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;

class PerformanceTargetService
{
    public function __construct(
        private readonly NetworkService $networkService,
    ) {
    }

    public function summaryForUser(User $user, ?string $periodMonth = null): array
    {
        [$start, $end, $normalizedPeriodMonth] = $this->resolvePeriod($periodMonth);
        $targets = $this->activeTargetsForUser($user);

        $metrics = [];
        foreach (PerformanceMetric::forRole($user->role) as $metricKey) {
            $definition = PerformanceMetric::definition($metricKey);
            $actualValue = $this->actualValue($user, $metricKey, $start, $end);
            $targetValue = (int) ($targets[$metricKey]?->target_value ?? 0);
            $remainingValue = max($targetValue - $actualValue, 0);
            $progressRatio = $targetValue > 0
                ? min($actualValue / $targetValue, 1)
                : 0;

            $metrics[] = [
                'key' => $metricKey,
                'label' => $definition['label'],
                'description' => $definition['description'],
                'unit' => $definition['unit'],
                'actual_value' => $actualValue,
                'target_value' => $targetValue,
                'remaining_value' => $remainingValue,
                'progress_ratio' => round($progressRatio, 4),
                'display_value' => $actualValue . '/' . $targetValue,
            ];
        }

        return [
            'period_month' => $normalizedPeriodMonth,
            'period_label' => $start->format('m/Y'),
            'role' => $user->role,
            'metrics' => $metrics,
        ];
    }

    public function upsertTargets(
        User $employee,
        User $actor,
        array $targetValues,
    ): void {
        $currentYear = (int) now()->format('Y');
        $currentMonth = (int) now()->format('m');
        $allowedMetrics = PerformanceMetric::forRole($employee->role);

        foreach ($allowedMetrics as $metricKey) {
            $rawValue = $targetValues[$metricKey] ?? null;

            if ($rawValue === null || $rawValue === '') {
                $activeTarget = $this->activeTargetsForUser($employee)->get($metricKey);
                $activeTarget?->delete();
                continue;
            }

            $activeTarget = $this->activeTargetsForUser($employee)->get($metricKey);
            if ($activeTarget !== null) {
                $activeTarget->update([
                    'target_value' => (int) $rawValue,
                    'created_by' => $actor->id,
                    'period_year' => $currentYear,
                    'period_month' => $currentMonth,
                ]);
                continue;
            }

            PerformanceTarget::query()->create([
                'user_id' => $employee->id,
                'metric_key' => $metricKey,
                'period_year' => $currentYear,
                'period_month' => $currentMonth,
                'target_value' => (int) $rawValue,
                'created_by' => $actor->id,
            ]);
        }
    }

    public function targetValuesForUser(User $user): array
    {
        return $this->activeTargetsForUser($user)
            ->pluck('target_value', 'metric_key')
            ->map(fn ($value) => (int) $value)
            ->all();
    }

    public function metricDefinitionsForRole(string $role): array
    {
        return array_map(
            static fn (string $metricKey) => [
                'key' => $metricKey,
                ...PerformanceMetric::definition($metricKey),
            ],
            PerformanceMetric::forRole($role),
        );
    }

    private function activeTargetsForUser(User $user)
    {
        return PerformanceTarget::query()
            ->where('user_id', $user->id)
            ->orderByDesc('period_year')
            ->orderByDesc('period_month')
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->get()
            ->unique('metric_key')
            ->keyBy('metric_key');
    }

    private function actualValue(
        User $user,
        string $metricKey,
        Carbon $start,
        Carbon $end,
    ): int {
        return match ($metricKey) {
            PerformanceMetric::FGG_NEW_UKM => $this->countOwnedProfiles(
                $user,
                type: 'ukm',
                start: $start,
                end: $end,
            ),
            PerformanceMetric::FGG_FOLLOW_UP_VISIT => $this->countFollowUpsByActor(
                $user,
                start: $start,
                end: $end,
            ),
            PerformanceMetric::AREA_MANAGER_TEAM_NEW_UKM => $this->countAreaManagerTeamNewUkm(
                $user,
                start: $start,
                end: $end,
            ),
            PerformanceMetric::AREA_MANAGER_NEW_MITRA => $this->countOwnedProfiles(
                $user,
                type: 'mitra',
                start: $start,
                end: $end,
            ),
            PerformanceMetric::AREA_MANAGER_TEAM_FOLLOW_UP_VISIT => $this->countAreaManagerTeamVisits(
                $user,
                start: $start,
                end: $end,
            ),
            default => 0,
        };
    }

    private function countOwnedProfiles(
        User $user,
        string $type,
        Carbon $start,
        Carbon $end,
    ): int {
        return NetworkProfile::query()
            ->where('owner_id', $user->id)
            ->where('type', $type)
            ->whereBetween('created_at', [$start, $end])
            ->count();
    }

    private function countFollowUpsByActor(
        User $user,
        Carbon $start,
        Carbon $end,
    ): int {
        return NetworkFollowUp::query()
            ->where('actor_id', $user->id)
            ->whereBetween('created_at', [$start, $end])
            ->count();
    }

    private function countAreaManagerTeamNewUkm(
        User $user,
        Carbon $start,
        Carbon $end,
    ): int {
        $teamUkm = $this->networkService
            ->queryTeamUkm($user)
            ->whereBetween('created_at', [$start, $end])
            ->count();

        $ownUkm = $this->countOwnedProfiles($user, 'ukm', $start, $end);

        return $teamUkm + $ownUkm;
    }

    private function countAreaManagerTeamVisits(
        User $user,
        Carbon $start,
        Carbon $end,
    ): int {
        return NetworkFollowUp::query()
            ->whereBetween('created_at', [$start, $end])
            ->whereHas('actor', fn (Builder $builder) => $builder->where('role', UserRole::FGG))
            ->whereHas('profile', function (Builder $builder) use ($user): void {
                $this->networkService->applyTerritoryScopeToQuery($builder, $user);
            })
            ->count();
    }

    private function resolvePeriod(?string $periodMonth): array
    {
        if (is_string($periodMonth) && preg_match('/^\d{4}-\d{2}$/', $periodMonth) === 1) {
            $start = Carbon::createFromFormat('Y-m', $periodMonth)->startOfMonth();
        } else {
            $start = now()->startOfMonth();
        }

        return [$start, $start->copy()->endOfMonth(), $start->format('Y-m')];
    }
}
