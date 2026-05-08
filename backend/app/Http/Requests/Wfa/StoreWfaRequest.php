<?php

namespace App\Http\Requests\Wfa;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWfaRequest extends FormRequest
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
            'mode' => ['required', Rule::in(['regular', 'overtime'])],
            'compensation_mode' => ['nullable', Rule::in(['shiftMundur', 'klaimLembur', 'reviewHr'])],
            'work_date' => ['required', 'date'],
            'start_time' => ['required', 'date_format:H:i'],
            'end_time' => ['required', 'date_format:H:i'],
            'location_label' => ['required', 'string'],
            'reason' => ['required', 'string'],
            'initial_task' => ['required', 'string'],
            'note' => ['nullable', 'string'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            if ($this->input('mode') === 'overtime' && ! $this->filled('compensation_mode')) {
                $validator->errors()->add('compensation_mode', 'Mode kompensasi wajib diisi untuk WFA overtime.');
            }
        });
    }
}
