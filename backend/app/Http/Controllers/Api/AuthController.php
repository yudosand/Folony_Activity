<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Models\User;
use App\Support\Workflow\WorkflowApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'identifier' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        $identifier = trim($validated['identifier']);

        $user = User::query()
            ->with(['spv', 'management', 'faceProfile'])
            ->where('employee_code', $identifier)
            ->orWhere('phone_number', $identifier)
            ->orWhere('email', $identifier)
            ->first();

        abort_if(! $user || ! Hash::check($validated['password'], $user->password), 422, 'Kredensial tidak valid.');
        abort_if(! $user->is_active, 403, 'User tidak aktif.');

        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'user' => WorkflowApiData::user($user),
            ],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'data' => [
                'logged_out' => true,
            ],
        ]);
    }

    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $user = $request->user();
        abort_if(! $user instanceof User, 401, 'User belum terautentikasi.');

        $validated = $request->validated();
        abort_if(
            ! Hash::check($validated['current_password'], $user->password),
            422,
            'Password saat ini tidak sesuai.'
        );

        $user->forceFill([
            'password' => $validated['new_password'],
        ])->save();

        return response()->json([
            'data' => [
                'password_changed' => true,
            ],
        ]);
    }
}
