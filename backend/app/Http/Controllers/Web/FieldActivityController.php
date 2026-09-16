<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\FggOperation;
use App\Services\FieldActivityReport;
use App\Support\Workflow\UserRole;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class FieldActivityController extends Controller
{
    public function proof(FggOperation $operation)
    {
        abort_unless($operation->state === 'succeeded' && $operation->action === 'send'
            && $operation->environment === config('fgg.environment')
            && preg_match('~^fgg-delivery-proofs/[a-f0-9-]+\.(jpg|png)$~', $operation->proof_path ?? ''), 404);
        $disk = Storage::disk('local');
        abort_unless($disk->exists($operation->proof_path), 404);

        return $disk->response($operation->proof_path, null, [
            'Content-Type' => str_ends_with($operation->proof_path, '.png') ? 'image/png' : 'image/jpeg',
            'Cache-Control' => 'private, no-store', 'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function index(Request $request, FieldActivityReport $report): View
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'], 'owner_role' => ['nullable', 'string'],
            'date_from' => ['nullable', 'date_format:Y-m-d'], 'date_until' => ['nullable', 'date_format:Y-m-d'],
        ]);
        if (! empty($filters['date_from']) && ! empty($filters['date_until']) && $filters['date_from'] > $filters['date_until']) {
            [$filters['date_from'], $filters['date_until']] = [$filters['date_until'], $filters['date_from']];
        }
        $query = $report->query($filters);
        $counts = (clone $query)->selectRaw('source, COUNT(*) as total')->groupBy('source')->pluck('total', 'source');
        $days = (clone $query)->selectRaw('actor_id, DATE(occurred_at) as activity_date, MAX(occurred_at) as latest_at')
            ->whereNotNull('actor_id')->groupBy('actor_id')->groupByRaw('DATE(occurred_at)')
            ->orderByDesc('activity_date')->orderByDesc('latest_at')->orderBy('actor_id')->paginate(30)->withQueryString();
        // Search selects matching days. A selected day always includes all of that person's activities.
        $days->setCollection($days->getCollection()->map(fn ($day) => $report->day($report->events($day->actor_id, $day->activity_date), $day->activity_date)));

        return view('admin.network.activities', [
            'days' => $days, 'filters' => $filters,
            'ownerRoles' => [UserRole::FGG => UserRole::label(UserRole::FGG), UserRole::AREA_MANAGER => UserRole::label(UserRole::AREA_MANAGER)],
            'summary' => ['total' => $counts->sum(), 'created' => (int) ($counts['created'] ?? 0),
                'visits' => (int) ($counts['visits'] ?? 0), 'shipping' => (int) ($counts['shipping'] ?? 0)],
        ]);
    }

    public function show(string $employee, string $date, FieldActivityReport $report): View
    {
        abort_unless(preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) && checkdate((int) substr($date, 5, 2), (int) substr($date, 8, 2), (int) substr($date, 0, 4)), 404);
        $events = $report->events($employee, $date);
        abort_if($events->isEmpty(), 404);

        return view('admin.network.activity-day', ['events' => $events, 'day' => $report->day($events, $date)]);
    }
}
