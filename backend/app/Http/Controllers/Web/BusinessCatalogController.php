<?php
namespace App\Http\Controllers\Web;
use App\Http\Controllers\Controller;
use App\Models\BusinessCategory;
use App\Models\BusinessKind;
use App\Models\NetworkProfile;
use App\Services\BusinessCatalog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class BusinessCatalogController extends Controller {
    public function index(Request $r) {
        $r->validate(['category'=>['nullable','string'],'search'=>['nullable','string','max:120']]);
        return view('admin.business-catalog.index', [
            'categories'=>BusinessCategory::orderBy('name')->get(),
            'kinds'=>BusinessKind::with('category')->when($r->query('category'),fn($q,$v)=>$q->where('category_id',$v))
                ->when($r->query('search'),fn($q,$v)=>$q->where('name','like','%'.$v.'%'))->orderBy('name')->paginate(25)->withQueryString(),
            'review'=>NetworkProfile::without('businessKind')->whereNull('business_kind_id')->selectRaw('business_type, COUNT(*) as total')
                ->groupBy('business_type')->orderByDesc('total')->paginate(20, ['*'], 'review_page')->withQueryString(),
            'reviewCount'=>NetworkProfile::whereNull('business_kind_id')->count(),
            'options'=>app(BusinessCatalog::class)->options(), 'icons'=>BusinessCatalog::ICONS,
        ]);
    }
    public function category(Request $r, ?BusinessCategory $category = null) {
        $data = $r->validate(['name'=>['required','string','max:120',Rule::unique('business_categories')->ignore($category?->id)],
            'color'=>['required','regex:/^#[0-9a-fA-F]{6}$/'],'active'=>['required','boolean']]);
        if ($category) $category->update($data);
        else BusinessCategory::create($data+['id'=>(string)Str::uuid()]);
        return back()->with('status','Kategori usaha disimpan.');
    }
    public function kind(Request $r, ?BusinessKind $kind = null) {
        $data = $r->validate(['category_id'=>['required','exists:business_categories,id'],
            'name'=>['required','string','max:120',Rule::unique('business_kinds')->where('category_id',$r->input('category_id'))->ignore($kind?->id)],
            'icon'=>['required',Rule::in(array_keys(BusinessCatalog::ICONS))], 'active'=>['required','boolean']]);
        DB::transaction(function () use ($kind,$data) {
            if ($kind) $kind->update($data);
            else $kind = BusinessKind::create($data+['id'=>(string)Str::uuid()]);
            DB::table('business_aliases')->insertOrIgnore(['normalized'=>BusinessCatalog::normalize($kind->name),'kind_id'=>$kind->id]);
        });
        return back()->with('status','Jenis usaha disimpan.');
    }
    public function mapLegacy(Request $r) {
        $data=$r->validate(['source'=>['present','nullable','string','max:255'], 'business_category_id'=>['required','string'], 'business_kind_id'=>['required','string']]);
        $classification=app(BusinessCatalog::class)->classify($data);
        $count=DB::transaction(function () use ($data,$classification) {
            // Only unmapped rows with this exact legacy label; no fuzzy guessing.
            $ids=NetworkProfile::whereNull('business_kind_id')->where('business_type',$data['source'])->get(['id','business_type'])
                ->filter(fn($p)=>$p->business_type === $data['source'])->pluck('id');
            $count=DB::table('network_profiles')->whereNull('business_kind_id')->whereIn('id',$ids)->update(['business_kind_id'=>$classification['business_kind_id']]);
            if ($count > 0 && filled($data['source'])) DB::table('business_aliases')->updateOrInsert(['normalized'=>BusinessCatalog::normalize($data['source'])],['kind_id'=>$classification['business_kind_id']]);
            return $count;
        });
        return back()->with('status', $count.' profil dipetakan. Teks asli dan titik peta dipertahankan.');
    }
}
