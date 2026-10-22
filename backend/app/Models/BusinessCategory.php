<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class BusinessCategory extends Model {
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];
    protected function casts(): array { return ['active' => 'boolean']; }
    public function kinds() { return $this->hasMany(BusinessKind::class, 'category_id'); }
}
