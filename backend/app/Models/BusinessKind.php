<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class BusinessKind extends Model {
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
    protected function casts(): array { return ['active' => 'boolean']; }
    public function category() { return $this->belongsTo(BusinessCategory::class, 'category_id'); }
}
