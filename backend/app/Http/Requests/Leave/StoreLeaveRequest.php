<?php

namespace App\Http\Requests\Leave;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreLeaveRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id' => ['nullable', 'string'],
            'requester_id' => ['required', 'string'],
            'category' => ['required', Rule::in(['cuti', 'sakit', 'izinPerJam', 'izinPerHari'])],
            'compensation_option' => ['required', Rule::in(['potongSaldoCuti', 'potongGaji', 'tidakPotongGaji'])],
            'start_at' => ['required', 'date'],
            'end_at' => ['nullable', 'date'],
            'duration_value' => ['required', 'numeric', 'gt:0'],
            'reason' => ['required', 'string'],
            'delegate_to' => ['nullable', 'string'],
            'attachments' => ['required', 'array', 'min:1'],
            'attachments.*.id' => ['required', 'string'],
            'attachments.*.file_name' => ['required', 'string'],
            'attachments.*.mime_type' => ['required', 'string'],
            'attachments.*.url' => ['required', 'string'],
            'attachments.*.thumbnail_url' => ['nullable', 'string'],
            'attachments.*.size_in_bytes' => ['nullable', 'integer'],
            'note' => ['nullable', 'string'],
        ];
    }
}
