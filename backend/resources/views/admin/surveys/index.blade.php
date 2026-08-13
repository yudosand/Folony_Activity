@extends('admin.layouts.app', ['title' => 'Survey'])

@section('content')
    <div class="topbar">
        <div>
            <h1 style="margin:0;">Survey</h1>
            <p class="muted" style="margin:6px 0 0;">HR bisa melihat hasil Survey Kios dan Survey Harga dari aplikasi mobile.</p>
        </div>
    </div>

    @if(session('status'))
        <div class="status-banner">{{ session('status') }}</div>
    @endif

    @if($errors->any())
        <div class="error-banner">{{ $errors->first() }}</div>
    @endif

    <div class="grid cols-2" style="margin-bottom: 20px;">
        <section class="panel pad">
            <h3 style="margin-top:0;">Produk Survey Kios</h3>
            <form method="POST" action="{{ route('admin.surveys.products.store') }}" class="filters" style="margin-bottom: 14px;">
                @csrf
                <input name="name" placeholder="Nama produk, contoh: Beras premium" required>
                <button class="btn primary" type="submit">Tambah Produk</button>
            </form>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Produk</th>
                            <th>Status</th>
                            <th>Aksi</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($products as $product)
                            <tr>
                                <td>{{ $product->name }}</td>
                                <td><span class="pill success">{{ $product->is_active ? 'Aktif' : 'Nonaktif' }}</span></td>
                                <td>
                                    <form method="POST" action="{{ route('admin.surveys.products.destroy', $product) }}" onsubmit="return confirm('Hapus produk survey ini?')">
                                        @csrf
                                        @method('DELETE')
                                        <button class="btn secondary" type="submit">Hapus</button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="3" class="muted">Belum ada produk.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </section>

        <section class="panel pad">
            <h3 style="margin-top:0;">Komoditas Survey Harga</h3>
            <form method="POST" action="{{ route('admin.surveys.commodities.store') }}" class="filters" style="margin-bottom: 14px;">
                @csrf
                <input name="name" placeholder="Nama komoditas, contoh: Cabai rawit" required>
                <input name="unit" placeholder="Satuan, contoh: kg">
                <button class="btn primary" type="submit">Tambah Komoditas</button>
            </form>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Komoditas</th>
                            <th>Satuan</th>
                            <th>Aksi</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($commodities as $commodity)
                            <tr>
                                <td>{{ $commodity->name }}</td>
                                <td>{{ $commodity->unit ?: '-' }}</td>
                                <td>
                                    <form method="POST" action="{{ route('admin.surveys.commodities.destroy', $commodity) }}" onsubmit="return confirm('Hapus komoditas survey ini?')">
                                        @csrf
                                        @method('DELETE')
                                        <button class="btn secondary" type="submit">Hapus</button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr><td colspan="3" class="muted">Belum ada komoditas.</td></tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </section>
    </div>

    <section class="panel pad">
        <div class="toolbar">
            <div>
                <h3 style="margin:0;">Data Survey Masuk</h3>
                <p class="muted" style="margin:4px 0 0;">Foto, wilayah, dan detail isian tersimpan untuk audit HR.</p>
            </div>
        </div>

        <form method="GET" class="filters" style="margin-bottom: 16px;">
            <input name="search" value="{{ $filters['search'] ?? '' }}" placeholder="Cari user / kota / kecamatan / kelurahan">
            <select name="type">
                <option value="">Semua survey</option>
                @foreach($types as $value => $label)
                    <option value="{{ $value }}" @selected(($filters['type'] ?? '') === $value)>{{ $label }}</option>
                @endforeach
            </select>
            <button class="btn secondary" type="submit">Filter</button>
        </form>

        <div class="table-wrap">
            <table>
                <thead>
                    <tr>
                        <th>Survey</th>
                        <th>Pengirim</th>
                        <th>Wilayah</th>
                        <th>Detail</th>
                        <th>Foto</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse($responses as $response)
                        @php
                            $payload = $response->payload ?? [];
                            $photo = $response->photo_attachment ?? [];
                            $photoUrl = $photo['url'] ?? null;
                        @endphp
                        <tr>
                            <td class="stack">
                                <strong>{{ $types[$response->type] ?? $response->type }}</strong>
                                <span class="muted">{{ optional($response->submitted_at)->format('d M Y H:i') }}</span>
                            </td>
                            <td class="stack">
                                <strong>{{ $response->user_name }}</strong>
                                <span class="muted">{{ $roleLabels[$response->user_role] ?? $response->user_role }} · {{ $response->area_name ?: '-' }}</span>
                            </td>
                            <td>
                                {{ $response->territory_subdistrict }},
                                {{ $response->territory_district }},
                                {{ $response->territory_city }},
                                {{ $response->territory_province }}
                            </td>
                            <td>
                                @if($response->type === 'kios')
                                    <div class="stack">
                                        <strong>{{ $payload['kiosk_name'] ?? '-' }}</strong>
                                        <span>Pemilik: {{ $payload['owner_name'] ?? '-' }}</span>
                                        <span>HP: {{ $payload['phone_number'] ?? '-' }}</span>
                                        <span>Produk: {{ collect($payload['products'] ?? [])->pluck('name')->join(', ') ?: '-' }}</span>
                                        @if(!empty($payload['other_product']))
                                            <span>Lainnya: {{ $payload['other_product'] }}</span>
                                        @endif
                                        <span>Bangunan: {{ implode(', ', $payload['building_types'] ?? []) ?: '-' }}</span>
                                        <span>Luas: {{ implode(', ', $payload['kiosk_sizes'] ?? []) ?: '-' }}</span>
                                    </div>
                                @else
                                    <div class="stack">
                                        <strong>{{ $payload['market_name'] ?? '-' }}</strong>
                                        @foreach(($payload['commodity_prices'] ?? []) as $price)
                                            @php
                                                $lowestPrice = (float) ($price['lowest_price'] ?? $price['price'] ?? 0);
                                                $highestPrice = (float) ($price['highest_price'] ?? $price['price'] ?? 0);
                                            @endphp
                                            <span>{{ $price['commodity_name'] ?? '-' }}: Rp {{ number_format($lowestPrice, 0, ',', '.') }} - Rp {{ number_format($highestPrice, 0, ',', '.') }}{{ !empty($price['unit']) ? ' / ' . $price['unit'] : '' }}</span>
                                        @endforeach
                                    </div>
                                @endif
                            </td>
                            <td>
                                @if($photoUrl)
                                    <a class="attachment-link" href="{{ $photoUrl }}" target="_blank" rel="noreferrer">Buka foto</a>
                                @else
                                    <span class="muted">Tidak ada foto</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr><td colspan="5" class="muted">Belum ada data survey.</td></tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        <div class="pagination">{{ $responses->links() }}</div>
    </section>
@endsection
