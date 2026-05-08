<?php

namespace App\Support\Workflow;

final class WorkflowModule
{
    public const LEAVE = 'leave';
    public const WFA = 'wfa';
    public const WFA_TASK_UPDATE = 'wfa_task_update';

    public const ALL = [
        self::LEAVE,
        self::WFA,
    ];
}
