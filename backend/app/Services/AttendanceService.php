<?php

namespace App\Services;

use App\Models\AttendanceRecord;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class AttendanceService
{
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

        $record = AttendanceRecord::query()->create([
            'id' => Arr::get($payload, 'id', (string) Str::uuid()),
            'user_id' => $user->id,
            'work_date' => $workDate->toDateString(),
            'action' => $action,
            'status' => Arr::get($payload, 'status', 'success'),
            'recorded_at' => $recordedAt,
            'location' => Arr::get($payload, 'location', []),
            'verification' => Arr::get($payload, 'verification'),
            'note' => Arr::get($payload, 'note'),
        ]);

        return AttendanceRecord::query()->findOrFail($record->id);
    }

    public function clearByUser(User $user): void
    {
        AttendanceRecord::query()
            ->where('user_id', $user->id)
            ->delete();
    }
}
