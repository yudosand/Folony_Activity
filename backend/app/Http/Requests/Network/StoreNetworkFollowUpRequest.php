<?php

namespace App\Http\Requests\Network;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreNetworkFollowUpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id' => ['nullable', 'string'],
            'title' => ['required', 'string'],
            'note' => ['required', 'string'],
            'created_at' => ['nullable', 'date'],
            'visit_started_at' => ['nullable', 'date'],
            'visit_finished_at' => ['nullable', 'date'],
            'visit_duration_seconds' => ['nullable', 'integer', 'min:0', 'max:86400'],
            'photo' => ['nullable', 'array'],
            'photo.id' => ['required_with:photo', 'string'],
            'photo.file_name' => ['required_with:photo', 'string'],
            'photo.mime_type' => ['required_with:photo', 'string'],
            'photo.url' => ['required_with:photo', 'string'],
            'photo.thumbnail_url' => ['nullable', 'string'],
            'photo.size_in_bytes' => ['nullable', 'integer'],
            'next_status' => ['nullable', Rule::in(['draft', 'followUp', 'completed', 'archived'])],
        ];
    }
}
