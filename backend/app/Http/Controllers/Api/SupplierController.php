<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSupplierRequest;
use App\Models\Supplier;
use App\Support\Workflow\UserRole;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    private function authorizeRole(Request $request): void
    {
        abort_unless(in_array($request->user()->role, [UserRole::SPV, UserRole::MANAGEMENT, UserRole::AREA_MANAGER], true), 403);
    }

    public function index(Request $request): JsonResponse
    {
        $this->authorizeRole($request);
        $request->validate(['page' => ['sometimes', 'integer', 'min:1'], 'q' => ['nullable', 'string', 'max:255']]);
        $query = Supplier::where('created_by', $request->user()->id);
        if ($search = trim((string) $request->query('q', ''))) {
            $query->where('name', 'like', '%'.$search.'%');
        }
        $page = $query->orderByDesc('created_at')->orderByDesc('id')->paginate(20);

        return response()->json(['data' => $page->items(), 'meta' => [
            'current_page' => $page->currentPage(), 'has_more' => $page->hasMorePages(), 'total' => $page->total(),
        ]]);
    }

    public function show(Request $request, Supplier $supplier): JsonResponse
    {
        $this->authorizeRole($request);
        abort_unless($supplier->created_by === $request->user()->id, 404);

        return response()->json(['data' => $supplier]);
    }

    public function store(StoreSupplierRequest $request): JsonResponse
    {
        $supplier = new Supplier($request->validated());
        $supplier->created_by = $request->user()->id;
        $supplier->save();

        return response()->json(['data' => $supplier], 201);
    }
}
