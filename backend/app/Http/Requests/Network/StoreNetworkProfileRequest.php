<?php

namespace App\Http\Requests\Network;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreNetworkProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id' => ['nullable', 'string'],
            'type' => ['required', Rule::in(['ukm', 'mitra'])],
            'name' => ['required', 'string'],
            'address' => ['required', 'string'],
            'territory_province' => ['required', 'string', 'max:255'],
            'territory_city' => ['required', 'string', 'max:255'],
            'territory_district' => ['required', 'string', 'max:255'],
            'territory_subdistrict' => ['required', 'string', 'max:255'],
            'business_type' => ['required', 'string'],
            'phone_number' => ['required', 'string'],
            'status' => ['required', Rule::in(['draft', 'followUp', 'completed', 'archived'])],
            'reference_name' => ['nullable', 'string'],
            'note' => ['nullable', 'string'],
            'photo' => ['nullable', 'array'],
            'photo.id' => ['required_with:photo', 'string'],
            'photo.file_name' => ['required_with:photo', 'string'],
            'photo.mime_type' => ['required_with:photo', 'string'],
            'photo.url' => ['required_with:photo', 'string'],
            'photo.thumbnail_url' => ['nullable', 'string'],
            'photo.size_in_bytes' => ['nullable', 'integer'],
            'personality_metrics' => ['nullable', 'array'],
            'personality_metrics.*.label' => ['required_with:personality_metrics', 'string'],
            'personality_metrics.*.score' => ['required_with:personality_metrics', 'numeric'],
            'documents' => ['nullable', 'array'],
            'documents.*.label' => ['required_with:documents', 'string'],
            'documents.*.exists' => ['required_with:documents', 'boolean'],
            'documents.*.is_valid' => ['required_with:documents', 'boolean'],
            'documents.*.attachment' => ['nullable', 'array'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ];
    }
}
