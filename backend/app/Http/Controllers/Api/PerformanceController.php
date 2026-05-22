<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PerformanceTargetService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PerformanceController extends Controller
{
    public function summary(Request $request, PerformanceTargetService $performanceTargetService): JsonResponse
    {
        $validated = $request->validate([
            'period_month' => ['nullable', 'date_format:Y-m'],
        ]);

        return response()->json([
            'data' => $performanceTargetService->summaryForUser(
                $request->user(),
                $validated['period_month'] ?? null,
            ),
        ]);
    }
}
