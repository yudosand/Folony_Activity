<?php

namespace App\Http\Requests\Face;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFaceVerificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'action' => ['required', Rule::in(['checkIn', 'checkOut', 'enrollmentAudit'])],
            'capture' => ['required', 'array'],
            'capture.id' => ['required', 'string'],
            'capture.file_name' => ['required', 'string'],
            'capture.mime_type' => ['required', 'string'],
            'capture.url' => ['required', 'url'],
            'capture.thumbnail_url' => ['nullable', 'url'],
            'capture.size_in_bytes' => ['nullable', 'integer', 'min:0'],
            'signature' => ['required', 'array', 'min:64', 'max:512'],
            'signature.*' => ['required', 'numeric'],
            'liveness_score' => ['required', 'numeric', 'min:0', 'max:100'],
            'note' => ['nullable', 'string'],
        ];
    }
}
