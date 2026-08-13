@extends('admin.layouts.app')

@section('content')
    <div class="topbar">
        <div>
            <h1 style="margin:0;">Announcement</h1>
            <p class="muted" style="margin:6px 0 0;">HR bisa menulis pengumuman yang tampil di Home aplikasi karyawan.</p>
        </div>
    </div>

    @if(session('status'))
        <div class="status-banner">{{ session('status') }}</div>
    @endif

    @if($errors->any())
        <div class="error-banner">{{ $errors->first() }}</div>
    @endif

    <div class="grid cols-2">
        <section class="panel pad">
            <h3 style="margin:0 0 16px;">Tulis Announcement</h3>
            <form method="POST" action="{{ route('admin.announcements.store') }}" class="grid">
                @csrf
                <div>
                    <label for="title">Judul</label>
                    <input id="title" name="title" value="{{ old('title') }}" placeholder="Contoh: Briefing pagi tim operasional" required>
                </div>
                <div>
                    <label for="body">Isi pengumuman</label>
                    <textarea id="body" name="body" rows="6" placeholder="Tulis pesan singkat untuk tim..." required>{{ old('body') }}</textarea>
                </div>
                <label style="display:flex;align-items:center;gap:10px;margin:0;">
                    <input type="checkbox" name="is_active" value="1" checked style="width:auto;">
                    Aktif dan tampil di aplikasi
                </label>
                <div>
                    <button class="btn primary" type="submit">Publikasikan</button>
                </div>
            </form>
        </section>

        <section class="panel pad">
            <h3 style="margin:0 0 16px;">Announcement Aktif</h3>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Judul</th>
                            <th>Status</th>
                            <th>Tanggal</th>
                            <th>Aksi</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse($announcements as $announcement)
                            <tr>
                                <td>
                                    <strong>{{ $announcement->title }}</strong>
                                    <div class="muted" style="margin-top:4px;">{{ \Illuminate\Support\Str::limit($announcement->body, 110) }}</div>
                                </td>
                                <td>
                                    <span class="pill {{ $announcement->is_active ? 'success' : 'warning' }}">
                                        {{ $announcement->is_active ? 'Aktif' : 'Nonaktif' }}
                                    </span>
                                </td>
                                <td>{{ optional($announcement->published_at ?? $announcement->created_at)->timezone('Asia/Jakarta')->format('d M Y H:i') }}</td>
                                <td>
                                    <form method="POST" action="{{ route('admin.announcements.destroy', $announcement) }}" onsubmit="return confirm('Hapus announcement ini?');">
                                        @csrf
                                        @method('DELETE')
                                        <button class="btn secondary" type="submit">Hapus</button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="4" class="muted">Belum ada announcement.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
            <div class="pagination">{{ $announcements->links() }}</div>
        </section>
    </div>
@endsection
