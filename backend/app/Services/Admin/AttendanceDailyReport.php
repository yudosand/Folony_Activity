<?php

namespace App\Services\Admin;

use App\Models\AttendanceRecord;
use App\Services\AttendanceSummaryService;
use Illuminate\Support\Carbon;

class AttendanceDailyReport
{
    public function day(string $userId, string $date): array
    {
        $records = AttendanceRecord::with('user')->where('user_id', $userId)->whereDate('work_date', $date)
            ->orderBy('recorded_at')->orderBy('id')->get();
        $starts = [];
        $intervals = [];
        foreach ($records->where('status', 'success') as $record) {
            $type = str_starts_with($record->action, 'outsideOffice') ? 'outside' : 'office';
            if (in_array($record->action, ['checkIn', 'outsideOfficeStart'], true)) {
                $starts[$type] ??= $record->recorded_at;
            } elseif (in_array($record->action, ['checkOut', 'outsideOfficeFinish'], true) && isset($starts[$type])) {
                if ($record->recorded_at->gte($starts[$type])) {
                    $intervals[] = [$starts[$type]->timestamp, $record->recorded_at->timestamp];
                }
                unset($starts[$type]);
            }
        }
        sort($intervals);
        $seconds = 0;
        $end = null;
        foreach ($intervals as [$from, $until]) {
            $seconds += max(0, $until - max($from, $end ?? $from));
            $end = max($end ?? $until, $until);
        }
        $user = $records->first()?->user;
        $summary = $user ? app(AttendanceSummaryService::class)->summarize($user, Carbon::parse($date)) : [];
        $success = $records->where('status', 'success');

        return [
            'user_id' => $userId, 'user' => $user, 'date' => $date, 'records' => $records,
            'check_in' => $success->first(fn ($r) => in_array($r->action, ['checkIn', 'outsideOfficeStart']))?->recorded_at,
            'check_out' => $success->last(fn ($r) => in_array($r->action, ['checkOut', 'outsideOfficeFinish']))?->recorded_at,
            'last_update' => $records->last()?->recorded_at,
            'duration_seconds' => $intervals ? $seconds : null,
            'duration_label' => $intervals ? sprintf('%02d:%02d:%02d', intdiv($seconds, 3600), intdiv($seconds % 3600, 60), $seconds % 60) : 'Belum lengkap',
            'open_sessions' => count($starts), 'summary' => $summary,
            'status_label' => $success->whereIn('action', ['checkIn', 'checkOut'])->isEmpty()
                && $success->whereIn('action', ['outsideOfficeStart', 'outsideOfficeFinish'])->isNotEmpty()
                ? 'Absensi luar kantor' : ($summary['summary_label'] ?? 'Belum ada ringkasan'),
            'locations' => $records->pluck('location.address_label')->filter()->unique()->values(),
        ];
    }
}
