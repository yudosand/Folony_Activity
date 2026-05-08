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
        'actor_id',
        'actor_name',
        'created_at',
    ];

    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public function profile(): BelongsTo
    {
        return $this->belongsTo(NetworkProfile::class, 'network_profile_id');
    }
}
