<?php

namespace App\Services;

use App\Support\Workflow\UserRole;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class FieldActivityReport
{
    public function query(array $filters = []): Builder
    {
        $roles = [UserRole::FGG, UserRole::AREA_MANAGER];
        $profiles = DB::table('network_profiles as p')->whereIn('p.owner_role', $roles)->selectRaw("
            p.id as event_id, 'created' as source, p.owner_id as actor_id, p.owner_name as actor_name,
            p.owner_role as actor_role, p.created_at as occurred_at,
            CASE WHEN p.type = 'mitra' THEN 'Tambah MITRA Baru' ELSE 'Tambah UKM Baru' END as activity_label,
            p.name as profile_name, p.type as profile_type, p.address, p.area_name,
            p.latitude, p.longitude, p.business_type as detail, NULL as note,
            p.photo_attachment as photo, NULL as started_at, NULL as finished_at, NULL as duration_seconds,
            'Lokasi profil' as location_source, NULL as accuracy_meters, NULL as captured_at");
        $visits = DB::table('network_follow_ups as f')->join('users as u', 'u.id', '=', 'f.actor_id')
            ->leftJoin('network_profiles as p', 'p.id', '=', 'f.network_profile_id')->whereIn('u.role', $roles)->selectRaw("
            f.id as event_id, 'visits' as source, f.actor_id, f.actor_name, u.role as actor_role, f.created_at as occurred_at,
            CASE WHEN p.type = 'mitra' THEN 'Kunjungan Mitra' ELSE 'Kunjungan UKM' END as activity_label,
            COALESCE(p.name, f.network_profile_id) as profile_name, p.type as profile_type, p.address, p.area_name,
            p.latitude, p.longitude, f.title as detail, f.note, f.photo_attachment as photo,
            f.visit_started_at as started_at, f.visit_finished_at as finished_at, f.visit_duration_seconds as duration_seconds,
            'Lokasi profil' as location_source, NULL as accuracy_meters, NULL as captured_at");
        $shipping = DB::table('fgg_operations as o')->leftJoin('users as u', 'u.id', '=', 'o.user_id')
            ->leftJoin('fgg_delivery_trips as t', function ($join) {
                $join->on('t.environment', '=', 'o.environment')->on('t.member_id', '=', 'o.member_id')
                    ->on('t.target', '=', 'o.target')->on('t.user_id', '=', 'o.user_id')->on('t.hub_id', '=', 'o.hub_id')
                    ->where('o.action', '=', 'send');
            })
            ->where('o.state', 'succeeded')->where('o.environment', config('fgg.environment'))->selectRaw("
            o.id as event_id, 'shipping' as source, o.user_id as actor_id, COALESCE(u.full_name, o.user_id) as actor_name,
            u.role as actor_role, o.updated_at as occurred_at,
            CASE WHEN o.action = 'receive' THEN 'Terima DST' ELSE 'Kirim Pesanan' END as activity_label,
            o.hub_id as profile_name, 'HUB' as profile_type, NULL as address, NULL as area_name,
            o.latitude, o.longitude, o.target as detail, NULL as note, o.proof_path as photo,
            t.started_at as started_at, t.arrived_at as finished_at, NULL as duration_seconds,
            'GPS perangkat' as location_source, o.accuracy_meters, o.captured_at");
        $query = DB::query()->fromSub($profiles->unionAll($visits)->unionAll($shipping), 'events');
        if (! empty($filters['owner_role'])) {
            $query->where('actor_role', $filters['owner_role']);
        }
        if (! empty($filters['date_from'])) {
            $query->where('occurred_at', '>=', Carbon::parse($filters['date_from'])->startOfDay());
        }
        if (! empty($filters['date_until'])) {
            $query->where('occurred_at', '<=', Carbon::parse($filters['date_until'])->endOfDay());
        }
        if (! empty($filters['search'])) {
            $query->where(function (Builder $q) use ($filters) {
                foreach (['actor_name', 'profile_name', 'address', 'area_name', 'detail', 'note', 'activity_label'] as $field) {
                    $q->orWhere($field, 'like', '%'.$filters['search'].'%');
                }
            });
        }

        return $query;
    }

    public function events(string $actor, string $date): Collection
    {
        return $this->query(['date_from' => $date, 'date_until' => $date])->where('actor_id', $actor)
            ->orderByRaw('COALESCE(started_at, occurred_at)')->orderBy('source')->orderBy('event_id')->get()
            ->map(function ($row) {
                $event = (array) $row;
                foreach (['occurred_at', 'started_at', 'finished_at', 'captured_at'] as $key) {
                    $event[$key] = $row->$key ? Carbon::parse($row->$key) : null;
                }
                $event['actor_role'] = UserRole::label((string) $row->actor_role);
                $event['photo'] = $row->source === 'shipping'
                    ? ($row->photo ? ['url' => route('admin.network.activities.proof', $row->event_id)] : null)
                    : ($row->photo ? json_decode($row->photo, true) : null);
                $event['profile_type'] = strtoupper((string) $row->profile_type);
                $valid = is_numeric($row->latitude) && is_numeric($row->longitude)
                    && abs((float) $row->latitude) <= 90 && abs((float) $row->longitude) <= 180;
                $event['latitude'] = $valid ? (float) $row->latitude : null;
                $event['longitude'] = $valid ? (float) $row->longitude : null;
                $event['duration_label'] = $this->duration($row->duration_seconds === null ? null : max(0, (int) $row->duration_seconds));
                if ($row->source === 'shipping' && $event['started_at'] && $event['finished_at']) {
                    $event['duration_seconds'] = max(0, (int) $event['started_at']->diffInSeconds($event['finished_at']));
                    $event['duration_label'] = $this->duration($event['duration_seconds']);
                }
                if ($row->source === 'shipping') {
                    $event['detail'] = ($row->activity_label === 'Terima DST' ? 'DST ' : 'Pesanan ').$row->detail.' · Berhasil';
                    $event['address'] = $valid ? sprintf('GPS %.6f, %.6f', $row->latitude, $row->longitude) : 'Lokasi tidak tercatat';
                }

                return $event;
            });
    }

    public function day(Collection $events, string $date): array
    {
        // Merge recorded visit intervals so overlapping visits do not inflate working time.
        $intervals = [];
        $fallback = 0;
        $known = false;
        foreach ($events as $event) {
            if (! in_array($event['source'], ['visits', 'shipping'])) {
                continue;
            }
            $start = $event['started_at'];
            $end = $event['finished_at'];
            if ($start && $end && $end->gte($start)) {
                $known = true;
                $intervals[] = [$start->timestamp, $end->timestamp];
            } elseif ($event['duration_seconds'] !== null) {
                $known = true;
                $fallback += max(0, (int) $event['duration_seconds']);
            }
        }
        sort($intervals);
        $seconds = $fallback;
        $end = null;
        foreach ($intervals as [$from, $until]) {
            $seconds += max(0, $until - max($from, $end ?? $from));
            $end = max($end ?? $until, $until);
        }

        return [
            'actor_id' => $events->first()['actor_id'], 'actor_name' => $events->first()['actor_name'],
            'actor_role' => $events->first()['actor_role'], 'date' => $date, 'count' => $events->count(),
            'activities' => $events->pluck('activity_label')->countBy(),
            'profiles' => $events->pluck('profile_name')->filter()->unique()->values(),
            'locations' => $events->pluck('address')->filter()->unique()->values(),
            'duration_label' => $this->duration($known ? $seconds : null),
            'duration_seconds' => $known ? $seconds : null,
            'located' => $events->whereNotNull('latitude')->count(),
        ];
    }

    private function duration(?int $seconds): ?string
    {
        if ($seconds === null) {
            return null;
        }
        $parts = [];
        if ($seconds >= 3600) {
            $parts[] = intdiv($seconds, 3600).'j';
        }
        if ($seconds >= 60) {
            $parts[] = intdiv($seconds % 3600, 60).'m';
        }
        if ($seconds % 60 || ! $parts) {
            $parts[] = ($seconds % 60).'d';
        }

        return implode(' ', $parts);
    }
}
