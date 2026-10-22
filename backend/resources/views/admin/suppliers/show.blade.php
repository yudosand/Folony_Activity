@extends('admin.layouts.app')
@php
    $title = $heading = 'Detail Supplier';
    $subheading = $supplier->name;
@endphp
@section('content')
<div class="panel pad">
    <a class="btn secondary" href="{{ route('admin.suppliers.index') }}">Kembali ke daftar</a>
    <div class="grid cols-2" style="margin-top:20px">
        <div><label>Nama Supplier</label><p>{{ $supplier->name }}</p></div>
        <div><label>Nama PIC supplier</label><p>{{ $supplier->pic_name ?: 'Belum diisi' }}</p></div>
        <div><label>PIC Pembuat</label><p>{{ $supplier->creator?->full_name ?? '—' }} · {{ \App\Support\Workflow\UserRole::label($supplier->creator?->role) }}</p></div>
        <div><label>No. HP</label><p>{{ $supplier->phone_number }}</p></div>
        <div><label>Dibuat</label><p>{{ $supplier->created_at->timezone('Asia/Jakarta')->format('d/m/Y H:i:s') }} WIB</p></div>
        <div><label>Wilayah</label><p>{{ implode(' / ', array_filter([$supplier->territory_province, $supplier->territory_city, $supplier->territory_district])) ?: 'Wilayah belum tersedia' }}</p></div>
        <div><label>Alamat</label><p style="white-space:pre-wrap">{{ $supplier->address ?: 'Menggunakan titik lokasi' }}</p></div>
        <div><label>Jenis kebutuhan</label><ul>@foreach($supplier->items as $item)<li>{{ $item }}</li>@endforeach</ul></div>
        <div><label>Keterangan / Catatan</label><p style="white-space:pre-wrap">{{ $supplier->notes ?: '—' }}</p></div>
        <div><label>Lokasi</label>@if($supplier->latitude !== null && $supplier->longitude !== null)
            <p>{{ $supplier->latitude }}, {{ $supplier->longitude }}</p>
            <a class="btn secondary" href="https://www.google.com/maps/search/?api=1&amp;query={{ rawurlencode($supplier->latitude.','.$supplier->longitude) }}" target="_blank" rel="noopener">Buka di Google Maps</a>
        @else<p>Alamat manual, belum ada titik peta.</p>@endif</div>
    </div>
</div>
@endsection
