@extends('admin.layouts.app')

@section('content')
    <div class="topbar">
        <div>
            <h1 style="margin:0;">FAQ Aplikasi</h1>
            <p class="muted" style="margin:6px 0 0;">HR bisa menambah, mengubah, dan menonaktifkan panduan yang tampil di aplikasi semua role.</p>
        </div>
    </div>

    @if($errors->any())
        <div class="error-banner">{{ $errors->first() }}</div>
    @endif

    <div class="grid cols-2">
        <section class="panel pad">
            <h3 style="margin:0 0 16px;">Tambah FAQ</h3>
            <form method="POST" action="{{ route('admin.faqs.store') }}" class="grid">
                @csrf
                <div>
                    <label for="title">Judul</label>
                    <input id="title" name="title" value="{{ old('title') }}" placeholder="Contoh: Cara Absensi" required>
                </div>
                <div>
                    <label for="body">Isi FAQ</label>
                    <textarea id="body" name="body" rows="8" placeholder="Tulis langkah-langkahnya..." required>{{ old('body') }}</textarea>
                </div>
                <div>
                    <label for="sort_order">Urutan</label>
                    <input id="sort_order" name="sort_order" type="number" min="0" value="{{ old('sort_order', 0) }}">
                </div>
                <label style="display:flex;align-items:center;gap:10px;margin:0;">
                    <input type="checkbox" name="is_active" value="1" checked style="width:auto;">
                    Aktif dan tampil di aplikasi
                </label>
                <div>
                    <button class="btn primary" type="submit">Simpan FAQ</button>
                </div>
            </form>
        </section>

        <section class="panel pad">
            <h3 style="margin:0 0 16px;">Daftar FAQ</h3>
            <div class="grid">
                @forelse($faqs as $faq)
                    <details class="panel pad" style="box-shadow:none;">
                        <summary style="cursor:pointer;font-weight:800;">{{ $faq->title }}</summary>
                        <form method="POST" action="{{ route('admin.faqs.update', $faq) }}" class="grid" style="margin-top:16px;">
                            @csrf
                            @method('PUT')
                            <div>
                                <label>Judul</label>
                                <input name="title" value="{{ old('title', $faq->title) }}" required>
                            </div>
                            <div>
                                <label>Isi FAQ</label>
                                <textarea name="body" rows="7" required>{{ old('body', $faq->body) }}</textarea>
                            </div>
                            <div>
                                <label>Urutan</label>
                                <input name="sort_order" type="number" min="0" value="{{ old('sort_order', $faq->sort_order) }}">
                            </div>
                            <label style="display:flex;align-items:center;gap:10px;margin:0;">
                                <input type="checkbox" name="is_active" value="1" @checked($faq->is_active) style="width:auto;">
                                Aktif
                            </label>
                            <div>
                                <button class="btn primary" type="submit">Update</button>
                            </div>
                        </form>
                        <form method="POST" action="{{ route('admin.faqs.destroy', $faq) }}" onsubmit="return confirm('Hapus FAQ ini?');" style="margin-top:10px;">
                            @csrf
                            @method('DELETE')
                            <button class="btn secondary" type="submit">Hapus</button>
                        </form>
                    </details>
                @empty
                    <div class="muted">Belum ada FAQ.</div>
                @endforelse
            </div>
            <div class="pagination">{{ $faqs->links() }}</div>
        </section>
    </div>
@endsection
