<?php

namespace App\Support\Workflow;

final class WorkflowStatus
{
    public const PENDING = 'pending';
    public const APPROVED = 'approved';
    public const REJECTED = 'rejected';
    public const CANCELLED = 'cancelled';
    public const ACTIVE = 'active';
    public const COMPLETED = 'completed';

    public const LEAVE_STATUSES = [
        self::PENDING,
        self::APPROVED,
        self::REJECTED,
        self::CANCELLED,
    ];

    public const WFA_STATUSES = [
        self::PENDING,
        self::APPROVED,
        self::ACTIVE,
        self::COMPLETED,
        self::REJECTED,
    ];
}
