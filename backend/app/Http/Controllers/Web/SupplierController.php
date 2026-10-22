<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSupplierRequest;
use App\Models\Supplier;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    private function filtered(Request $request): Builder
    {
        $request->validate(['search' => ['nullable', 'string', 'max:255'],
            'needs' => ['nullable', 'string', 'max:255'],
            'province' => ['nullable', 'string', 'max:255'], 'city' => ['nullable', 'string', 'max:255'],
            'district' => ['nullable', 'string', 'max:255'], 'after' => ['nullable', 'uuid']]);
        $query = Supplier::query();
        foreach (['province', 'city', 'district'] as $level) {
            if ($value = $request->query($level)) $query->where('territory_'.$level, $value);
        }
        if ($search = trim((string) $request->query('search', ''))) {
            $query->where(function (Builder $q) use ($search) {
                $q->where('name', 'like', '%'.$search.'%')->orWhere('pic_name', 'like', '%'.$search.'%')->orWhereHas('creator', fn ($c) => $c->where('full_name', 'like', '%'.$search.'%'));
            });
        }

        if ($needs = trim((string) $request->query('needs', ''))) {
            // Search each item, treating user-entered % and _ as literal characters.
            $pattern = '%'.str_replace(['!', '%', '_'], ['!!', '!%', '!_'], mb_strtolower($needs)).'%';
            if ($query->getConnection()->getDriverName() === 'sqlite') {
                $query->whereRaw("EXISTS (SELECT 1 FROM json_each(suppliers.items) WHERE LOWER(json_each.value) LIKE ? ESCAPE '!')", [$pattern]);
            } else {
                $query->whereRaw("JSON_SEARCH(LOWER(items), 'one', ?, '!') IS NOT NULL", [$pattern]);
            }
        }

        return $query;
    }

    public function index(Request $request)
    {
        $query = $this->filtered($request);
        $filters = $request->only(['province', 'city', 'district', 'search', 'needs']);
        $regions = Supplier::select('territory_province', 'territory_city', 'territory_district')->distinct()->get();

        return view('admin.suppliers.index', [
            'suppliers' => $query->with('creator')->orderByDesc('created_at')->orderByDesc('id')->paginate(25)->withQueryString(),
            'filters' => $filters, 'regions' => $regions,
        ]);
    }

    public function create()
    {
        return view('admin.suppliers.create');
    }

    public function store(StoreSupplierRequest $request)
    {
        $supplier = new Supplier($request->validated());
        $supplier->created_by = $request->user()->id;
        $supplier->save();

        return redirect()->route('admin.suppliers.show', $supplier)->with('status', 'Supplier berhasil ditambahkan.');
    }

    public function show(Supplier $supplier)
    {
        return view('admin.suppliers.show', ['supplier' => $supplier->load('creator')]);
    }

    public function mapPoints(Request $request)
    {
        $query = $this->filtered($request);
        $total = (clone $query)->count();
        $query->whereBetween('latitude', [-90, 90])->whereBetween('longitude', [-180, 180]);
        $mapped = (clone $query)->count();
        if ($after = $request->query('after')) $query->where('id', '>', $after);
        $rows = $query->with('creator')->orderBy('id')->limit(1001)->get();
        $hasMore = $rows->count() > 1000;
        $rows = $rows->take(1000);

        return response()->json(['data' => $rows->map(fn (Supplier $s) => [
            'id' => $s->id, 'name' => $s->name, 'type' => 'supplier', 'status' => implode(', ', $s->items),
            'owner' => 'PIC supplier: '.($s->pic_name ?: 'Belum diisi').' · Pembuat: '.($s->creator?->full_name ?? '—'),
            'area' => implode(', ', array_filter([$s->territory_district, $s->territory_city, $s->territory_province])),
            'address' => $s->address, 'latitude' => $s->latitude, 'longitude' => $s->longitude,
            'detail_url' => route('admin.suppliers.show', $s),
        ])->values(), 'meta' => ['total' => $total, 'mapped' => $mapped, 'unmapped' => $total - $mapped,
            'next_cursor' => $hasMore ? $rows->last()->id : null]]);
    }
}
