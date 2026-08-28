<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Faq;
use Illuminate\Http\JsonResponse;

class FaqController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $items = Faq::query()
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->orderBy('title')
            ->get()
            ->map(fn (Faq $faq): array => [
                'id' => $faq->id,
                'title' => $faq->title,
                'body' => $faq->body,
                'sort_order' => $faq->sort_order,
            ])
            ->values();

        return response()->json(['data' => $items]);
    }
}
