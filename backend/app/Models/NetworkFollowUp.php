<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NetworkFollowUp extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'network_profile_id',
        'title',
        'note',
        'visit_started_at',
        'visit_finished_at',
        'visit_duration_seconds',
        'photo_attachment',
        'actor_id',
        'actor_name',
        'created_at',
    ];

    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'visit_started_at' => 'datetime',
            'visit_finished_at' => 'datetime',
            'visit_duration_seconds' => 'integer',
            'photo_attachment' => 'array',
        ];
    }

    public function profile(): BelongsTo
    {
        return $this->belongsTo(NetworkProfile::class, 'network_profile_id');
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
