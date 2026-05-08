<?php

namespace App\Http\Requests\Upload;

use Illuminate\Foundation\Http\FormRequest;

class UploadAttachmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'file' => ['required', 'file', 'max:8192'],
            'label' => ['nullable', 'string'],
        ];
    }
}
