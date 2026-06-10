<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PushDeviceToken;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class DeviceTokenController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_if(! $user instanceof User, 401, 'User belum terautentikasi.');

        $validated = $request->validate([
            'token' => ['required', 'string'],
            'platform' => ['nullable', 'string', 'max:32'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:64'],
        ]);

        $tokenHash = hash('sha256', $validated['token']);

        $deviceToken = PushDeviceToken::query()->firstOrNew([
            'user_id' => $user->id,
            'platform' => $validated['platform'] ?? 'android',
            'token_hash' => $tokenHash,
        ]);

        if (! $deviceToken->exists) {
            $deviceToken->id = (string) Str::uuid();
        }

        $deviceToken->fill([
            'token' => $validated['token'],
            'device_name' => $validated['device_name'] ?? null,
            'app_version' => $validated['app_version'] ?? null,
            'last_seen_at' => now(),
        ])->save();

        return response()->json([
            'data' => [
                'registered' => true,
            ],
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_if(! $user instanceof User, 401, 'User belum terautentikasi.');

        $validated = $request->validate([
            'token' => ['required', 'string'],
        ]);

        PushDeviceToken::query()
            ->where('user_id', $user->id)
            ->where('token_hash', hash('sha256', $validated['token']))
            ->delete();

        return response()->json([
            'data' => [
                'removed' => true,
            ],
        ]);
    }
}
