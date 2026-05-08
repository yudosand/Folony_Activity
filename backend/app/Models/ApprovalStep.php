<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class ApprovalStep extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'module',
        'reference_id',
        'sequence',
        'approver_role',
        'approver_id',
        'approver_name',
        'status',
        'note',
        'acted_at',
    ];

    protected function casts(): array
    {
        return [
            'acted_at' => 'datetime',
        ];
    }

    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approver_id');
    }

    public function leaveRequest(): HasOne
    {
        return $this->hasOne(LeaveRequest::class, 'id', 'reference_id');
    }

    public function wfaRequest(): HasOne
    {
        return $this->hasOne(WfaRequest::class, 'id', 'reference_id');
    }
}
