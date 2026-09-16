<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FggAccount;
use App\Services\FggService;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

class FggController extends Controller
{
    public function __construct(private FggService $fgg) {}

    private function account(Request $request, bool $selected = true): FggAccount
    {
        $account = FggAccount::where('user_id', $request->user()->id)->where('environment', $this->fgg->environment())->first();
        abort_unless($account && $account->token, 409, 'Hubungkan akun FGG terlebih dahulu.');
        $this->expire($account);
        abort_unless($account->token, 409, 'Sesi FGG berakhir. Hubungkan ulang akun FGG.');
        if ($selected) {
            abort_unless(collect($account->hubs)->contains(fn ($hub) => $hub['id'] === $account->hub_id), 409, 'Pilih akun HUB terlebih dahulu.');
            // The supplied API has no hub switch contract. Do not imply that local
            // selection scopes a multi-hub token on the upstream server.
            abort_unless(count($account->hubs) === 1, 409, 'Akun memiliki beberapa HUB. Pemilihan HUB memerlukan dukungan API FGG.');
        }

        return $account;
    }

    private function session(?FggAccount $account): array
    {
        if ($account) {
            $this->expire($account);
        }

        return ['connected' => (bool) $account?->token, 'environment' => $this->fgg->environment(),
            'name' => $account?->name, 'hubs' => $account?->hubs ?? [], 'hub_id' => $account?->hub_id];
    }

    private function expire(FggAccount $account): void
    {
        if (! $account->token) {
            return;
        }
        $parts = explode('.', $account->token);
        $claims = json_decode(base64_decode(strtr($parts[1] ?? '', '-_', '+/')), true);
        // This is only an expiry hint; upstream still authenticates every request.
        if (is_array($claims) && isset($claims['exp']) && is_numeric($claims['exp']) && $claims['exp'] <= time()) {
            $account->update(['token' => null]);
        }
    }

    public function show(Request $request)
    {
        return response()->json(['data' => $this->session(FggAccount::where('user_id', $request->user()->id)
            ->where('environment', $this->fgg->environment())->first())]);
    }

    public function connect(Request $request)
    {
        $data = $request->validate(['fuserid' => 'required|string|max:150', 'fpassword' => 'required|string|max:255',
            'idDevice' => 'required|string|max:200', 'lat' => 'nullable|numeric|between:-90,90',
            'long' => 'nullable|numeric|between:-180,180', 'os_version' => 'nullable|string|max:100']);
        $payload = $this->fgg->call('api_login', [...$data, 'fcm_token' => ''], post: true);
        $result = $payload['result'] ?? [];
        $hubs = collect($result['otherUser'] ?? [])->filter(fn ($hub) => is_array($hub) && ($hub['userRole'] ?? '') === 'HUB' && ! empty($hub['id']))
            ->map(fn ($hub) => ['id' => (string) $hub['id'], 'name' => (string) ($hub['name'] ?? $hub['id'])])->unique('id')->values()->all();
        abort_if(empty($hubs), 403, 'Akun ini tidak memiliki role HUB untuk FGG.');
        abort_unless(is_string($result['token'] ?? null) && $result['token'] !== '' && isset($result['idmember']), 502, 'Respons login FGG tidak lengkap.');
        $account = FggAccount::updateOrCreate(['user_id' => $request->user()->id, 'environment' => $this->fgg->environment()],
            ['member_id' => (string) $result['idmember'], 'name' => (string) ($result['name'] ?? ''),
                'token' => $result['token'], 'hubs' => $hubs, 'hub_id' => null]);

        return response()->json(['data' => $this->session($account)]);
    }

    public function select(Request $request)
    {
        $data = $request->validate(['hub_id' => 'required|string|max:100']);
        $account = $this->account($request, false);
        abort_unless(collect($account->hubs)->contains(fn ($hub) => $hub['id'] === $data['hub_id']), 403, 'HUB tidak tersedia untuk akun ini.');
        abort_unless(count($account->hubs) === 1, 409, 'Akun memiliki beberapa HUB. Pemilihan HUB memerlukan dukungan API FGG.');
        $account->update($data);

        return response()->json(['data' => $this->session($account)]);
    }

    public function disconnect(Request $request)
    {
        FggAccount::where('user_id', $request->user()->id)->where('environment', $this->fgg->environment())->delete();

        return response()->json(['data' => $this->session(null)]);
    }

    public function listing(Request $request, string $kind)
    {
        $data = $request->validate(['search' => 'nullable|string|max:150', 'status' => 'nullable|integer|between:0,4',
            'pagination' => 'nullable|integer|min:0|max:100000', 'location' => 'nullable|string|max:150']);
        $endpoint = $kind === 'dst' ? 'api_hub_list_dst' : 'api_list_daftar_kiriman_hub';
        $payload = $this->fgg->call($endpoint, $data, $this->account($request));

        return response()->json(['data' => $payload['result'] ?? [], 'page' => (int) ($payload['pagination'] ?? 1),
            'total_pages' => (int) ($payload['totalPage'] ?? 1)]);
    }

    public function detail(Request $request, string $kind, string $id)
    {
        $dpp = $kind === 'dpp';
        $payload = $this->fgg->call($dpp ? 'api_hub_detail_dpp' : 'api_hub_detail_pesanan',
            [$dpp ? 'no_dpp' : 'transaction_id' => $id], $this->account($request));

        return response()->json(['data' => $payload['result'] ?? []]);
    }

    public function action(Request $request, string $action)
    {
        $location = $request->validate([
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'accuracy_meters' => 'required|numeric|between:0,100000',
            'captured_at' => 'required|date',
        ]);
        $capturedAt = Carbon::parse($location['captured_at']);
        abort_if($capturedAt->lt(now()->subMinutes(2)) || $capturedAt->gt(now()->addSeconds(30)),
            422, 'Lokasi GPS sudah kedaluwarsa. Ambil lokasi terbaru dan coba lagi.');
        $location['captured_at'] = $capturedAt->utc()->format('Y-m-d H:i:s');
        $receive = $action === 'receive';
        $data = $request->validate($receive ? ['no_dst' => 'required|integer|min:1']
            : ['transaction_id' => 'required|integer|min:1', 'buktiFoto' => 'required|string|max:7000000']);
        if (! $receive) {
            $bytes = base64_decode($data['buktiFoto'], true);
            $info = $bytes === false ? false : @getimagesizefromstring($bytes);
            abort_unless($info && in_array($info[2], [IMAGETYPE_JPEG, IMAGETYPE_PNG], true), 422, 'Foto bukti harus JPEG atau PNG yang valid.');
        }
        $account = $this->account($request);
        $target = (string) $data[$receive ? 'no_dst' : 'transaction_id'];
        if (! $receive) {
            $trip = DB::table('fgg_delivery_trips')->where('environment', $account->environment)
                ->where('member_id', $account->member_id)->where('target', $target)->first();
            if ($trip) {
                abort_unless($trip->user_id === $request->user()->id && $trip->hub_id === $account->hub_id, 409, 'Perjalanan ditangani akun lain.');
                abort_unless($trip->arrived_at, 422, 'Catat tiba di tujuan sebelum mengirim bukti penyerahan.');
            }
        }
        $key = ['environment' => $account->environment, 'member_id' => $account->member_id, 'action' => $action, 'target' => $target];
        $inserted = DB::table('fgg_operations')->insertOrIgnore([...$key, ...$location, 'user_id' => $request->user()->id,
            'hub_id' => $account->hub_id, 'state' => 'pending', 'created_at' => now(), 'updated_at' => now()]);
        if (! $inserted) {
            $state = DB::table('fgg_operations')->where($key)->value('state');
            if ($state === 'succeeded') {
                return response()->json(['message' => 'Transaksi sudah berhasil diproses.']);
            }
            $retry = $state === 'rejected' && DB::table('fgg_operations')->where($key)->where('state', 'rejected')
                ->update([...$location, 'state' => 'pending', 'user_id' => $request->user()->id, 'updated_at' => now()]);
            abort_unless($retry, 409, 'Transaksi sudah pernah dikirim. Periksa status di FGG sebelum tindakan lanjutan.');
        }
        // Save before contacting FGG: a local storage failure must never send the order.
        if (! $receive) {
            try {
                $path = 'fgg-delivery-proofs/'.Str::uuid().($info[2] === IMAGETYPE_JPEG ? '.jpg' : '.png');
                if (! Storage::disk('local')->put($path, $bytes)) {
                    throw new \RuntimeException('Unable to store delivery proof.');
                }
                DB::table('fgg_operations')->where($key)->update(['proof_path' => $path]);
            } catch (\Throwable $e) {
                DB::table('fgg_operations')->where($key)->update(['state' => 'rejected', 'updated_at' => now()]);
                report($e);
                abort(503, 'Foto bukti belum dapat disimpan. Pesanan belum dikirim, silakan coba lagi.');
            }
        }
        try {
            $this->fgg->call($receive ? 'api_hub_terima_dst' : 'api_hub_kirim_pesanan', $data, $account, true);
        } catch (\Throwable $e) {
            $rejected = $e instanceof HttpExceptionInterface
                && in_array($e->getStatusCode(), [422, 409], true);
            DB::table('fgg_operations')->where($key)->update(['state' => $rejected ? 'rejected' : 'unknown', 'updated_at' => now()]);
            throw $e;
        }
        DB::table('fgg_operations')->where($key)->update(['state' => 'succeeded', 'updated_at' => now()]);
        if (! $receive) {
            DB::table('fgg_delivery_trips')->where('environment', $account->environment)
                ->where('member_id', $account->member_id)->where('hub_id', $account->hub_id)
                ->where('user_id', $request->user()->id)->where('target', $target)->whereNull('completed_at')
                ->update(['completed_at' => now(), 'updated_at' => now()]);
        }

        return response()->json(['message' => 'Transaksi berhasil diproses.']);
    }

    public function trip(Request $request, string $id)
    {
        $account = $this->account($request);
        $query = DB::table('fgg_delivery_trips')->where('environment', $account->environment)
            ->where('member_id', $account->member_id)->where('target', $id);
        $trip = (clone $query)->first();
        if ($trip) {
            abort_unless($trip->user_id === $request->user()->id && $trip->hub_id === $account->hub_id, 409,
                'Perjalanan pesanan ini sudah ditangani akun lain.');
        }
        if ($request->isMethod('post')) {
            abort_unless($request->user()->role === 'fgg', 403, 'Perjalanan pengiriman hanya untuk FGG.');
            $data = $request->validate(['action' => 'required|in:start,arrive',
                'latitude' => 'required|numeric|between:-90,90', 'longitude' => 'required|numeric|between:-180,180',
                'accuracy_meters' => 'required|numeric|between:0,100000', 'captured_at' => 'required|date']);
            $captured = Carbon::parse($data['captured_at']);
            abort_if($captured->lt(now()->subMinutes(2)) || $captured->gt(now()->addSeconds(30)), 422, 'Ambil lokasi GPS terbaru.');
            $location = json_encode(Arr::except($data, ['action']));
            if ($data['action'] === 'start' && ! $trip) {
                $operation = DB::table('fgg_operations')->where('environment', $account->environment)
                    ->where('member_id', $account->member_id)->where('target', $id)->where('action', 'send')->first();
                abort_if($operation && $operation->state !== 'rejected', 409, 'Pesanan sudah diproses. Periksa status kiriman.');
                $payload = $this->fgg->call('api_hub_detail_pesanan', ['transaction_id' => $id], $account);
                $result = $payload['result'] ?? [];
                $record = array_is_list($result) ? ($result[0] ?? []) : $result;
                $address = trim((string) ($record['senders_address'] ?? ''));
                abort_if($address === '' || strlen($address) > 4000, 422, 'Alamat tujuan pembeli belum tersedia pada pesanan.');
                if (isset($record['status'])) {
                    abort_unless(in_array(strtolower((string) $record['status']), ['1', 'orders_ready', 'order_ready']), 409, 'Pesanan tidak berstatus siap dikirim.');
                }
                DB::table('fgg_delivery_trips')->insertOrIgnore(['environment' => $account->environment,
                    'member_id' => $account->member_id, 'hub_id' => $account->hub_id, 'user_id' => $request->user()->id,
                    'target' => $id, 'destination_address' => $address, 'started_at' => now(), 'start_location' => $location,
                    'created_at' => now(), 'updated_at' => now()]);
            } elseif ($data['action'] === 'arrive') {
                abort_unless($trip, 409, 'Mulai perjalanan terlebih dahulu.');
                abort_if($trip->completed_at && ! $trip->arrived_at, 409, 'Pengiriman telah selesai tanpa catatan waktu tiba.');
                $query->whereNull('arrived_at')->update(['arrived_at' => now(), 'arrival_location' => $location, 'updated_at' => now()]);
            }
            $trip = DB::table('fgg_delivery_trips')->where('environment', $account->environment)
                ->where('member_id', $account->member_id)->where('target', $id)->first();
            abort_unless($trip && $trip->user_id === $request->user()->id && $trip->hub_id === $account->hub_id, 409, 'Perjalanan ditangani akun lain.');
        }

        return response()->json(['data' => $trip ? [
            'started_at' => Carbon::parse($trip->started_at)->toIso8601String(),
            'arrived_at' => $trip->arrived_at ? Carbon::parse($trip->arrived_at)->toIso8601String() : null,
            'completed_at' => $trip->completed_at ? Carbon::parse($trip->completed_at)->toIso8601String() : null,
            'duration_seconds' => $trip->arrived_at ? (int) Carbon::parse($trip->started_at)->diffInSeconds(Carbon::parse($trip->arrived_at)) : null,
            'destination_address' => $trip->destination_address,
        ] : null]);
    }
}
