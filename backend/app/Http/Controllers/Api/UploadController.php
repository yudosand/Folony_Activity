<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Upload\UploadAttachmentRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class UploadController extends Controller
{
    public function store(UploadAttachmentRequest $request): JsonResponse
    {
        $file = $request->file('file');
        $fileId = (string) Str::uuid();
        $directory = 'field-uploads/' . now()->format('Y/m');
        $path = $file->storeAs(
            $directory,
            $fileId . '.' . $file->getClientOriginalExtension(),
            'public',
        );
        $publicUrl = $request->getSchemeAndHttpHost() . '/storage/' . ltrim($path, '/');

        return response()->json([
            'data' => [
                'id' => $fileId,
                'file_name' => $request->string('label')->toString() !== ''
                    ? $request->string('label')->toString()
                    : $file->getClientOriginalName(),
                'mime_type' => $file->getClientMimeType() ?? 'application/octet-stream',
                'url' => $publicUrl,
                'thumbnail_url' => str_starts_with($file->getMimeType() ?? '', 'image/')
                    ? $publicUrl
                    : null,
                'size_in_bytes' => $file->getSize(),
            ],
        ], 201);
    }
}
