<?php

namespace App\Services;

use App\Models\AttendanceRecord;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AttendanceService
{
    private const OUTSIDE_OFFICE_START = 'outsideOfficeStart';
    private const OUTSIDE_OFFICE_FINISH = 'outsideOfficeFinish';

    public function __construct(
        private readonly AttendanceWorkAreaService $attendanceWorkAreaService,
    ) {
    }

    public function queryByUser(User $user, ?Carbon $dateFrom = null, ?Carbon $dateTo = null)
    {
        $query = AttendanceRecord::query()
            ->where('user_id', $user->id)
            ->orderByDesc('recorded_at');

        if ($dateFrom) {
            $query->whereDate('recorded_at', '>=', $dateFrom->toDateString());
        }

        if ($dateTo) {
            $query->whereDate('recorded_at', '<=', $dateTo->toDateString());
        }

        return $query;
    }

    public function create(User $user, array $payload, string $action): AttendanceRecord
    {
        $recordedAt = Arr::has($payload, 'recorded_at')
            ? Carbon::parse(Arr::get($payload, 'recorded_at'))
            : now();
        $workDate = Arr::has($payload, 'work_date')
            ? Carbon::parse(Arr::get($payload, 'work_date'))->startOfDay()
            : $recordedAt->copy()->startOfDay();

        $location = $this->normalizeLocation(Arr::get($payload, 'location', []));
        $areaAudit = $this->attendanceWorkAreaService->assertLocationWithinUserArea($user, $location);
        $location = array_merge($location, $areaAudit);

        $record = AttendanceRecord::query()->create([
            'id' => Arr::get($payload, 'id', (string) Str::uuid()),
            'user_id' => $user->id,
            'work_date' => $workDate->toDateString(),
            'action' => $action,
            'status' => Arr::get($payload, 'status', 'success'),
            'recorded_at' => $recordedAt,
            'location' => $location,
            'verification' => Arr::get($payload, 'verification'),
            'metadata' => Arr::get($payload, 'metadata'),
            'note' => Arr::get($payload, 'note'),
        ]);

        return AttendanceRecord::query()->findOrFail($record->id);
    }

    public function createOutsideOfficeStart(User $user, array $payload): AttendanceRecord
    {
        $recordedAt = Arr::has($payload, 'recorded_at')
            ? Carbon::parse(Arr::get($payload, 'recorded_at'))
            : now();
        $workDate = Arr::has($payload, 'work_date')
            ? Carbon::parse(Arr::get($payload, 'work_date'))->startOfDay()
            : $recordedAt->copy()->startOfDay();

        if ($this->findOpenOutsideOfficeStart($user, $workDate) !== null) {
            throw ValidationException::withMessages([
                'attendance' => 'Masih ada absensi luar kantor yang belum diselesaikan.',
            ]);
        }

        $metadata = array_merge(
            Arr::get($payload, 'metadata', []),
            [
                'attendance_mode' => 'outside_office',
                'started_at' => $recordedAt->toIso8601String(),
            ],
        );

        $record = AttendanceRecord::query()->create([
            'id' => Arr::get($payload, 'id', (string) Str::uuid()),
            'user_id' => $user->id,
            'work_date' => $workDate->toDateString(),
            'action' => self::OUTSIDE_OFFICE_START,
            'status' => Arr::get($payload, 'status', 'success'),
            'recorded_at' => $recordedAt,
            'location' => $this->normalizeLocation(Arr::get($payload, 'location', [])),
            'verification' => Arr::get($payload, 'verification'),
            'metadata' => $metadata,
            'note' => Arr::get(
                $payload,
                'note',
                sprintf(
                    'Absensi luar kantor dimulai untuk %s.',
                    Arr::get($metadata, 'place_description', 'aktivitas lapangan'),
                ),
            ),
        ]);

        return AttendanceRecord::query()->findOrFail($record->id);
    }

    public function createOutsideOfficeFinish(User $user, array $payload): AttendanceRecord
    {
        $recordedAt = Arr::has($payload, 'recorded_at')
            ? Carbon::parse(Arr::get($payload, 'recorded_at'))
            : now();
        $workDate = Arr::has($payload, 'work_date')
            ? Carbon::parse(Arr::get($payload, 'work_date'))->startOfDay()
            : $recordedAt->copy()->startOfDay();

        $openStart = $this->findOpenOutsideOfficeStart($user, $workDate);
        if (! $openStart) {
            throw ValidationException::withMessages([
                'attendance' => 'Belum ada absensi luar kantor yang aktif untuk diselesaikan.',
            ]);
        }

        $durationMinutes = max(0, $openStart->recorded_at->diffInMinutes($recordedAt));
        $durationText = $this->formatDuration($durationMinutes);

        $metadata = array_merge(
            is_array($openStart->metadata) ? $openStart->metadata : [],
            Arr::get($payload, 'metadata', []),
            [
                'attendance_mode' => 'outside_office',
                'started_at' => optional($openStart->recorded_at)?->toIso8601String(),
                'finished_at' => $recordedAt->toIso8601String(),
                'start_record_id' => $openStart->id,
                'duration_minutes' => $durationMinutes,
            ],
        );

        $record = AttendanceRecord::query()->create([
            'id' => Arr::get($payload, 'id', (string) Str::uuid()),
            'user_id' => $user->id,
            'work_date' => $workDate->toDateString(),
            'action' => self::OUTSIDE_OFFICE_FINISH,
            'status' => Arr::get($payload, 'status', 'success'),
            'recorded_at' => $recordedAt,
            'location' => $this->normalizeLocation(Arr::get($payload, 'location', [])),
            'verification' => Arr::get($payload, 'verification'),
            'metadata' => $metadata,
            'note' => Arr::get(
                $payload,
                'note',
                sprintf(
                    'Absensi luar kantor selesai. Durasi %s untuk %s.',
                    $durationText,
                    Arr::get($metadata, 'place_description', Arr::get($metadata, 'ukm_name', 'aktivitas lapangan')),
                ),
            ),
        ]);

        return AttendanceRecord::query()->findOrFail($record->id);
    }

    public function clearByUser(User $user): void
    {
        AttendanceRecord::query()
            ->where('user_id', $user->id)
            ->delete();
    }

    private function normalizeLocation(array $location): array
    {
        return [
            'latitude' => (float) Arr::get($location, 'latitude', 0),
            'longitude' => (float) Arr::get($location, 'longitude', 0),
            'recorded_at' => Arr::has($location, 'recorded_at')
                ? Carbon::parse(Arr::get($location, 'recorded_at'))->toIso8601String()
                : now()->toIso8601String(),
            'address_label' => Arr::get($location, 'address_label'),
            'radius_meters' => Arr::get($location, 'radius_meters'),
            'within_radius' => Arr::get($location, 'within_radius'),
            'distance_meters' => Arr::get($location, 'distance_meters'),
            'work_area_id' => Arr::get($location, 'work_area_id'),
            'work_area_name' => Arr::get($location, 'work_area_name'),
            'work_area_latitude' => Arr::get($location, 'work_area_latitude'),
            'work_area_longitude' => Arr::get($location, 'work_area_longitude'),
        ];
    }

    private function findOpenOutsideOfficeStart(User $user, Carbon $workDate): ?AttendanceRecord
    {
        $records = AttendanceRecord::query()
            ->where('user_id', $user->id)
            ->whereDate('work_date', $workDate->toDateString())
            ->whereIn('action', [self::OUTSIDE_OFFICE_START, self::OUTSIDE_OFFICE_FINISH])
            ->orderBy('recorded_at')
            ->get();

        $openStart = null;
        foreach ($records as $record) {
            if ($record->action === self::OUTSIDE_OFFICE_START && $record->status === 'success') {
                $openStart = $record;
                continue;
            }

            if ($record->action === self::OUTSIDE_OFFICE_FINISH && $record->status === 'success') {
                $openStart = null;
            }
        }

        return $openStart;
    }

    private function reportTypeLabel(?string $reportType): string
    {
        return match ($reportType) {
            'survey' => 'Survey',
            'follow_up' => 'Follow up',
            default => 'Kunjungan',
        };
    }

    private function formatDuration(int $minutes): string
    {
        $hours = intdiv($minutes, 60);
        $remainingMinutes = $minutes % 60;

        if ($hours <= 0) {
            return $remainingMinutes . 'm';
        }

        if ($remainingMinutes <= 0) {
            return $hours . 'j';
        }

        return $hours . 'j ' . $remainingMinutes . 'm';
    }
}
