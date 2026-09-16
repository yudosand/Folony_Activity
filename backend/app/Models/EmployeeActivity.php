<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmployeeActivity extends Model
{
    protected $fillable = ['request_id', 'user_id', 'note', 'photo_url', 'is_finished', 'started_at'];

    protected function casts(): array
    {
        return ['is_finished' => 'boolean', 'started_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
