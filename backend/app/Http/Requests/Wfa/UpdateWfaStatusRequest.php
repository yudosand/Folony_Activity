<?php

namespace App\Http\Requests\Wfa;

use App\Support\Workflow\WorkflowStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateWfaStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in(WorkflowStatus::WFA_STATUSES)],
            'actual_start_at' => ['nullable', 'date'],
            'actual_end_at' => ['nullable', 'date'],
            'note' => ['nullable', 'string'],
        ];
    }
}
