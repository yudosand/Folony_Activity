<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class FaceProfile extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'user_id',
        'status',
        'samples',
        'biometric_template',
        'enrolled_at',
        'last_verified_at',
        'verification_mode',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'samples' => 'array',
            'biometric_template' => 'array',
            'enrolled_at' => 'datetime',
            'last_verified_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function verificationLogs(): HasMany
    {
        return $this->hasMany(FaceVerificationLog::class, 'face_profile_id');
    }
}
