<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Supplier extends Model
{
    use HasUuids;

    protected $fillable = ['name', 'pic_name', 'phone_number', 'territory_province', 'territory_city',
        'territory_district', 'address', 'location_source', 'latitude', 'longitude', 'items', 'notes'];

    protected function casts(): array
    {
        return ['items' => 'array', 'latitude' => 'float', 'longitude' => 'float'];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
