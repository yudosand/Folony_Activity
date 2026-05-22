@extends('admin.layouts.app')

@section('content')
    <div style="min-height:100vh;display:grid;place-items:center;padding:24px;background:
        radial-gradient(circle at top left, rgba(248,106,16,0.20), transparent 22%),
        linear-gradient(135deg,#2f5b2d,#234724);">
        <div class="panel pad" style="width:min(500px,100%);background:linear-gradient(180deg,rgba(255,253,249,0.98),rgba(255,247,240,0.98));">
            <div class="pill" style="margin-bottom:18px;background:#fff0e5;color:#f86a10;border:1px solid rgba(248,106,16,0.12);">Akses khusus HR</div>
            <h1 style="margin:0 0 8px;">Login Web Admin</h1>
            <p class="muted" style="margin:0 0 24px;">Gunakan akun HR untuk mengelola karyawan, absensi, cuti, dan monitoring aktivitas lapangan Folony.</p>

            @if($errors->any())
                <div class="error-banner">{{ $errors->first() }}</div>
            @endif

            <form method="POST" action="{{ route('admin.login.store') }}" class="grid">
                @csrf
                <div>
                    <label for="identifier">Email / Nomor HP / Kode Karyawan</label>
                    <input id="identifier" name="identifier" value="{{ old('identifier', 'hr@hex.local') }}" required>
                </div>
                <div>
                    <label for="password">Password</label>
                    <input id="password" name="password" type="password" value="123456" required>
                </div>
                <button type="submit" class="btn primary">Masuk ke Web Admin</button>
            </form>
        </div>
    </div>
@endsection
