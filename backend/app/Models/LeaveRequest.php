<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LeaveRequest extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'requester_id',
        'requester_name',
        'requester_role',
        'category',
        'compensation_option',
        'start_at',
        'end_at',
        'duration_value',
        'reason',
        'delegate_to',
        'status',
        'note',
        'submitted_at',
    ];

    protected function casts(): array
    {
        return [
            'start_at' => 'datetime',
            'end_at' => 'datetime',
            'submitted_at' => 'datetime',
            'duration_value' => 'decimal:2',
        ];
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function approvalSteps(): HasMany
    {
        return $this->hasMany(ApprovalStep::class, 'reference_id', 'id')
            ->where('module', 'leave')
            ->orderBy('sequence');
    }
}
