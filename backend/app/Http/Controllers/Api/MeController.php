<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $user = $request->user();

        abort_if(! $user, 401, 'User belum terautentikasi.');

        $user->loadMissing(['spv', 'management', 'faceProfile']);

        return response()->json([
            'data' => WorkflowApiData::user($user),
        ]);
    }
}
