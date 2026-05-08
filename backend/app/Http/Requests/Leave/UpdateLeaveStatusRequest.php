<?php

namespace App\Http\Requests\Leave;

use App\Support\Workflow\WorkflowStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateLeaveStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in(WorkflowStatus::LEAVE_STATUSES)],
            'note' => ['nullable', 'string'],
        ];
    }
}
