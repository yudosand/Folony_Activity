<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WfaRequest extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'requester_id',
        'requester_name',
        'requester_role',
        'mode',
        'compensation_mode',
        'work_date',
        'start_time',
        'end_time',
        'location_label',
        'reason',
        'initial_task',
        'status',
        'note',
        'submitted_at',
        'actual_start_at',
        'actual_end_at',
    ];

    protected function casts(): array
    {
        return [
            'work_date' => 'datetime',
            'submitted_at' => 'datetime',
            'actual_start_at' => 'datetime',
            'actual_end_at' => 'datetime',
        ];
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function approvalSteps(): HasMany
    {
        return $this->hasMany(ApprovalStep::class, 'reference_id', 'id')
            ->where('module', 'wfa')
            ->orderBy('sequence');
    }

    public function taskUpdates(): HasMany
    {
        return $this->hasMany(WfaTaskUpdate::class)->orderBy('created_at');
    }
}
