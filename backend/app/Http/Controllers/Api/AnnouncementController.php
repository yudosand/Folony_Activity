<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnnouncementController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $role = $request->user()?->role;
        $announcements = Announcement::query()
            ->where('is_active', true)
            ->where(function ($query) use ($role): void {
                $query->whereNull('target_roles');

                if ($role !== null && $role !== '') {
                    $query->orWhereJsonContains('target_roles', $role);
                }
            })
            ->where(function ($query): void {
                $query
                    ->whereNull('published_at')
                    ->orWhere('published_at', '<=', now());
            })
            ->orderByDesc('published_at')
            ->orderByDesc('created_at')
            ->limit(5)
            ->get()
            ->map(fn (Announcement $announcement): array => [
                'id' => (string) $announcement->id,
                'title' => $announcement->title,
                'body' => $announcement->body,
                'published_at' => optional($announcement->published_at ?? $announcement->created_at)?->toIso8601String(),
            ])
            ->values();

        return response()->json(['data' => $announcements]);
    }
}
