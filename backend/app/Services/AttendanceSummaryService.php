<?php

namespace App\Services;

use App\Models\AttendanceRecord;
use App\Models\User;
use App\Models\WfaRequest;
use App\Support\Workflow\WorkflowStatus;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class AttendanceSummaryService
{
    public const OFFICE_START = '08:30';
    public const OFFICE_END = '17:00';

    public function summarize(User $user, Carbon $workDate): array
    {
        $records = AttendanceRecord::query()
            ->where('user_id', $user->id)
            ->whereDate('work_date', $workDate->toDateString())
            ->orderBy('recorded_at')
            ->get();

        $checkInRecord = $records->first(fn (AttendanceRecord $record) => $record->action === 'checkIn' && $record->status === 'success');
        $checkOutRecord = $records->reverse()->first(fn (AttendanceRecord $record) => $record->action === 'checkOut' && $record->status === 'success');

        $wfaRequests = WfaRequest::query()
            ->where('requester_id', $user->id)
            ->whereDate('work_date', $workDate->toDateString())
            ->whereIn('status', [
                WorkflowStatus::APPROVED,
                WorkflowStatus::ACTIVE,
                WorkflowStatus::COMPLETED,
            ])
            ->get();

        $regularWfa = $wfaRequests->filter(fn (WfaRequest $request) => $request->mode === 'regular');
        $overtimeWfa = $wfaRequests->filter(fn (WfaRequest $request) => $request->mode === 'overtime');
        $shiftCompensation = $overtimeWfa->filter(
            fn (WfaRequest $request) => $request->compensation_mode === 'shiftMundur'
        );

        $startBoundary = $this->timeOnDate($workDate, self::OFFICE_START);
        $endBoundary = $this->timeOnDate($workDate, self::OFFICE_END);
        $checkInAt = $checkInRecord?->recorded_at;
        $checkOutAt = $checkOutRecord?->recorded_at;

        $workDuration = $checkInAt === null || $checkOutAt === null
            ? Carbon::createFromTimestamp(0)->diff(Carbon::createFromTimestamp(0))
            : $checkInAt->diff($checkOutAt);
        $lateDuration = $checkInAt !== null && $checkInAt->greaterThan($startBoundary)
            ? $startBoundary->diff($checkInAt)
            : Carbon::createFromTimestamp(0)->diff(Carbon::createFromTimestamp(0));
        $earlyArrivalDuration = $checkInAt !== null && $checkInAt->lessThan($startBoundary)
            ? $checkInAt->diff($startBoundary)
            : Carbon::createFromTimestamp(0)->diff(Carbon::createFromTimestamp(0));
        $earlyLeaveDuration = $checkOutAt !== null && $checkOutAt->lessThan($endBoundary)
            ? $checkOutAt->diff($endBoundary)
            : Carbon::createFromTimestamp(0)->diff(Carbon::createFromTimestamp(0));
        $attendanceOvertime = $checkOutAt !== null && $checkOutAt->greaterThan($endBoundary)
            ? $endBoundary->diff($checkOutAt)
            : Carbon::createFromTimestamp(0)->diff(Carbon::createFromTimestamp(0));
        $wfaOvertimeDuration = $this->sumWfaDurations($overtimeWfa);
        $effectiveOvertime = $attendanceOvertime->totalSeconds > 0 ? $attendanceOvertime : $wfaOvertimeDuration;

        return [
            'user_id' => $user->id,
            'work_date' => $workDate->toDateString(),
            'standard_start_time' => self::OFFICE_START,
            'standard_end_time' => self::OFFICE_END,
            'check_in_at' => $checkInAt?->toIso8601String(),
            'check_out_at' => $checkOutAt?->toIso8601String(),
            'arrival_label' => $this->arrivalLabel($checkInAt, $lateDuration, $earlyArrivalDuration),
            'arrival_note' => $this->arrivalNote($checkInAt, $lateDuration, $earlyArrivalDuration),
            'departure_label' => $this->departureLabel($checkOutAt, $earlyLeaveDuration, $effectiveOvertime),
            'departure_note' => $this->departureNote($checkOutAt, $earlyLeaveDuration, $effectiveOvertime),
            'summary_label' => $this->summaryLabel($checkInAt, $checkOutAt, $lateDuration, $earlyLeaveDuration, $effectiveOvertime),
            'summary_note' => $checkInAt === null
                ? 'Jam kerja standar ' . self::OFFICE_START . ' - ' . self::OFFICE_END . '.'
                : ($checkOutAt === null
                    ? 'Durasi kerja akan dihitung setelah check-out.'
                    : 'Total durasi kerja hari ini ' . $this->formatDuration($workDuration) . '.'),
            'late_duration_minutes' => (int) round($lateDuration->totalMinutes),
            'early_leave_duration_minutes' => (int) round($earlyLeaveDuration->totalMinutes),
            'overtime_duration_minutes' => (int) round($effectiveOvertime->totalMinutes),
            'work_duration_minutes' => (int) round($workDuration->totalMinutes),
            'has_regular_wfa' => $regularWfa->isNotEmpty(),
            'has_overtime_wfa' => $overtimeWfa->isNotEmpty(),
            'next_start_recommendation' => $shiftCompensation->isEmpty()
                ? null
                : $this->recommendedNextStart(self::OFFICE_START, $this->sumWfaDurations($shiftCompensation)),
            'context_notes' => $this->contextNotes($regularWfa, $overtimeWfa, $shiftCompensation),
        ];
    }

    private function arrivalLabel(?Carbon $checkInAt, $lateDuration, $earlyArrivalDuration): string
    {
        if ($checkInAt === null) {
            return 'Belum check-in';
        }

        if ($lateDuration->totalSeconds > 0) {
            return 'Terlambat';
        }

        if ($earlyArrivalDuration->totalSeconds > 0) {
            return 'Lebih awal';
        }

        return 'Tepat waktu';
    }

    private function arrivalNote(?Carbon $checkInAt, $lateDuration, $earlyArrivalDuration): string
    {
        if ($checkInAt === null) {
            return 'Target masuk ' . self::OFFICE_START . '.';
        }

        if ($lateDuration->totalSeconds > 0) {
            return 'Terlambat ' . $this->formatDuration($lateDuration) . ' dari jadwal ' . self::OFFICE_START . '.';
        }

        if ($earlyArrivalDuration->totalSeconds > 0) {
            return 'Lebih awal ' . $this->formatDuration($earlyArrivalDuration) . ' dari jadwal ' . self::OFFICE_START . '.';
        }

        return 'Tepat waktu sesuai jadwal ' . self::OFFICE_START . '.';
    }

    private function departureLabel(?Carbon $checkOutAt, $earlyLeaveDuration, $effectiveOvertime): string
    {
        if ($checkOutAt === null) {
            return 'Belum check-out';
        }

        if ($effectiveOvertime->totalSeconds > 0) {
            return 'Lembur';
        }

        if ($earlyLeaveDuration->totalSeconds > 0) {
            return 'Pulang cepat';
        }

        return 'Sesuai jadwal';
    }

    private function departureNote(?Carbon $checkOutAt, $earlyLeaveDuration, $effectiveOvertime): string
    {
        if ($checkOutAt === null) {
            return 'Target pulang ' . self::OFFICE_END . '.';
        }

        if ($effectiveOvertime->totalSeconds > 0) {
            return 'Pulang ' . $this->formatDuration($effectiveOvertime) . ' setelah jadwal ' . self::OFFICE_END . '.';
        }

        if ($earlyLeaveDuration->totalSeconds > 0) {
            return 'Pulang lebih cepat ' . $this->formatDuration($earlyLeaveDuration) . ' dari jadwal ' . self::OFFICE_END . '.';
        }

        return 'Pulang sesuai jadwal ' . self::OFFICE_END . '.';
    }

    private function summaryLabel(?Carbon $checkInAt, ?Carbon $checkOutAt, $lateDuration, $earlyLeaveDuration, $effectiveOvertime): string
    {
        if ($checkInAt === null) {
            return 'Belum mulai';
        }
        if ($checkOutAt === null) {
            return 'Sesi aktif';
        }
        if ($effectiveOvertime->totalSeconds > 0) {
            return 'Lembur';
        }
        if ($earlyLeaveDuration->totalSeconds > 0) {
            return 'Pulang cepat';
        }
        if ($lateDuration->totalSeconds > 0) {
            return 'Terlambat';
        }

        return 'Normal';
    }

    private function contextNotes(Collection $regularWfa, Collection $overtimeWfa, Collection $shiftCompensation): array
    {
        $notes = [];

        if ($regularWfa->isNotEmpty()) {
            $notes[] = 'WFA reguler hari ini tercatat untuk jam kerja utama.';
        }
        if ($overtimeWfa->isNotEmpty()) {
            $notes[] = 'WFA overtime hari ini tercatat ' . $this->formatDuration($this->sumWfaDurations($overtimeWfa)) . '.';
        }
        if ($shiftCompensation->isNotEmpty()) {
            $notes[] = 'Rekomendasi jam masuk esok hari: ' . $this->recommendedNextStart(self::OFFICE_START, $this->sumWfaDurations($shiftCompensation)) . '.';
        }

        return $notes;
    }

    private function sumWfaDurations(Collection $requests)
    {
        $seconds = $requests->reduce(function (int $sum, WfaRequest $request): int {
            $start = $this->timeOnDate(Carbon::create(2026, 1, 1), $request->start_time);
            $end = $this->timeOnDate(Carbon::create(2026, 1, 1), $request->end_time);
            if ($end->lessThanOrEqualTo($start)) {
                return $sum;
            }

            return $sum + $start->diffInSeconds($end);
        }, 0);

        return Carbon::createFromTimestamp(0)->diff(Carbon::createFromTimestamp($seconds));
    }

    private function timeOnDate(Carbon $date, string $hhmm): Carbon
    {
        [$hour, $minute] = array_pad(explode(':', $hhmm), 2, '0');

        return $date->copy()->setTime((int) $hour, (int) $minute);
    }

    private function formatDuration($duration): string
    {
        $hours = (int) floor($duration->totalMinutes / 60);
        $minutes = (int) round($duration->totalMinutes % 60);

        if ($hours === 0) {
            return $minutes . ' menit';
        }

        if ($minutes === 0) {
            return $hours . ' jam';
        }

        return $hours . 'j ' . $minutes . 'm';
    }

    private function recommendedNextStart(string $baseline, $duration): string
    {
        $adjusted = $this->timeOnDate(Carbon::create(2026, 1, 1), $baseline)
            ->addMinutes((int) round($duration->totalMinutes));

        return $adjusted->format('H:i');
    }
}
