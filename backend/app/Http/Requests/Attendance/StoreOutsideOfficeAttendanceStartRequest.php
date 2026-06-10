<?php

namespace App\Http\Requests\Attendance;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreOutsideOfficeAttendanceStartRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id' => ['nullable', 'string'],
            'user_id' => ['nullable', 'string'],
            'work_date' => ['nullable', 'date'],
            'status' => ['nullable', Rule::in(['pending', 'success', 'failed'])],
            'recorded_at' => ['nullable', 'date'],
            'location' => ['required', 'array'],
            'location.latitude' => ['required', 'numeric'],
            'location.longitude' => ['required', 'numeric'],
            'location.recorded_at' => ['nullable', 'date'],
            'location.address_label' => ['nullable', 'string'],
            'verification' => ['nullable', 'array'],
            'verification.verified_at' => ['required_with:verification', 'date'],
            'verification.decision' => ['nullable', 'string'],
            'verification.match_score' => ['nullable', 'numeric'],
            'verification.liveness_score' => ['nullable', 'numeric'],
            'verification.note' => ['nullable', 'string'],
            'verification.capture' => ['nullable', 'array'],
            'verification.capture.id' => ['required_with:verification.capture', 'string'],
            'verification.capture.file_name' => ['required_with:verification.capture', 'string'],
            'verification.capture.mime_type' => ['required_with:verification.capture', 'string'],
            'verification.capture.url' => ['required_with:verification.capture', 'string'],
            'verification.capture.thumbnail_url' => ['nullable', 'string'],
            'verification.capture.size_in_bytes' => ['nullable', 'integer'],
            'metadata' => ['required', 'array'],
            'metadata.place_description' => ['required', 'string', 'max:255'],
            'metadata.ukm_name' => ['nullable', 'string', 'max:255'],
            'metadata.report_type' => ['nullable', Rule::in(['survey', 'kunjungan', 'follow_up'])],
            'metadata.report_text' => ['nullable', 'string'],
            'metadata.evidence_attachment' => ['required', 'array'],
            'metadata.evidence_attachment.id' => ['required', 'string'],
            'metadata.evidence_attachment.file_name' => ['required', 'string'],
            'metadata.evidence_attachment.mime_type' => ['required', 'string'],
            'metadata.evidence_attachment.url' => ['required', 'string'],
            'metadata.evidence_attachment.thumbnail_url' => ['nullable', 'string'],
            'metadata.evidence_attachment.size_in_bytes' => ['nullable', 'integer'],
            'note' => ['nullable', 'string'],
        ];
    }
}
