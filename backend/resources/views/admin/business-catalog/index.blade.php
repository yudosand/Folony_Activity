@extends('admin.layouts.app')
@php $heading = $title = 'Master Jenis Usaha'; $subheading = 'Kategori, ikon dan pemetaan data UKM/Mitra.'; $businessOptions = $options; @endphp
@section('content')
<div class="actions" style="margin-bottom:18px">
    <a class="btn secondary" href="{{ route('admin.network.index') }}">Kembali ke Monitoring Jaringan</a>
</div>
@if($errors->any())<div class="status-banner" role="alert">{{ $errors->first() }}</div>@endif
<div class="panel pad" style="margin-bottom:18px">
    <h3>Kategori usaha</h3>
    <p class="muted">Warna mengikuti kategori; ikon mengikuti jenis usaha. Menonaktifkan master menghentikan pilihan baru, data lama tetap tersimpan.</p>
    @foreach($categories as $category)
    <details class="disclosure" style="margin-bottom:8px"><summary><span style="color:{{ $category->color }}">●</span> {{ $category->name }} {{ $category->active ? '' : '(Nonaktif)' }}</summary>
        <form class="disclosure-body grid cols-2" method="POST" action="{{ route('admin.business-catalog.category',$category) }}">@csrf
            <label>Nama kategori<input name="name" maxlength="120" value="{{ $category->name }}" required></label>
            <label>Warna<input name="color" type="color" value="{{ $category->color }}" required></label>
            <label>Status<select name="active"><option value="1" @selected($category->active)>Aktif</option><option value="0" @selected(!$category->active)>Nonaktif</option></select></label>
            <div><button class="btn primary">Simpan kategori</button></div>
        </form>
    </details>@endforeach
    <details class="disclosure"><summary>Tambah kategori</summary><form class="disclosure-body grid cols-2" method="POST" action="{{ route('admin.business-catalog.category') }}">@csrf
        <label>Nama kategori<input name="name" maxlength="120" required></label><label>Warna<input type="color" name="color" value="#2563eb" required></label><input name="active" type="hidden" value="1"><div><button class="btn primary">Tambah kategori</button></div>
    </form></details>
</div>
<div class="panel pad" style="margin-bottom:18px">
    <h3>Jenis usaha</h3>
    <details class="disclosure" style="margin-bottom:16px"><summary>Tambah jenis usaha</summary><form class="disclosure-body grid cols-2" method="POST" action="{{ route('admin.business-catalog.kind') }}">@csrf
        @include('admin.business-catalog.kind-fields', ['kind'=>null])<div><button class="btn primary">Tambah jenis usaha</button></div>
    </form></details>
    <form method="GET" class="filters"><input name="search" placeholder="Cari jenis usaha" aria-label="Cari jenis usaha" value="{{ request('search') }}"><select name="category" aria-label="Filter kategori"><option value="">Semua kategori</option>@foreach($categories as $c)<option value="{{ $c->id }}" @selected(request('category')===$c->id)>{{ $c->name }}</option>@endforeach</select><button class="btn secondary">Cari</button></form>
    @foreach($kinds as $kind)<details class="disclosure" style="margin-top:8px"><summary>{{ $kind->name }} · {{ $kind->category->name }} {{ $kind->active ? '' : '(Nonaktif)' }}</summary>
        <form class="disclosure-body grid cols-2" method="POST" action="{{ route('admin.business-catalog.kind',$kind) }}">@csrf @include('admin.business-catalog.kind-fields')<div><button class="btn primary">Simpan jenis usaha</button></div></form>
    </details>@endforeach
    <div class="pagination">{{ $kinds->onEachSide(1)->links('admin.partials.pagination') }}</div>
</div>
<div class="panel pad">
    <details class="disclosure" @if(request()->has('review_page')) open @endif><summary>Perlu ditinjau · {{ number_format($reviewCount) }} profil</summary><div class="disclosure-body">
        <p class="muted">Pilih jenis usaha hanya jika keterangan lama sudah jelas. Isian campuran atau catatan non-usaha dapat dibiarkan sampai dikonfirmasi. Pemetaan mempertahankan keterangan asli dan koordinat.</p>
        @forelse($review as $row)<details class="disclosure" style="margin-top:8px"><summary>{{ $row->business_type ?: '(Kosong)' }} · {{ $row->total }} profil</summary>
            <form method="POST" class="disclosure-body" action="{{ route('admin.business-catalog.map') }}">@csrf
                <input type="hidden" name="source" value="{{ $row->business_type }}">
                @include('admin.business-catalog.select', ['required'=>true])
                <button class="btn primary" style="margin-top:12px">Petakan {{ $row->total }} profil</button>
            </form>
        </details>@empty<p>Semua profil sudah dipetakan.</p>@endforelse
        <div class="pagination">{{ $review->onEachSide(1)->links('admin.partials.pagination') }}</div>
    </div></details>
</div>
<script type="application/json" id="business-catalog-data">@json($businessOptions)</script>
<script src="{{ asset('js/business-catalog.js') }}?v=20261022" defer></script>
@endsection
