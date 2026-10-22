<div data-business-select class="grid cols-2" style="grid-column:1/-1">
    <div><label>Kategori usaha
        <select name="business_category_id" data-business-category @if($required ?? false) required @endif>
            <option value="">{{ ($required ?? false) ? 'Pilih kategori usaha' : 'Semua kategori usaha' }}</option>
            @if(!($required ?? false))<option value="unclassified" @selected(($selectedCategory ?? '') === 'unclassified')>Perlu ditinjau</option>@endif
            @foreach($businessOptions as $category)<option value="{{ $category['id'] }}" @selected(($selectedCategory ?? '') === $category['id'])>{{ $category['name'] }}</option>@endforeach
        </select>
    </label></div>
    <div><label>Jenis usaha
        <select name="business_kind_id" data-business-kind data-selected="{{ $selectedKind ?? '' }}" @if($required ?? false) required @endif><option value="">Pilih kategori dahulu</option></select>
    </label></div>
</div>
