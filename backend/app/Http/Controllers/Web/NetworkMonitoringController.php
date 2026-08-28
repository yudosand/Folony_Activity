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
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
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

    public function activities(Request $request): View
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string'],
            'owner_role' => ['nullable', 'string'],
            'date_from' => ['nullable', 'date'],
            'date_until' => ['nullable', 'date'],
        ]);

        $roles = [UserRole::FGG, UserRole::AREA_MANAGER];
        $dateFrom = ! empty($filters['date_from']) ? Carbon::parse($filters['date_from'])->startOfDay() : null;
        $dateUntil = ! empty($filters['date_until']) ? Carbon::parse($filters['date_until'])->endOfDay() : null;
        if ($dateFrom && $dateUntil && $dateUntil->lessThan($dateFrom)) {
            [$dateFrom, $dateUntil] = [$dateUntil->copy()->startOfDay(), $dateFrom->copy()->endOfDay()];
        }

        $createdProfiles = NetworkProfile::query()
            ->whereIn('owner_role', $roles)
            ->when($filters['owner_role'] ?? null, fn ($query, string $role) => $query->where('owner_role', $role))
            ->when($dateFrom, fn ($query) => $query->where('created_at', '>=', $dateFrom))
            ->when($dateUntil, fn ($query) => $query->where('created_at', '<=', $dateUntil))
            ->when($filters['search'] ?? null, function ($query, string $search): void {
                $query->where(function ($builder) use ($search): void {
                    $builder->where('owner_name', 'like', '%' . $search . '%')
                        ->orWhere('name', 'like', '%' . $search . '%')
                        ->orWhere('address', 'like', '%' . $search . '%')
                        ->orWhere('area_name', 'like', '%' . $search . '%');
                });
            })
            ->latest('created_at')
            ->limit(500)
            ->get()
            ->map(fn (NetworkProfile $profile): array => [
                'occurred_at' => $profile->created_at,
                'actor_name' => $profile->owner_name,
                'actor_role' => UserRole::label($profile->owner_role),
                'activity_label' => $profile->type === 'mitra' ? 'Tambah MITRA Baru' : 'Tambah UKM Baru',
                'profile_name' => $profile->name,
                'profile_type' => strtoupper((string) $profile->type),
                'address' => $profile->address,
                'latitude' => $profile->latitude,
                'longitude' => $profile->longitude,
                'duration_label' => null,
                'detail' => $profile->business_type ?: '-',
                'photo' => $profile->photo_attachment,
            ]);

        $visits = NetworkFollowUp::query()
            ->with(['profile', 'actor'])
            ->whereHas('actor', fn ($query) => $query->whereIn('role', $roles))
            ->when($filters['owner_role'] ?? null, fn ($query, string $role) => $query->whereHas('actor', fn ($actor) => $actor->where('role', $role)))
            ->when($dateFrom, fn ($query) => $query->where('created_at', '>=', $dateFrom))
            ->when($dateUntil, fn ($query) => $query->where('created_at', '<=', $dateUntil))
            ->when($filters['search'] ?? null, function ($query, string $search): void {
                $query->where(function ($builder) use ($search): void {
                    $builder->where('actor_name', 'like', '%' . $search . '%')
                        ->orWhere('title', 'like', '%' . $search . '%')
                        ->orWhere('note', 'like', '%' . $search . '%')
                        ->orWhereHas('profile', function ($profile) use ($search): void {
                            $profile->where('name', 'like', '%' . $search . '%')
                                ->orWhere('address', 'like', '%' . $search . '%')
                                ->orWhere('area_name', 'like', '%' . $search . '%');
                        });
                });
            })
            ->latest('created_at')
            ->limit(500)
            ->get()
            ->map(function (NetworkFollowUp $followUp): array {
                $profile = $followUp->profile;

                return [
                    'occurred_at' => $followUp->created_at,
                    'actor_name' => $followUp->actor_name,
                    'actor_role' => UserRole::label((string) ($followUp->actor?->role ?? '')),
                    'activity_label' => ($profile?->type === 'mitra') ? 'Kunjungan Mitra' : 'Kunjungan UKM',
                    'profile_name' => $profile?->name ?? $followUp->network_profile_id,
                    'profile_type' => strtoupper((string) ($profile?->type ?? '-')),
                    'address' => $profile?->address ?? '-',
                    'latitude' => $profile?->latitude,
                    'longitude' => $profile?->longitude,
                    'duration_label' => $this->formatDuration($followUp->visit_duration_seconds),
                    'detail' => trim($followUp->title . ($followUp->note ? ' - ' . $followUp->note : '')),
                    'photo' => $followUp->photo_attachment,
                ];
            });

        $activities = $createdProfiles
            ->concat($visits)
            ->sortByDesc(fn (array $activity) => optional($activity['occurred_at'])->timestamp ?? 0)
            ->values();

        $page = LengthAwarePaginator::resolveCurrentPage();
        $perPage = 30;
        $paginated = new LengthAwarePaginator(
            $activities->forPage($page, $perPage)->values(),
            $activities->count(),
            $perPage,
            $page,
            [
                'path' => $request->url(),
                'query' => $request->query(),
            ],
        );

        return view('admin.network.activities', [
            'activities' => $paginated,
            'filters' => $filters,
            'ownerRoles' => [
                UserRole::FGG => UserRole::label(UserRole::FGG),
                UserRole::AREA_MANAGER => UserRole::label(UserRole::AREA_MANAGER),
            ],
            'summary' => [
                'total' => $activities->count(),
                'created' => $createdProfiles->count(),
                'visits' => $visits->count(),
            ],
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

    public function import(Request $request, NetworkService $networkService): RedirectResponse
    {
        $payload = $request->validate([
            'sheet_url' => ['nullable', 'string', 'max:1000'],
            'csv_file' => ['nullable', 'file', 'max:5120'],
            'default_type' => ['required', 'in:ukm,mitra'],
            'default_status' => ['required', 'in:draft,followUp,completed,archived'],
        ]);

        if (! $request->hasFile('csv_file') && trim((string) ($payload['sheet_url'] ?? '')) === '') {
            return back()
                ->withInput()
                ->withErrors(['sheet_url' => 'Masukkan link Google Sheet atau upload file CSV terlebih dahulu.']);
        }

        try {
            $csvContent = $this->readImportCsvContent($request, $payload);
            $this->assertCsvContent($csvContent);
        } catch (RequestException) {
            return back()
                ->withInput()
                ->withErrors(['sheet_url' => 'Google Sheet tidak bisa dibaca dari server. Pastikan link bisa diakses publik atau upload file CSV.']);
        } catch (\Throwable $exception) {
            return back()
                ->withInput()
                ->withErrors(['csv_file' => $exception->getMessage()]);
        }

        $rows = $this->parseCsvRows($csvContent);
        if ($rows === []) {
            return back()
                ->withInput()
                ->withErrors(['csv_file' => 'CSV kosong atau header tidak cocok. Pastikan ada kolom nama, latitude, dan longitude.']);
        }

        $created = 0;
        $updated = 0;
        $skipped = 0;
        $skippedReasons = [];

        foreach ($rows as $index => $row) {
            $rowNumber = $index + 2;
            $mapped = $this->mapImportRow($row, $payload);

            if ($mapped['name'] === '') {
                $skipped++;
                $skippedReasons[] = "Baris {$rowNumber}: nama kosong";
                continue;
            }

            if ($mapped['latitude'] === null || $mapped['longitude'] === null) {
                $skipped++;
                $skippedReasons[] = "Baris {$rowNumber}: latitude/longitude kosong atau tidak valid";
                continue;
            }

            $ownerName = $mapped['_owner_name'] ?? null;
            $sourceId = $mapped['_source_id'] ?? null;
            $existingProfile = $this->findImportProfile($mapped);
            unset($mapped['_owner_name'], $mapped['_source_id']);

            $profile = $networkService->create(
                $mapped + [
                    'id' => $existingProfile?->id ?? $this->importProfileId($sourceId),
                    'reference_name' => 'Input spreadsheet HR',
                    'personality_metrics' => [],
                    'documents' => [],
                ],
                $request->user(),
            );

            if (is_string($ownerName) && $ownerName !== '') {
                $profile->update([
                    'owner_name' => $ownerName,
                ]);
            }

            if ($existingProfile) {
                $updated++;
            } else {
                $created++;
            }
        }

        $message = "Import jaringan selesai. {$created} data baru masuk ke heatmap.";
        if ($updated > 0) {
            $message .= " {$updated} data diperbarui.";
        }
        if ($skipped > 0) {
            $message .= " {$skipped} baris dilewati.";
        }
        if ($skippedReasons !== []) {
            $message .= ' ' . implode('; ', array_slice($skippedReasons, 0, 5));
            if (count($skippedReasons) > 5) {
                $message .= '; dan ' . (count($skippedReasons) - 5) . ' lainnya';
            }
        }

        return redirect()
            ->route('admin.network.index')
            ->with('status', $message);
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

    private function formatDuration(?int $seconds): ?string
    {
        if ($seconds === null) {
            return null;
        }

        $hours = intdiv($seconds, 3600);
        $minutes = intdiv($seconds % 3600, 60);
        $remainingSeconds = $seconds % 60;

        $parts = [];
        if ($hours > 0) {
            $parts[] = $hours . 'j';
        }
        if ($minutes > 0) {
            $parts[] = $minutes . 'm';
        }
        if ($parts === []) {
            $parts[] = $remainingSeconds . 'd';
        }

        return implode(' ', $parts);
    }

    private function readImportCsvContent(Request $request, array $payload): string
    {
        if ($request->hasFile('csv_file')) {
            $content = file_get_contents($request->file('csv_file')->getRealPath());
            if ($content === false) {
                throw new \RuntimeException('File CSV tidak bisa dibaca.');
            }

            return $content;
        }

        $url = $this->normalizeSheetCsvUrl((string) $payload['sheet_url']);
        $response = Http::timeout(25)
            ->accept('text/csv, text/plain, */*')
            ->get($url)
            ->throw();

        return $response->body();
    }

    private function assertCsvContent(string $content): void
    {
        $preview = strtolower(ltrim(substr($content, 0, 500)));
        if (str_starts_with($preview, '<!doctype') || str_starts_with($preview, '<html') || str_contains($preview, '<body')) {
            throw new \RuntimeException('Link yang diimport tidak mengembalikan CSV. Pastikan Google Sheet bisa diakses publik atau upload file CSV.');
        }
    }

    private function normalizeSheetCsvUrl(string $url): string
    {
        $trimmed = trim($url);
        if (! str_contains($trimmed, 'docs.google.com/spreadsheets/d/')) {
            return $trimmed;
        }

        preg_match('#/spreadsheets/d/([^/]+)#', $trimmed, $matches);
        $sheetId = $matches[1] ?? null;
        if (! $sheetId) {
            return $trimmed;
        }

        $gid = '0';
        $query = parse_url($trimmed, PHP_URL_QUERY);
        if (is_string($query)) {
            parse_str($query, $params);
            $gid = (string) ($params['gid'] ?? $gid);
        }

        return "https://docs.google.com/spreadsheets/d/{$sheetId}/export?format=csv&gid={$gid}";
    }

    /**
     * @return list<array<string, string>>
     */
    private function parseCsvRows(string $csvContent): array
    {
        $handle = fopen('php://temp', 'r+');
        fwrite($handle, $csvContent);
        rewind($handle);

        $headers = null;
        $rows = [];

        while (($line = fgetcsv($handle)) !== false) {
            if ($headers === null) {
                $candidateHeaders = array_map(fn ($header) => $this->normalizeImportHeader((string) $header), $line);
                if (! $this->isImportHeaderCandidate($candidateHeaders)) {
                    continue;
                }

                $headers = $candidateHeaders;
                continue;
            }

            if ($this->isBlankCsvLine($line)) {
                continue;
            }

            $row = [];
            foreach ($headers as $index => $header) {
                if ($header === '') {
                    continue;
                }

                $row[$header] = trim((string) ($line[$index] ?? ''));
            }

            $rows[] = $row;
        }

        fclose($handle);

        if ($headers === null) {
            return [];
        }

        return $rows;
    }

    private function isImportHeaderCandidate(array $headers): bool
    {
        $knownHeaders = array_merge(...array_values($this->importHeaderAliases()));
        $matches = 0;

        foreach ($headers as $header) {
            if (in_array($header, $knownHeaders, true)) {
                $matches++;
            }
        }

        return $matches >= 3
            && $this->hasAnyImportHeader($headers, $this->importHeaderAliases()['name'])
            && (
                $this->hasAnyImportHeader($headers, $this->importHeaderAliases()['latitude'])
                || $this->hasAnyImportHeader($headers, $this->importHeaderAliases()['longitude'])
            );
    }

    private function hasAnyImportHeader(array $headers, array $aliases): bool
    {
        foreach ($aliases as $alias) {
            if (in_array($alias, $headers, true)) {
                return true;
            }
        }

        return false;
    }

    private function normalizeImportHeader(string $header): string
    {
        $normalized = strtolower(trim($header));
        $normalized = preg_replace('/^\xEF\xBB\xBF/', '', $normalized) ?? $normalized;
        $normalized = preg_replace('/[^a-z0-9]+/', '_', $normalized) ?? $normalized;

        return trim($normalized, '_');
    }

    private function isBlankCsvLine(array $line): bool
    {
        foreach ($line as $value) {
            if (trim((string) $value) !== '') {
                return false;
            }
        }

        return true;
    }

    private function mapImportRow(array $row, array $defaults): array
    {
        $aliases = $this->importHeaderAliases();
        $type = strtolower($this->pickImportValue($row, $aliases['type'], $defaults['default_type']));
        $status = $this->normalizeImportStatus($this->pickImportValue($row, $aliases['status'], $defaults['default_status']));
        $latitude = $this->parseCoordinate($this->pickImportValue($row, $aliases['latitude']));
        $longitude = $this->parseCoordinate($this->pickImportValue($row, $aliases['longitude']));
        $territory = $this->parseCombinedTerritory($this->pickImportValue($row, $aliases['combined_territory']));
        $photo = $this->mapImportPhoto($this->pickImportValue($row, $aliases['photo_url']));
        $sourceId = $this->pickImportValue($row, $aliases['source_id']);
        $csvOwnerName = $this->pickImportValue($row, $aliases['owner_name']);
        $businessOwnerName = $this->pickImportValue($row, $aliases['business_owner_name']);
        $note = $this->pickImportValue($row, $aliases['note']);
        $subdistrict = $this->pickImportValue($row, $aliases['subdistrict'], $territory['subdistrict'] ?? '-');
        if (str_contains($subdistrict, ' - ') && isset($territory['subdistrict'])) {
            $subdistrict = $territory['subdistrict'];
        }

        $mapped = [
            'type' => str_contains($type, 'mitra') ? 'mitra' : 'ukm',
            'name' => $this->pickImportValue($row, $aliases['name']),
            'address' => $this->pickImportValue($row, $aliases['address'], '-'),
            'business_type' => $this->pickImportValue($row, $aliases['business_type'], '-'),
            'phone_number' => $this->pickImportValue($row, $aliases['phone_number'], '-'),
            'status' => $status,
            'territory_province' => $this->pickImportValue($row, $aliases['province'], $territory['province'] ?? '-'),
            'territory_city' => $this->pickImportValue($row, $aliases['city'], $territory['city'] ?? '-'),
            'territory_district' => $this->pickImportValue($row, $aliases['district'], $territory['district'] ?? '-'),
            'territory_subdistrict' => $subdistrict,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'note' => $this->mergeImportNotes($note, [
                'ID CSV' => $sourceId,
                'User CSV' => $csvOwnerName,
                'Pemilik' => $businessOwnerName,
            ]),
            '_source_id' => $sourceId,
            '_owner_name' => $csvOwnerName,
        ];

        if ($photo !== null) {
            $mapped['photo'] = $photo;
        }

        return $mapped;
    }

    /**
     * @return array<string, list<string>>
     */
    private function importHeaderAliases(): array
    {
        return [
            'type' => ['type', 'tipe', 'jenis_data'],
            'status' => ['status'],
            'name' => [
                'name',
                'nama',
                'namaukm',
                'namamitra',
                'nama_ukm',
                'nama_mitra',
                'nama_ukm_mitra',
                'nama_usaha',
                'nama_kios',
                'nama_toko',
                'nama_warung',
                'nama_outlet',
                'nama_tempat',
            ],
            'address' => ['address', 'alamat', 'alamat_lengkap', 'alamat_kios', 'alamat_usaha', 'lokasi', 'gpsaddress', 'gps_address'],
            'business_type' => ['business_type', 'jenis_usaha', 'jenisproduk', 'jenis_produk', 'kategori', 'bidang_usaha', 'tipe_usaha', 'tipeproduk'],
            'phone_number' => ['phone_number', 'nomor_hp', 'no_hp', 'hp', 'telepon', 'nomor_telepon', 'no_telp', 'kontak', 'wapemilik', 'wa_pemilik', 'whatsapp', 'no_wa'],
            'province' => ['territory_province', 'provinsi', 'province'],
            'city' => ['territory_city', 'kota', 'kota_kabupaten', 'kabupaten', 'city'],
            'district' => ['territory_district', 'kecamatan', 'district'],
            'subdistrict' => ['territory_subdistrict', 'kelurahan', 'desa', 'subdistrict', 'village'],
            'combined_territory' => ['kelurahan', 'wilayah', 'wilayah_survey', 'area', 'lokasi_wilayah'],
            'latitude' => ['latitude', 'lat', 'lintang', 'titik_latitude', 'koordinat_latitude'],
            'longitude' => ['longitude', 'long', 'lng', 'lon', 'bujur', 'longtitude', 'titik_longitude', 'koordinat_longitude'],
            'photo_url' => ['linkfoto', 'link_foto', 'foto', 'photo_url', 'url_foto'],
            'source_id' => ['idukm', 'id_ukm', 'idmitra', 'id_mitra', 'id_jaringan', 'external_id', 'kode_ukm', 'kode_mitra'],
            'owner_name' => ['namauser', 'nama_user', 'user', 'creator', 'dibuat_oleh'],
            'business_owner_name' => ['namapemilik', 'nama_pemilik', 'pemilik', 'owner_kios', 'owner_ukm'],
            'note' => ['note', 'catatan', 'keterangan'],
        ];
    }

    private function importProfileId(?string $sourceId): string
    {
        $normalized = trim((string) $sourceId);
        if ($normalized === '') {
            return (string) Str::uuid();
        }

        return 'import_csv_' . sha1($normalized);
    }

    private function findImportProfile(array $mapped): ?NetworkProfile
    {
        $sourceId = trim((string) ($mapped['_source_id'] ?? ''));
        if ($sourceId !== '') {
            $byDeterministicId = NetworkProfile::query()->find($this->importProfileId($sourceId));
            if ($byDeterministicId) {
                return $byDeterministicId;
            }

            $byStoredSourceId = NetworkProfile::query()
                ->where('reference_name', 'Input spreadsheet HR')
                ->where('note', 'like', '%ID CSV: ' . $sourceId . '%')
                ->first();

            if ($byStoredSourceId) {
                return $byStoredSourceId;
            }
        }

        return NetworkProfile::query()
            ->where('reference_name', 'Input spreadsheet HR')
            ->where('type', $mapped['type'])
            ->where('name', $mapped['name'])
            ->where('phone_number', $mapped['phone_number'])
            ->whereBetween('latitude', [$mapped['latitude'] - 0.000001, $mapped['latitude'] + 0.000001])
            ->whereBetween('longitude', [$mapped['longitude'] - 0.000001, $mapped['longitude'] + 0.000001])
            ->first();
    }

    /**
     * @param array<string, string> $extraNotes
     */
    private function mergeImportNotes(string $note, array $extraNotes): string
    {
        $parts = [];
        if (trim($note) !== '') {
            $parts[] = trim($note);
        }

        foreach ($extraNotes as $label => $value) {
            if (trim($value) !== '') {
                $parts[] = $label . ': ' . trim($value);
            }
        }

        return implode('; ', array_unique($parts));
    }

    /**
     * @return array{province?: string, city?: string, district?: string, subdistrict?: string}
     */
    private function parseCombinedTerritory(string $value): array
    {
        $parts = array_values(array_filter(array_map('trim', explode('-', $value)), fn (string $part): bool => $part !== ''));

        if (count($parts) >= 4) {
            return [
                'province' => $parts[0],
                'city' => $parts[1],
                'district' => $parts[2],
                'subdistrict' => $parts[3],
            ];
        }

        if (count($parts) === 1) {
            return [
                'subdistrict' => $parts[0],
            ];
        }

        return [];
    }

    private function mapImportPhoto(string $url): ?array
    {
        $trimmed = trim($url);
        if ($trimmed === '' || ! filter_var($trimmed, FILTER_VALIDATE_URL)) {
            return null;
        }

        return [
            'id' => 'import_photo_' . md5($trimmed),
            'file_name' => basename(parse_url($trimmed, PHP_URL_PATH) ?: 'foto-jaringan.jpg'),
            'mime_type' => 'image/jpeg',
            'url' => $trimmed,
            'thumbnail_url' => $trimmed,
        ];
    }

    private function pickImportValue(array $row, array $keys, string $default = ''): string
    {
        foreach ($keys as $key) {
            if (isset($row[$key]) && trim((string) $row[$key]) !== '') {
                return trim((string) $row[$key]);
            }
        }

        return $default;
    }

    private function normalizeImportStatus(string $status): string
    {
        $normalized = strtolower(str_replace([' ', '-', '_'], '', trim($status)));

        return match ($normalized) {
            'followup' => 'followUp',
            'complete', 'completed', 'lengkap', 'selesai' => 'completed',
            'archive', 'archived', 'arsip' => 'archived',
            default => 'draft',
        };
    }

    private function parseCoordinate(string $value): ?float
    {
        $normalized = str_replace(',', '.', trim($value));
        if ($normalized === '' || ! is_numeric($normalized)) {
            return null;
        }

        return (float) $normalized;
    }
}
