<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user && $request->filled('user_id')) {
            $user = User::query()
                ->with(['spv', 'management'])
                ->findOrFail($request->string('user_id')->toString());
        }

        abort_if(! $user, 401, 'User belum terautentikasi.');

        $user->loadMissing(['spv', 'management']);

        return response()->json([
            'data' => WorkflowApiData::user($user),
        ]);
    }
}
