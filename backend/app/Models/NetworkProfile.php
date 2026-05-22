<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class NetworkProfile extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'owner_id',
        'owner_name',
        'owner_role',
        'area_name',
        'territory_province',
        'territory_city',
        'territory_district',
        'territory_subdistrict',
        'type',
        'name',
        'address',
        'business_type',
        'phone_number',
        'status',
        'reference_name',
        'note',
        'photo_attachment',
        'personality_metrics',
        'documents',
        'latitude',
        'longitude',
    ];

    protected function casts(): array
    {
        return [
            'photo_attachment' => 'array',
            'personality_metrics' => 'array',
            'documents' => 'array',
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function followUps(): HasMany
    {
        return $this->hasMany(NetworkFollowUp::class)->latest('created_at');
    }
}
