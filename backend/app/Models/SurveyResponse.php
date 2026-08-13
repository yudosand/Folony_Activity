<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SurveyResponse extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'type',
        'user_id',
        'user_name',
        'user_role',
        'area_name',
        'territory_province',
        'territory_city',
        'territory_district',
        'territory_subdistrict',
        'photo_attachment',
        'payload',
        'submitted_at',
    ];

    protected function casts(): array
    {
        return [
            'photo_attachment' => 'array',
            'payload' => 'array',
            'submitted_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
