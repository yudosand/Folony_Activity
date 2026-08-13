<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AnnouncementController extends Controller
{
    public function index(): View
    {
        return view('admin.announcements.index', [
            'announcements' => Announcement::query()
                ->orderByDesc('published_at')
                ->orderByDesc('created_at')
                ->paginate(20),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $payload = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:2000'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        Announcement::query()->create([
            'title' => $payload['title'],
            'body' => $payload['body'],
            'is_active' => (bool) ($payload['is_active'] ?? false),
            'published_at' => now(),
        ]);

        return redirect()
            ->route('admin.announcements.index')
            ->with('status', 'Announcement berhasil dipublikasikan.');
    }

    public function destroy(Announcement $announcement): RedirectResponse
    {
        $announcement->delete();

        return redirect()
            ->route('admin.announcements.index')
            ->with('status', 'Announcement berhasil dihapus.');
    }
}
