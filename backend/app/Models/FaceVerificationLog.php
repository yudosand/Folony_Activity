<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FaceVerificationLog extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'user_id',
        'face_profile_id',
        'attendance_record_id',
        'action',
        'result',
        'match_score',
        'liveness_score',
        'capture_attachment',
        'metadata',
        'verified_at',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'match_score' => 'decimal:2',
            'liveness_score' => 'decimal:2',
            'capture_attachment' => 'array',
            'metadata' => 'array',
            'verified_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function faceProfile(): BelongsTo
    {
        return $this->belongsTo(FaceProfile::class, 'face_profile_id');
    }
}
