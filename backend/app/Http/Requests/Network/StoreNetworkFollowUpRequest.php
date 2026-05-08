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
            'next_status' => ['nullable', Rule::in(['draft', 'followUp', 'completed', 'archived'])],
        ];
    }
}
