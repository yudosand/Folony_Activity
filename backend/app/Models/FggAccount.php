<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FggAccount extends Model
{
    protected $guarded = ['id'];
    protected $hidden = ['token'];

    protected function casts(): array
    {
        return ['token' => 'encrypted', 'hubs' => 'array'];
    }
}
