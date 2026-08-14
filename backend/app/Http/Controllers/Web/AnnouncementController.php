<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\User;
use App\Services\PushNotificationService;
use App\Support\Workflow\UserRole;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class AnnouncementController extends Controller
{
    public function __construct(
        private readonly PushNotificationService $pushNotificationService,
    ) {}

    public function index(): View
    {
        return view('admin.announcements.index', [
            'announcements' => Announcement::query()
                ->orderByDesc('published_at')
                ->orderByDesc('created_at')
                ->paginate(20),
            'roleOptions' => UserRole::adminOptions(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $payload = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:2000'],
            'target_roles' => ['nullable', 'array'],
            'target_roles.*' => ['string', Rule::in(array_keys(UserRole::adminOptions()))],
            'is_active' => ['nullable', 'boolean'],
        ]);
        $targetRoles = array_values(array_unique($payload['target_roles'] ?? []));

        $announcement = Announcement::query()->create([
            'title' => $payload['title'],
            'body' => $payload['body'],
            'target_roles' => $targetRoles === [] ? null : $targetRoles,
            'is_active' => (bool) ($payload['is_active'] ?? false),
            'published_at' => now(),
        ]);

        if ($announcement->is_active) {
            $this->pushNotificationService->sendToUsers(
                $this->targetUserIds($targetRoles),
                title: 'Announcement HR: ' . $announcement->title,
                body: Str::limit($announcement->body, 120),
                data: [
                    'type' => 'announcement',
                    'announcement_id' => (string) $announcement->id,
                ],
            );
        }

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

    /**
     * @param array<int, string> $targetRoles
     * @return array<int, string>
     */
    private function targetUserIds(array $targetRoles): array
    {
        $roles = $targetRoles === []
            ? array_keys(UserRole::adminOptions())
            : $targetRoles;

        return User::query()
            ->where('is_active', true)
            ->whereIn('role', $roles)
            ->pluck('id')
            ->values()
            ->all();
    }
}
