@extends('admin.layouts.app')
@php
    $title = $heading = 'Daftar Supplier';
    $subheading = 'Semua supplier dari aplikasi dan HR, dengan PIC pembuat serta lokasi.';
@endphp
@section('content')
<div class="panel pad">
    <div class="toolbar">
        <div><strong>{{ number_format($suppliers->total(), 0, ',', '.') }} supplier</strong><p class="muted">Sesuai filter yang dipilih.</p></div>
        <a class="btn primary" href="{{ route('admin.suppliers.create') }}">Tambah Supplier</a>
    </div>
    <details class="disclosure" style="margin-bottom:20px">
        <summary>Filter supplier @if(array_filter($filters)) · Filter aktif @endif</summary>
        <form class="grid cols-2" method="GET" style="margin-top:14px">
            <div><label for="search">Nama supplier / PIC</label><input id="search" name="search" maxlength="255" value="{{ $filters['search'] ?? '' }}"></div>
            <div><label for="needs">Kebutuhan / Barang</label><input id="needs" name="needs" maxlength="255" placeholder="Contoh: tepung" value="{{ $filters['needs'] ?? '' }}"><small class="muted">Daftar dan peta menampilkan supplier dengan barang yang dicari.</small></div>
            @foreach(['province' => 'Provinsi', 'city' => 'Kota/Kabupaten', 'district' => 'Kecamatan'] as $level => $label)
                <div><label for="{{ $level }}">{{ $label }}</label><select id="{{ $level }}" name="{{ $level }}"><option value="">Semua {{ $label }}</option>
                    @foreach($regions->pluck('territory_'.$level)->filter()->unique()->sort() as $value)
                        <option @selected(($filters[$level] ?? '') === $value) value="{{ $value }}">{{ $value }}</option>
                    @endforeach
                </select></div>
            @endforeach
            <div class="actions"><button class="btn primary">Terapkan</button><a class="btn secondary" href="{{ route('admin.suppliers.index') }}">Reset</a></div>
        </form>
    </details>
    @include('admin.network.satellite-map', ['mapTitle' => 'Peta Supplier', 'mapPointsUrl' => route('admin.suppliers.map-points', $filters), 'mapDetailLabel' => 'Lihat detail supplier'])
    <div style="overflow-x:auto"><table>
        <thead><tr><th>Supplier / HP</th><th>PIC pembuat</th><th>Wilayah / Alamat</th><th>Jenis kebutuhan</th><th>Dibuat</th><th>Detail</th></tr></thead>
        <tbody>@forelse($suppliers as $supplier)
            <tr><td><strong>{{ $supplier->name }}</strong><br>PIC supplier: {{ $supplier->pic_name ?: 'Belum diisi' }}<br>{{ $supplier->phone_number }}</td>
                <td>{{ $supplier->creator?->full_name ?? '—' }}<br><span class="muted">{{ \App\Support\Workflow\UserRole::label($supplier->creator?->role) }}</span></td>
                <td>{{ implode(', ', array_filter([$supplier->territory_district, $supplier->territory_city, $supplier->territory_province])) ?: 'Wilayah belum tersedia' }}<br><span class="muted">{{ $supplier->address ?: 'Menggunakan titik lokasi' }}</span>@if($supplier->latitude === null)<br><span class="muted">Belum ada titik peta</span>@endif</td>
                <td>{{ implode(', ', $supplier->items) }}</td><td>{{ $supplier->created_at->timezone('Asia/Jakarta')->format('d/m/Y H:i') }}</td>
                <td><a class="btn secondary" href="{{ route('admin.suppliers.show', $supplier) }}">Detail</a></td></tr>
        @empty<tr><td colspan="6">Belum ada supplier sesuai filter.</td></tr>@endforelse</tbody>
    </table></div>
    <div class="pagination">{{ $suppliers->onEachSide(1)->links('admin.partials.pagination') }}</div>
</div>
@endsection
