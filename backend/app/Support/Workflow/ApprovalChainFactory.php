<?php

namespace App\Support\Workflow;

use App\Models\User;
use Illuminate\Validation\ValidationException;

class ApprovalChainFactory
{
    /**
     * @return array<int, array<string, int|string>>
     */
    public function buildFor(User $requester): array
    {
        $steps = [];

        if ($requester->spv_id && $requester->spv) {
            $steps[] = [
                'sequence' => 1,
                'approver_role' => UserRole::SPV,
                'approver_id' => $requester->spv_id,
                'approver_name' => $requester->spv->full_name,
            ];
        }

        if ($requester->management_id && $requester->management) {
            $steps[] = [
                'sequence' => count($steps) + 1,
                'approver_role' => UserRole::MANAGEMENT,
                'approver_id' => $requester->management_id,
                'approver_name' => $requester->management->full_name,
            ];
        }

        if ($steps !== []) {
            return $steps;
        }

        throw ValidationException::withMessages([
            'approver' => 'Approver belum diatur, hubungi HR.',
        ]);
    }
}
