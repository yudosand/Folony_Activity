<?php

namespace App\Support\Workflow;

final class ApprovalStepStatus
{
    public const PENDING = 'pending';
    public const APPROVED = 'approved';
    public const REJECTED = 'rejected';
    public const SKIPPED = 'skipped';

    public const ALL = [
        self::PENDING,
        self::APPROVED,
        self::REJECTED,
        self::SKIPPED,
    ];
}
