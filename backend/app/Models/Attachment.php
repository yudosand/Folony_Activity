<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Attachment extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'module',
        'reference_id',
        'file_name',
        'mime_type',
        'url',
        'thumbnail_url',
        'size_in_bytes',
    ];
}
