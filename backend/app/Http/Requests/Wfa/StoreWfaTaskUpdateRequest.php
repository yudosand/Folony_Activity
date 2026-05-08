<?php

namespace App\Http\Requests\Wfa;

use Illuminate\Foundation\Http\FormRequest;

class StoreWfaTaskUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id' => ['nullable', 'string'],
            'actor_id' => ['required', 'string'],
            'message' => ['required', 'string'],
            'created_at' => ['nullable', 'date'],
            'attachments' => ['nullable', 'array'],
            'attachments.*.id' => ['nullable', 'string'],
            'attachments.*.file_name' => ['required_with:attachments', 'string'],
            'attachments.*.mime_type' => ['required_with:attachments', 'string'],
            'attachments.*.url' => ['nullable', 'string'],
            'attachments.*.thumbnail_url' => ['nullable', 'string'],
            'attachments.*.size_in_bytes' => ['nullable', 'integer'],
        ];
    }
}
