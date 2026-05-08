<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Support\Workflow\WorkflowModule;

class WfaTaskUpdate extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'wfa_request_id',
        'created_by',
        'message',
    ];

    public function wfaRequest(): BelongsTo
    {
        return $this->belongsTo(WfaRequest::class);
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(Attachment::class, 'reference_id', 'id')
            ->where('module', WorkflowModule::WFA_TASK_UPDATE);
    }
}
