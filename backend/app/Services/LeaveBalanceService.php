<?php

namespace App\Services;

use App\Models\LeaveRequest;
use App\Models\User;

class LeaveBalanceService
{
    public function usesBalance(string $category, string $compensationOption): bool
    {
        return $category === 'cuti' && $compensationOption === 'potongSaldoCuti';
    }

    public function usesBalanceForRequest(LeaveRequest $leaveRequest): bool
    {
        return $this->usesBalance($leaveRequest->category, $leaveRequest->compensation_option);
    }

    public function reserve(User $user, float $durationValue): void
    {
        $currentBalance = (float) ($user->leave_balance_days ?? 0);
        abort_if($durationValue > $currentBalance, 422, 'Saldo cuti tidak mencukupi untuk pengajuan ini.');

        $user->forceFill([
            'leave_balance_days' => $currentBalance - $durationValue,
        ])->save();
    }

    public function restore(User $user, float $durationValue): void
    {
        $currentBalance = (float) ($user->leave_balance_days ?? 0);

        $user->forceFill([
            'leave_balance_days' => $currentBalance + $durationValue,
        ])->save();
    }
}
