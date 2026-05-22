<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Upload\UploadAttachmentRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;

class UploadController extends Controller
{
    public function store(UploadAttachmentRequest $request): JsonResponse
    {
        $file = $request->file('file');
        $fileId = (string) Str::uuid();
        $directory = 'field-uploads/' . now()->format('Y/m');
        $extension = $file->getClientOriginalExtension();
        $targetFileName = $extension !== ''
            ? $fileId . '.' . $extension
            : $fileId;
        $mimeType = $file->getClientMimeType() ?? 'application/octet-stream';
        $sizeInBytes = $file->getSize();

        if (class_exists(\finfo::class)) {
            $path = $file->storeAs(
                $directory,
                $targetFileName,
                'public',
            );
        } else {
            $targetDirectory = storage_path('app/public/' . $directory);
            File::ensureDirectoryExists($targetDirectory);
            $file->move($targetDirectory, $targetFileName);
            $path = $directory . '/' . $targetFileName;
        }

        $publicUrl = $request->getSchemeAndHttpHost() . '/storage/' . ltrim($path, '/');

        return response()->json([
            'data' => [
                'id' => $fileId,
                'file_name' => $request->string('label')->toString() !== ''
                    ? $request->string('label')->toString()
                    : $file->getClientOriginalName(),
                'mime_type' => $mimeType,
                'url' => $publicUrl,
                'thumbnail_url' => str_starts_with($mimeType, 'image/')
                    ? $publicUrl
                    : null,
                'size_in_bytes' => $sizeInBytes,
            ],
        ], 201);
    }
}
