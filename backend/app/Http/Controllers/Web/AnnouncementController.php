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

        $pushSummary = null;
        if ($announcement->is_active) {
            $pushSummary = $this->pushNotificationService->sendToUsers(
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
            ->with('status', $this->statusMessage($announcement->is_active, $pushSummary));
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

    /**
     * @param array{target_users:int,tokens:int,sent:int,failed:int,skipped_reason:string|null}|null $pushSummary
     */
    private function statusMessage(bool $isActive, ?array $pushSummary): string
    {
        if (! $isActive) {
            return 'Announcement disimpan sebagai nonaktif. Push notification tidak dikirim.';
        }

        if ($pushSummary === null) {
            return 'Announcement berhasil dipublikasikan.';
        }

        if ($pushSummary['skipped_reason'] !== null) {
            return 'Announcement berhasil dipublikasikan, tetapi push notification belum terkirim: '
                . $pushSummary['skipped_reason'];
        }

        return sprintf(
            'Announcement berhasil dipublikasikan. Push notification: %d terkirim, %d gagal, dari %d token untuk %d user target.',
            $pushSummary['sent'],
            $pushSummary['failed'],
            $pushSummary['tokens'],
            $pushSummary['target_users'],
        );
    }
}
