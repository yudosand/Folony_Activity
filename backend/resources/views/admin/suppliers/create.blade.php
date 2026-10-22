@extends('admin.layouts.app')
@php
    $title = $heading = 'Tambah Supplier';
    $subheading = 'PIC pembuat otomatis memakai akun HR yang sedang login.';
@endphp
@section('content')
<div class="panel pad">
    @if($errors->any())<div role="alert"><strong>Periksa data supplier:</strong><ul>@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>@endif
    <form method="POST" action="{{ route('admin.suppliers.store') }}" id="supplier-form" class="grid cols-2">
        @csrf
        <div><label for="name">Nama supplier</label><input id="name" name="name" required maxlength="255" value="{{ old('name') }}"></div>
        <div><label for="pic_name">Nama PIC supplier</label><input id="pic_name" name="pic_name" required maxlength="255" value="{{ old('pic_name') }}"></div>
        <div><label for="phone_number">No. HP</label><input id="phone_number" name="phone_number" type="tel" required maxlength="32" value="{{ old('phone_number') }}"></div>
        <div style="grid-column:1/-1">
            <details @if(in_array(old('location_source'), ['gps','map'])) open @endif id="location-panel">
                <summary>Pilih titik lokasi (opsional untuk alamat manual)</summary>
                <p class="muted">Gunakan lokasi perangkat atau klik titik supplier di peta. Pilih wilayah dan lengkapi alamat di bawah agar lokasinya jelas.</p>
                <button class="btn secondary" type="button" id="supplier-gps">Gunakan lokasi saya</button>
                <button class="btn secondary" type="button" id="supplier-clear-location">Hapus titik / alamat manual</button>
                <p id="supplier-location-status" role="status"></p>
                <div id="supplier-location-map" style="height:330px;z-index:0"></div>
            </details>
            <input type="hidden" name="location_source" id="location_source" value="{{ old('location_source', 'manual') }}">
            <input type="hidden" name="latitude" id="latitude" value="{{ old('latitude') }}">
            <input type="hidden" name="longitude" id="longitude" value="{{ old('longitude') }}">
        </div>
        @foreach(['province' => 'Provinsi', 'city' => 'Kota/Kabupaten', 'district' => 'Kecamatan'] as $level => $label)
            <div><label for="territory_{{ $level }}">{{ $label }}</label>
                <select id="territory_{{ $level }}" name="territory_{{ $level }}" required data-old="{{ old('territory_'.$level) }}">
                    <option value="{{ old('territory_'.$level) }}">{{ old('territory_'.$level) ?: 'Pilih '.$label }}</option>
                </select></div>
        @endforeach
        <div style="grid-column:1/-1"><p id="supplier-region-status" role="status" class="muted"></p><button id="supplier-region-retry" type="button" class="btn secondary" hidden>Muat ulang wilayah</button></div>
        <div style="grid-column:1/-1"><label for="address">Alamat lengkap</label><textarea id="address" name="address" required maxlength="1000" rows="3">{{ old('address') }}</textarea></div>
        <div style="grid-column:1/-1"><label>Jenis kebutuhan / Barang</label><p class="muted">Satu nama barang per kolom. Maksimal 50 barang.</p>
            <div id="supplier-items">@foreach(old('items', ['']) as $item)<div class="actions" style="margin-bottom:8px"><input name="items[]" aria-label="Nama barang" value="{{ $item }}" required maxlength="255"><button type="button" class="btn secondary remove-item">Hapus</button></div>@endforeach</div>
            <button class="btn secondary" id="supplier-add-item" type="button">Tambah barang</button></div>
        <div style="grid-column:1/-1"><label for="notes">Keterangan / Catatan (opsional)</label><textarea id="notes" name="notes" maxlength="3000" rows="3">{{ old('notes') }}</textarea></div>
        <div class="actions"><button class="btn primary" id="supplier-submit" type="submit">Simpan Supplier</button><a class="btn secondary" href="{{ route('admin.suppliers.index') }}">Batal</a></div>
    </form>
</div>
<link rel="stylesheet" href="{{ asset('vendor/leaflet/leaflet.css') }}">
<script src="{{ asset('vendor/leaflet/leaflet.js') }}"></script>
<script src="{{ asset('js/supplier-form.js') }}?v=20261022" defer></script>
@endsection
