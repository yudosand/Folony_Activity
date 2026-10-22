<?php
namespace App\Services;
use App\Models\BusinessCategory;
use App\Models\BusinessKind;
use App\Models\NetworkProfile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BusinessCatalog {
    public const ICONS = ['store' => 'Toko', 'chicken' => 'Ayam', 'bowl' => 'Mangkuk', 'food' => 'Makanan', 'coffee' => 'Minuman', 'basket' => 'Bahan pangan', 'tools' => 'Jasa'];

    public static function normalize(string $text): string {
        $text = mb_strtolower(trim($text));
        $text = preg_replace('/\b(baso|bakso)\b/u', 'bakso', $text);
        $text = preg_replace('/\bklontong\b/u', 'kelontong', $text);
        $text = preg_replace('/\bmi ayam\b/u', 'mie ayam', $text);
        $text = preg_replace('/\bbakmie\b/u', 'bakmi', $text);
        return preg_replace('/\s+/u', ' ', $text);
    }

    public function options(): array {
        return BusinessCategory::where('active', true)->with(['kinds' => fn ($q) => $q->where('active', true)->orderBy('name')])
            ->orderBy('name')->get()->map(fn ($c) => ['id'=>$c->id, 'name'=>$c->name, 'color'=>$c->color,
                'kinds'=>$c->kinds->map(fn ($k) => ['id'=>$k->id, 'name'=>$k->name, 'icon'=>$k->icon])->values()])->all();
    }

    public function resolve(string $text): ?string {
        $normalized = self::normalize($text);
        $id = DB::table('business_aliases')->where('normalized', $normalized)->value('kind_id');
        if (!$id) return null;
        return BusinessKind::whereKey($id)->where('active', true)->whereHas('category', fn ($q) => $q->where('active', true))->value('id');
    }

    public function classify(array $payload, ?NetworkProfile $existing = null): array {
        if (!empty($payload['business_kind_id'])) {
            $kind = BusinessKind::with('category')->find($payload['business_kind_id']);
            if (!$kind || !$kind->active || !$kind->category->active || ($payload['business_category_id'] ?? '') !== $kind->category_id) {
                throw ValidationException::withMessages(['business_kind_id'=>'Pilih jenis usaha aktif yang sesuai kategori.']);
            }
            return ['business_kind_id'=>$kind->id, 'business_type'=>$kind->name];
        }
        if (!empty($payload['business_category_id'])) {
            throw ValidationException::withMessages(['business_kind_id'=>'Pilih jenis usaha setelah memilih kategori.']);
        }
        $text = $payload['business_type'] ?? $existing?->business_type ?? '';
        // Older APKs and CSV imports still send free text. Never silently misclassify it.
        return ['business_type'=>$text, 'business_kind_id'=> $existing && $text === $existing->business_type
            ? $existing->business_kind_id : $this->resolve($text)];
    }

    public static function marker(NetworkProfile $profile): array {
        $kind = $profile->businessKind;
        return ['category_id'=>$kind?->category_id, 'category_name'=>$kind?->category?->name ?? 'Perlu ditinjau',
            'kind_id'=>$kind?->id, 'kind_name'=>$kind?->name ?? $profile->business_type,
            'color'=>$kind?->category?->color ?? '#64748b', 'icon'=>$kind?->icon ?? 'store'];
    }
}
