<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\SurveyCommodityOption;
use App\Models\SurveyProductOption;
use App\Models\SurveyResponse;
use App\Support\Survey\SurveyType;
use App\Support\Workflow\UserRole;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\View\View;

class SurveyController extends Controller
{
    public function index(Request $request): View
    {
        $filters = $request->validate([
            'type' => ['nullable', 'string'],
            'search' => ['nullable', 'string'],
        ]);

        $responses = SurveyResponse::query()
            ->when($filters['type'] ?? null, fn ($query, string $type) => $query->where('type', $type))
            ->when($filters['search'] ?? null, function ($query, string $search): void {
                $query->where(function ($inner) use ($search): void {
                    $inner->where('user_name', 'like', '%' . $search . '%')
                        ->orWhere('area_name', 'like', '%' . $search . '%')
                        ->orWhere('territory_province', 'like', '%' . $search . '%')
                        ->orWhere('territory_city', 'like', '%' . $search . '%')
                        ->orWhere('territory_district', 'like', '%' . $search . '%')
                        ->orWhere('territory_subdistrict', 'like', '%' . $search . '%')
                        ->orWhere('payload->kiosk_name', 'like', '%' . $search . '%')
                        ->orWhere('payload->kiosk_address', 'like', '%' . $search . '%')
                        ->orWhere('payload->market_name', 'like', '%' . $search . '%')
                        ->orWhere('payload->location_address', 'like', '%' . $search . '%');
                });
            })
            ->latest('submitted_at')
            ->paginate(20)
            ->withQueryString();

        return view('admin.surveys.index', [
            'responses' => $responses,
            'filters' => $filters,
            'types' => SurveyType::LABELS,
            'roleLabels' => UserRole::LABELS,
            'products' => SurveyProductOption::query()->orderBy('name')->get(),
            'commodities' => SurveyCommodityOption::query()->orderBy('name')->get(),
        ]);
    }

    public function storeProduct(Request $request): RedirectResponse
    {
        $payload = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:survey_product_options,name'],
        ]);

        SurveyProductOption::query()->create([
            'id' => (string) Str::uuid(),
            'name' => $payload['name'],
            'is_active' => true,
        ]);

        return redirect()->route('admin.surveys.index')
            ->with('status', 'Produk survey kios berhasil ditambahkan.');
    }

    public function destroyProduct(SurveyProductOption $product): RedirectResponse
    {
        $product->delete();

        return redirect()->route('admin.surveys.index')
            ->with('status', 'Produk survey kios berhasil dihapus.');
    }

    public function storeCommodity(Request $request): RedirectResponse
    {
        $payload = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:survey_commodity_options,name'],
            'unit' => ['nullable', 'string', 'max:64'],
        ]);

        SurveyCommodityOption::query()->create([
            'id' => (string) Str::uuid(),
            'name' => $payload['name'],
            'unit' => $payload['unit'] ?? null,
            'is_active' => true,
        ]);

        return redirect()->route('admin.surveys.index')
            ->with('status', 'Komoditas survey harga berhasil ditambahkan.');
    }

    public function destroyCommodity(SurveyCommodityOption $commodity): RedirectResponse
    {
        $commodity->delete();

        return redirect()->route('admin.surveys.index')
            ->with('status', 'Komoditas survey harga berhasil dihapus.');
    }
}
