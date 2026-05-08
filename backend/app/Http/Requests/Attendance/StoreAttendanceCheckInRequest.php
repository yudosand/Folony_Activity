<?php

namespace App\Http\Requests\Attendance;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreAttendanceCheckInRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id' => ['nullable', 'string'],
            'work_date' => ['nullable', 'date'],
            'status' => ['nullable', Rule::in(['pending', 'success', 'failed'])],
            'recorded_at' => ['nullable', 'date'],
            'location' => ['required', 'array'],
            'location.latitude' => ['required', 'numeric'],
            'location.longitude' => ['required', 'numeric'],
            'location.recorded_at' => ['required', 'date'],
            'location.address_label' => ['nullable', 'string'],
            'location.radius_meters' => ['nullable', 'numeric'],
            'location.within_radius' => ['nullable', 'boolean'],
            'verification' => ['nullable', 'array'],
            'verification.verified_at' => ['required_with:verification', 'date'],
            'verification.match_score' => ['nullable', 'numeric'],
            'verification.liveness_score' => ['nullable', 'numeric'],
            'verification.capture' => ['nullable', 'array'],
            'note' => ['nullable', 'string'],
        ];
    }
}
