<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfilePhotoController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $payload = $request->validate([
            'profile_photo' => ['required', 'array'],
            'profile_photo.id' => ['required', 'string'],
            'profile_photo.file_name' => ['required', 'string'],
            'profile_photo.mime_type' => ['required', 'string'],
            'profile_photo.url' => ['required', 'string'],
            'profile_photo.thumbnail_url' => ['nullable', 'string'],
            'profile_photo.size_in_bytes' => ['nullable', 'integer'],
        ]);

        $user = $request->user();
        $user->update([
            'profile_photo_attachment' => $payload['profile_photo'],
        ]);

        return response()->json([
            'data' => WorkflowApiData::user($user->fresh(['spv', 'management', 'faceProfile', 'attendanceWorkArea'])),
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->update([
            'profile_photo_attachment' => null,
        ]);

        return response()->json([
            'data' => WorkflowApiData::user($user->fresh(['spv', 'management', 'faceProfile', 'attendanceWorkArea'])),
        ]);
    }
}
