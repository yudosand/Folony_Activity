<?php

namespace App\Services\Admin;

use App\Models\AttendanceRecord;
use App\Models\LeaveRequest;
use App\Models\User;
use App\Models\WfaRequest;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class AdminMetricsService
{
    public function employeeSummary(User $user): array
    {
        $attendanceRecords = AttendanceRecord::query()
            ->where('user_id', $user->id)
            ->orderBy('recorded_at')
            ->get()
            ->groupBy(fn (AttendanceRecord $record) => $record->work_date->toDateString());

        $totalWorkMinutes = $attendanceRecords->reduce(
            function (int $carry, Collection $records): int {
                $checkIn = $records->first(
                    fn (AttendanceRecord $record) => $record->action === 'checkIn' && $record->status === 'success'
                );
                $checkOut = $records->last(
                    fn (AttendanceRecord $record) => $record->action === 'checkOut' && $record->status === 'success'
                );

                if (! $checkIn || ! $checkOut) {
                    return $carry;
                }

                return $carry + $checkIn->recorded_at->diffInMinutes($checkOut->recorded_at);
            },
            0,
        );

        return [
            'leave_balance_days' => (float) $user->leave_balance_days,
            'attendance_days' => $attendanceRecords->count(),
            'total_work_minutes' => $totalWorkMinutes,
            'leave_requests_count' => LeaveRequest::query()->where('requester_id', $user->id)->count(),
            'wfa_requests_count' => WfaRequest::query()->where('requester_id', $user->id)->count(),
        ];
    }

    public function formatMinutes(int $minutes): string
    {
        $hours = intdiv($minutes, 60);
        $remainingMinutes = $minutes % 60;

        return sprintf('%dj %02dm', $hours, $remainingMinutes);
    }

    public function dashboardSummary(): array
    {
        $today = Carbon::today();

        $todayRecords = AttendanceRecord::query()
            ->whereDate('work_date', $today->toDateString())
            ->get();

        return [
            'total_employees' => User::query()->where('role', '!=', 'hr')->count(),
            'active_employees' => User::query()->where('role', '!=', 'hr')->where('is_active', true)->count(),
            'pending_leave_requests' => LeaveRequest::query()->where('status', 'pending')->count(),
            'pending_wfa_requests' => WfaRequest::query()->where('status', 'pending')->count(),
            'check_ins_today' => $todayRecords->where('action', 'checkIn')->where('status', 'success')->count(),
            'check_outs_today' => $todayRecords->where('action', 'checkOut')->where('status', 'success')->count(),
            'late_check_ins_today' => $todayRecords
                ->where('action', 'checkIn')
                ->where('status', 'success')
                ->filter(fn (AttendanceRecord $record) => $record->recorded_at->format('H:i') > '08:30')
                ->count(),
            'role_breakdown' => User::query()
                ->where('role', '!=', 'hr')
                ->selectRaw('role, count(*) as total')
                ->groupBy('role')
                ->orderBy('role')
                ->get(),
            'recent_leaves' => LeaveRequest::query()
                ->latest('submitted_at')
                ->limit(5)
                ->get(),
            'recent_attendance' => AttendanceRecord::query()
                ->latest('recorded_at')
                ->limit(8)
                ->get(),
        ];
    }
}
