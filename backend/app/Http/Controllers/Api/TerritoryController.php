<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Admin\IndonesiaTerritoryMasterService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TerritoryController extends Controller
{
    public function provinces(IndonesiaTerritoryMasterService $service): JsonResponse
    {
        return response()->json([
            'data' => $service->provinces()->values()->all(),
        ]);
    }

    public function cities(Request $request, IndonesiaTerritoryMasterService $service): JsonResponse
    {
        return response()->json([
            'data' => $service->cities($request->query('province_code'))->values()->all(),
        ]);
    }

    public function districts(Request $request, IndonesiaTerritoryMasterService $service): JsonResponse
    {
        return response()->json([
            'data' => $service->districts($request->query('city_code'))->values()->all(),
        ]);
    }

    public function subdistricts(Request $request, IndonesiaTerritoryMasterService $service): JsonResponse
    {
        return response()->json([
            'data' => $service->subdistricts($request->query('district_code'))->values()->all(),
        ]);
    }
}
