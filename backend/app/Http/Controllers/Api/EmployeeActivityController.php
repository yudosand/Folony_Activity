<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmployeeActivity;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EmployeeActivityController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return response()->json(['data' => EmployeeActivity::query()
            ->where('user_id', $request->user()->id)->latest('id')->limit(100)->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'request_id' => ['required', 'string', 'max:100'],
            'note' => ['required', 'string', 'max:5000'],
            'photo_url' => ['nullable', 'url:http,https', 'max:2048'],
            'is_finished' => ['required', 'boolean'],
        ]);
        abort_if(trim($data['note']) === '', 422, 'Isi pekerjaan terlebih dahulu.');

        $activity = DB::transaction(function () use ($request, $data) {
            $userId = $request->user()->id;
            User::whereKey($userId)->lockForUpdate()->firstOrFail();
            $existing = EmployeeActivity::where('request_id', $data['request_id'])->first();
            if ($existing) {
                abort_unless($existing->user_id === $userId, 403);
                return $existing;
            }
            $latest = EmployeeActivity::where('user_id', $userId)->latest('id')->first();
            $active = $latest && ! $latest->is_finished;
            abort_if($data['is_finished'] && ! $active, 422, 'Belum ada pekerjaan aktif.');

            return EmployeeActivity::create([
                ...$data,
                'user_id' => $userId,
                'started_at' => $active ? $latest->started_at : now(),
            ]);
        });

        return response()->json(['data' => $activity], 201);
    }
}
