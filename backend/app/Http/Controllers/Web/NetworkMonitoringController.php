<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\NetworkFollowUp;
use App\Models\NetworkProfile;
use App\Models\User;
use App\Services\Admin\AdminExportService;
use App\Services\NetworkService;
use App\Support\Workflow\UserRole;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class NetworkMonitoringController extends Controller
{
    public function index(Request $request, AdminExportService $exportService): View|StreamedResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string'],
            'owner_role' => ['nullable', 'string'],
            'type' => ['nullable', 'string'],
            'status' => ['nullable', 'string'],
            'area_name' => ['nullable', 'string'],
            'date_from' => ['nullable', 'date'],
            'date_until' => ['nullable', 'date'],
        ]);

        $query = NetworkProfile::query()
            ->with('followUps')
            ->when($filters['search'] ?? null, function ($builder, string $search) {
                $builder->where(function ($query) use ($search) {
                    $query->where('name', 'like', '%' . $search . '%')
                        ->orWhere('owner_name', 'like', '%' . $search . '%')
                        ->orWhere('address', 'like', '%' . $search . '%');
                });
            })
            ->when($filters['owner_role'] ?? null, fn ($builder, string $ownerRole) => $builder->where('owner_role', $ownerRole))
            ->when($filters['type'] ?? null, fn ($builder, string $type) => $builder->where('type', $type))
            ->when($filters['status'] ?? null, fn ($builder, string $status) => $builder->where('status', $status))
            ->when($filters['area_name'] ?? null, fn ($builder, string $areaName) => $builder->where('area_name', 'like', '%' . $areaName . '%'))
            ->when($filters['date_from'] ?? null, fn ($builder, string $dateFrom) => $builder->whereDate('updated_at', '>=', $dateFrom))
            ->when($filters['date_until'] ?? null, fn ($builder, string $dateUntil) => $builder->whereDate('updated_at', '<=', $dateUntil))
            ->latest('updated_at');

        $summary = $this->buildSummary(clone $query);

        if ($request->string('export')->value() === 'csv') {
            $rows = $query->get()->map(function (NetworkProfile $profile): array {
                $latestFollowUp = $profile->followUps->sortByDesc('created_at')->first();

                return [
                    $profile->id,
                    $profile->type,
                    $profile->name,
                    $profile->owner_name,
                    UserRole::label($profile->owner_role),
                    $profile->area_name,
                    $profile->status,
                    $profile->business_type,
                    $profile->address,
                    $latestFollowUp?->title,
                    optional($latestFollowUp?->created_at)->format('Y-m-d H:i'),
                ];
            });

            return $exportService->streamCsv(
                'network-monitoring.csv',
                ['ID', 'Type', 'Nama', 'Owner', 'Owner Role', 'Area', 'Status', 'Bidang Usaha', 'Alamat', 'Follow-up Terakhir', 'Waktu Follow-up'],
                $rows,
            );
        }

        $activityRecap = $this->buildActivityRecap($filters);

        return view('admin.network.index', [
            'profiles' => $query->paginate(20)->withQueryString(),
            'activityRecap' => $activityRecap,
            'summary' => $summary,
            'filters' => $filters,
            'ownerRoles' => [
                UserRole::FGG => UserRole::label(UserRole::FGG),
                UserRole::AREA_MANAGER => UserRole::label(UserRole::AREA_MANAGER),
            ],
            'types' => [
                'ukm' => 'UKM',
                'mitra' => 'Mitra',
            ],
            'statuses' => ['draft', 'followUp', 'completed', 'archived'],
        ]);
    }

    public function show(NetworkProfile $profile): View
    {
        $profile->load(['owner', 'followUps']);

        return view('admin.network.show', [
            'profile' => $profile,
            'latestFollowUp' => $profile->followUps->sortByDesc('created_at')->first(),
        ]);
    }

    public function storeManual(Request $request, NetworkService $networkService): RedirectResponse
    {
        $payload = $request->validate([
            'type' => ['required', 'in:ukm,mitra'],
            'name' => ['required', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:500'],
            'business_type' => ['required', 'string', 'max:255'],
            'phone_number' => ['required', 'string', 'max:32'],
            'status' => ['required', 'in:draft,followUp,completed,archived'],
            'territory_province' => ['required', 'string', 'max:255'],
            'territory_city' => ['required', 'string', 'max:255'],
            'territory_district' => ['required', 'string', 'max:255'],
            'territory_subdistrict' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $networkService->create(
            $payload + [
                'id' => (string) \Illuminate\Support\Str::uuid(),
                'reference_name' => 'Input manual HR',
                'personality_metrics' => [],
                'documents' => [],
            ],
            $request->user(),
        );

        return redirect()
            ->route('admin.network.index')
            ->with('status', 'Data jaringan manual berhasil ditambahkan.');
    }

    /**
     * @return array{total:int,ukm:int,mitra:int,needs_follow_up:int,fgg_owned:int,area_owned:int}
     */
    private function buildSummary(Builder $query): array
    {
        return [
            'total' => (clone $query)->count(),
            'ukm' => (clone $query)->where('type', 'ukm')->count(),
            'mitra' => (clone $query)->where('type', 'mitra')->count(),
            'needs_follow_up' => (clone $query)->where('status', 'followUp')->count(),
            'fgg_owned' => (clone $query)->where('owner_role', UserRole::FGG)->count(),
            'area_owned' => (clone $query)->where('owner_role', UserRole::AREA_MANAGER)->count(),
        ];
    }

    private function buildActivityRecap(array $filters): ?array
    {
        if (empty($filters['date_from']) || empty($filters['date_until'])) {
            return null;
        }

        $owner = $this->resolveOwnerFromSearch($filters['search'] ?? null);
        if (! $owner) {
            return null;
        }

        $dateFrom = Carbon::parse($filters['date_from'])->startOfDay();
        $dateUntil = Carbon::parse($filters['date_until'])->endOfDay();
        if ($dateUntil->lessThan($dateFrom)) {
            [$dateFrom, $dateUntil] = [$dateUntil->copy()->startOfDay(), $dateFrom->copy()->endOfDay()];
        }

        $createdProfiles = NetworkProfile::query()
            ->where('owner_id', $owner->id)
            ->whereBetween('created_at', [$dateFrom, $dateUntil])
            ->orderBy('created_at')
            ->get();

        $followUps = NetworkFollowUp::query()
            ->with('profile')
            ->where('actor_id', $owner->id)
            ->whereBetween('created_at', [$dateFrom, $dateUntil])
            ->orderBy('created_at')
            ->get();

        $entries = [];

        foreach ($createdProfiles as $profile) {
            $entries[] = [
                'occurred_at' => $profile->created_at,
                'date_label' => optional($profile->created_at)->format('d M Y H:i'),
                'activity_label' => $profile->type === 'mitra' ? 'Mitra Baru' : 'UKM Baru',
                'profile_name' => $profile->name,
                'profile_type' => strtoupper((string) $profile->type),
                'status' => $profile->status,
                'area_name' => $profile->area_name,
                'detail' => $profile->address ?: ($profile->note ?: '-'),
            ];
        }

        foreach ($followUps as $followUp) {
            $profile = $followUp->profile;
            $entries[] = [
                'occurred_at' => $followUp->created_at,
                'date_label' => optional($followUp->created_at)->format('d M Y H:i'),
                'activity_label' => ($profile?->type === 'mitra') ? 'Kunjungan Mitra' : 'Kunjungan UKM',
                'profile_name' => $profile?->name ?? $followUp->network_profile_id,
                'profile_type' => strtoupper((string) ($profile?->type ?? '-')),
                'status' => $profile?->status ?? '-',
                'area_name' => $profile?->area_name ?? '-',
                'detail' => trim($followUp->title . ($followUp->note ? ' - ' . $followUp->note : '')),
            ];
        }

        usort($entries, function (array $left, array $right): int {
            $leftAt = $left['occurred_at'];
            $rightAt = $right['occurred_at'];

            return $leftAt <=> $rightAt;
        });

        return [
            'owner' => $owner,
            'date_from' => $dateFrom->copy()->startOfDay(),
            'date_until' => $dateUntil->copy()->startOfDay(),
            'entries' => $entries,
            'summary' => [
                'new_ukm' => $createdProfiles->where('type', 'ukm')->count(),
                'new_mitra' => $createdProfiles->where('type', 'mitra')->count(),
                'follow_up_count' => $followUps->count(),
                'total_activities' => count($entries),
            ],
        ];
    }

    private function resolveOwnerFromSearch(?string $search): ?User
    {
        $keyword = trim((string) $search);
        if ($keyword === '') {
            return null;
        }

        $baseQuery = User::query()
            ->whereIn('role', [UserRole::FGG, UserRole::AREA_MANAGER]);

        $exact = (clone $baseQuery)
            ->where(function ($query) use ($keyword) {
                $query->where('full_name', $keyword)
                    ->orWhere('employee_code', $keyword);
            })
            ->first();

        if ($exact) {
            return $exact;
        }

        $matched = (clone $baseQuery)
            ->where(function ($query) use ($keyword) {
                $query->where('full_name', 'like', '%' . $keyword . '%')
                    ->orWhere('employee_code', 'like', '%' . $keyword . '%');
            })
            ->limit(2)
            ->get();

        return $matched->count() === 1 ? $matched->first() : null;
    }
}
