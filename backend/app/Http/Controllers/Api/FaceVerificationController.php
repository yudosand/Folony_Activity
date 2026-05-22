<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Face\StoreFaceVerificationRequest;
use App\Services\FaceVerificationService;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;

class FaceVerificationController extends Controller
{
    public function store(
        StoreFaceVerificationRequest $request,
        FaceVerificationService $faceVerificationService,
    ): JsonResponse {
        $result = $faceVerificationService->verify(
            $request->user(),
            $request->validated(),
        );

        return response()->json([
            'data' => [
                'verified' => $result['verified'],
                'decision' => $result['decision'],
                'match_score' => $result['match_score'],
                'liveness_score' => $result['liveness_score'],
                'note' => $result['note'],
                'profile' => WorkflowApiData::faceProfile($result['profile']),
                'verification_log' => WorkflowApiData::faceVerificationLog($result['log']),
            ],
        ], $result['verified'] ? 201 : 200);
    }
}
