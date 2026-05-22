<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Face\UpsertFaceProfileRequest;
use App\Services\FaceVerificationService;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FaceProfileController extends Controller
{
    public function show(Request $request, FaceVerificationService $faceVerificationService): JsonResponse
    {
        return response()->json([
            'data' => WorkflowApiData::faceProfile(
                $faceVerificationService->profileFor($request->user()),
            ),
        ]);
    }

    public function upsert(
        UpsertFaceProfileRequest $request,
        FaceVerificationService $faceVerificationService,
    ): JsonResponse {
        $profile = $faceVerificationService->enroll(
            $request->user(),
            $request->validated(),
        );

        return response()->json([
            'data' => WorkflowApiData::faceProfile($profile),
        ], 201);
    }
}
