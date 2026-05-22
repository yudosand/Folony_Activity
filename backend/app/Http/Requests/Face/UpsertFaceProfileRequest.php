<?php

namespace App\Http\Requests\Face;

use Illuminate\Foundation\Http\FormRequest;

class UpsertFaceProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'samples' => ['required', 'array', 'min:3', 'max:5'],
            'samples.*.id' => ['required', 'string'],
            'samples.*.file_name' => ['required', 'string'],
            'samples.*.mime_type' => ['required', 'string'],
            'samples.*.url' => ['required', 'url'],
            'samples.*.thumbnail_url' => ['nullable', 'url'],
            'samples.*.size_in_bytes' => ['nullable', 'integer', 'min:0'],
            'biometric_template' => ['required', 'array', 'min:64', 'max:512'],
            'biometric_template.*' => ['required', 'numeric'],
            'note' => ['nullable', 'string'],
        ];
    }
}
