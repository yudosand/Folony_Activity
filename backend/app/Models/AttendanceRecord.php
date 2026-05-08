<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AttendanceRecord extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'user_id',
        'work_date',
        'action',
        'status',
        'recorded_at',
        'location',
        'verification',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'work_date' => 'date',
            'recorded_at' => 'datetime',
            'location' => 'array',
            'verification' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
