<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Network\StoreNetworkFollowUpRequest;
use App\Http\Requests\Network\StoreNetworkProfileRequest;
use App\Http\Requests\Network\UpdateNetworkProfileRequest;
use App\Models\NetworkProfile;
use App\Services\NetworkService;
use App\Support\Api\ApiListResponse;
use App\Support\FieldOps\FieldApiData;
use App\Support\Workflow\UserRole;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NetworkController extends Controller
{
    public function index(Request $request, NetworkService $networkService): JsonResponse
    {
        return ApiListResponse::fromQueryWindow(
            $request,
            $networkService->queryOwned(
                $request->user(),
                $request->string('type')->toString() ?: null,
                $request->string('q')->toString() ?: null,
            ),
            fn (NetworkProfile $profile) => FieldApiData::networkProfileListItem($profile),
        );
    }

    public function teamUkm(Request $request, NetworkService $networkService): JsonResponse
    {
        abort_if(
            $request->user()->role !== UserRole::AREA_MANAGER,
            403,
            'Menu UKM tim FGG hanya tersedia untuk Area Manager.',
        );

        return ApiListResponse::fromQueryWindow(
            $request,
            $networkService->queryTeamUkm(
                $request->user(),
                $request->string('q')->toString() ?: null,
            ),
            fn (NetworkProfile $profile) => FieldApiData::networkProfileListItem($profile),
        );
    }

    public function store(StoreNetworkProfileRequest $request, NetworkService $networkService): JsonResponse
    {
        $profile = $networkService->create($request->validated(), $request->user());

        return response()->json([
            'data' => FieldApiData::networkProfile($profile),
        ], 201);
    }

    public function update(
        UpdateNetworkProfileRequest $request,
        NetworkProfile $networkProfile,
        NetworkService $networkService,
    ): JsonResponse {
        $profile = $networkService->update($networkProfile, $request->validated(), $request->user());

        return response()->json([
            'data' => FieldApiData::networkProfile($profile),
        ]);
    }

    public function destroy(NetworkProfile $networkProfile, NetworkService $networkService): JsonResponse
    {
        $networkService->delete($networkProfile, request()->user());

        return response()->json([
            'data' => ['deleted' => true],
        ]);
    }

    public function storeFollowUp(
        StoreNetworkFollowUpRequest $request,
        NetworkProfile $networkProfile,
        NetworkService $networkService,
    ): JsonResponse {
        $profile = $networkService->appendFollowUp($networkProfile, $request->validated(), $request->user());

        return response()->json([
            'data' => FieldApiData::networkProfile($profile),
        ], 201);
    }
}
