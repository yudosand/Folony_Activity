<?php

namespace App\Support\Api;

use Closure;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

class ApiListResponse
{
    public static function fromQuery(Request $request, Builder $query, Closure $transform): JsonResponse
    {
        $perPage = self::perPage($request);
        if ($perPage === null) {
            $items = $query->get()->map($transform)->values();

            return response()->json([
                'data' => $items,
                'meta' => ['total' => $items->count()],
            ]);
        }

        $paginator = $query->paginate($perPage);

        return self::fromPaginator($paginator, $transform);
    }

    public static function fromCollection(
        Request $request,
        Collection $collection,
        Closure $transform,
    ): JsonResponse {
        $items = $collection->values();
        $perPage = self::perPage($request);
        if ($perPage === null) {
            return response()->json([
                'data' => $items->map($transform)->values(),
                'meta' => ['total' => $items->count()],
            ]);
        }

        $page = max(1, (int) $request->integer('page', 1));
        $offset = ($page - 1) * $perPage;
        $slice = $items->slice($offset, $perPage)->values();

        return response()->json([
            'data' => $slice->map($transform)->values(),
            'meta' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => $items->count(),
                'last_page' => (int) ceil(max(1, $items->count()) / $perPage),
            ],
        ]);
    }

    private static function fromPaginator(LengthAwarePaginator $page, Closure $transform): JsonResponse
    {
        return response()->json([
            'data' => collect($page->items())->map($transform)->values(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
                'last_page' => $page->lastPage(),
            ],
        ]);
    }

    private static function perPage(Request $request): ?int
    {
        if (! $request->filled('per_page')) {
            return null;
        }

        return min(100, max(1, (int) $request->integer('per_page', 15)));
    }
}
