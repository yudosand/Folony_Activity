<?php

namespace App\Services\Admin;

use Illuminate\Database\Query\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class EmployeeActivitySummary
{
    public function sessions(): Builder
    {
        return DB::table('employee_activities')
            ->selectRaw('user_id, started_at, DATE(started_at) as work_date, MAX(created_at) as last_update, MAX(is_finished) as completed, COUNT(*) as update_count')
            ->groupBy('user_id', 'started_at');
    }

    public function days(array $filters = []): Builder
    {
        return DB::query()->fromSub($this->sessions(), 'sessions')
            ->join('users', 'users.id', '=', 'sessions.user_id')
            ->selectRaw('sessions.user_id, work_date, users.full_name, users.employee_code, users.role,
                MIN(started_at) as started_at, MAX(last_update) as last_update,
                SUM(update_count) as update_count, COUNT(*) as session_count,
                SUM(CASE WHEN completed = 0 THEN 1 ELSE 0 END) as active_sessions')
            ->when($filters['search'] ?? null, fn ($q, $search) => $q->where(function ($q) use ($search) {
                $q->where('users.full_name', 'like', "%{$search}%")->orWhere('users.employee_code', 'like', "%{$search}%");
            }))
            ->when($filters['from'] ?? null, fn ($q, $date) => $q->where('work_date', '>=', $date))
            ->when($filters['to'] ?? null, fn ($q, $date) => $q->where('work_date', '<=', $date))
            ->groupBy('sessions.user_id', 'work_date', 'users.full_name', 'users.employee_code', 'users.role')
            ->when($filters['status'] ?? null, fn ($q, $status) => $q->havingRaw(
                'SUM(CASE WHEN completed = 0 THEN 1 ELSE 0 END) ' . ($status === 'active' ? '> 0' : '= 0')))
            ->orderByDesc('work_date')->orderBy('users.full_name')->orderBy('sessions.user_id');
    }

    public function withDurations(Collection $days): Collection
    {
        if ($days->isEmpty()) return $days;
        if ($days->count() > 200) {
            return $days->chunk(200)->flatMap(fn ($batch) => $this->withDurations($batch))->values();
        }
        $sessions = $this->sessions()->where(function ($query) use ($days) {
            foreach ($days as $day) {
                $query->orWhere(fn ($q) => $q->where('user_id', $day->user_id)->whereDate('started_at', $day->work_date));
            }
        })->get()->groupBy(fn ($row) => $row->user_id . '|' . $row->work_date);
        $now = now();
        return $days->map(function ($day) use ($sessions, $now) {
            $day->duration_seconds = $sessions[$day->user_id . '|' . $day->work_date]->sum(function ($session) use ($now) {
                $end = $session->completed ? Carbon::parse($session->last_update) : $now;
                return max(0, (int) Carbon::parse($session->started_at)->diffInSeconds($end, false));
            });
            $day->duration_label = self::durationLabel($day->duration_seconds);
            $day->finished_at = $day->active_sessions ? null : $day->last_update;
            return $day;
        });
    }

    public static function durationLabel(int $seconds): string
    {
        return sprintf('%02d:%02d:%02d', intdiv($seconds, 3600), intdiv($seconds % 3600, 60), $seconds % 60);
    }
}
