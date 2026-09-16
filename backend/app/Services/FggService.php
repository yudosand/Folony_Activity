<?php

namespace App\Services;

use App\Models\FggAccount;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

class FggService
{
    public function environment(): string
    {
        $env = config('fgg.environment');
        abort_unless(in_array($env, ['staging', 'production'], true), 503, 'Environment FGG belum dikonfigurasi.');
        if ($env === 'production') {
            abort_unless(config('app.env') === 'production'
                && parse_url(config('app.url'), PHP_URL_HOST) === 'absent.folony.co.id',
                503, 'FGG production hanya tersedia pada server Folony production.');
        }
        return $env;
    }

    public function call(string $endpoint, array $data = [], ?FggAccount $account = null, bool $post = false): array
    {
        $base = $this->environment() === 'production' ? 'https://api.foodukm.com/app/' : 'https://dev.foodukm.com/app/';
        $http = Http::acceptJson()->connectTimeout(8)->timeout(20)->withoutRedirecting();
        if ($account) {
            abort_unless($account->environment === $this->environment() && $account->token, 409, 'Hubungkan ulang akun FGG.');
            $http = $http->withHeaders(['Authorization' => $account->token]);
        } else {
            $http = $http->asForm();
        }
        try {
            $response = $post ? $http->post($base.$endpoint, $data) : $http->get($base.$endpoint, $data);
        } catch (ConnectionException $e) {
            abort(504, $post && $account
                ? 'Hasil transaksi belum dapat dipastikan. Periksa status pengiriman sebelum mencoba kembali.'
                : 'FGG belum dapat dihubungi. Coba lagi.');
        }
        if (in_array($response->status(), [401, 403], true)) {
            $account?->update(['token' => null]);
            abort(409, 'Sesi FGG berakhir atau akses ditolak. Hubungkan ulang akun FGG.');
        }
        abort_unless($response->successful(), 502, 'FGG sedang bermasalah. Periksa status sebelum mengulangi transaksi.');
        $payload = $response->json();
        abort_unless(is_array($payload) && array_key_exists('statusCode', $payload), 502, 'Respons FGG tidak valid.');
        // Never relay upstream tokens, credentials, or arbitrary diagnostics to clients.
        $knownRejection = match ($payload['message'] ?? '') {
            'DST sudah pernah diterima HUB!' => 'DST sudah pernah diterima HUB. Muat ulang daftar kiriman.',
            'Pesanan sudah pernah dikirim!' => 'Pesanan sudah pernah dikirim. Muat ulang daftar kiriman.',
            default => null,
        };
        abort_unless((string) $payload['statusCode'] === '1', 422, $knownRejection ?? ($account
            ? 'Permintaan ditolak FGG. Periksa status barang atau hubungkan ulang akun.'
            : 'Login FGG gagal. Periksa akun dan kata sandi.'));
        return $payload;
    }
}
