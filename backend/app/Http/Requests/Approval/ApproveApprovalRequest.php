<?php

namespace App\Http\Requests\Approval;

use Illuminate\Foundation\Http\FormRequest;

class ApproveApprovalRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'approver_id' => ['required', 'string'],
            'approver_name' => ['nullable', 'string'],
            'note' => ['nullable', 'string'],
        ];
    }
}
