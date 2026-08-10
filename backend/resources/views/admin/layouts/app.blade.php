<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'Folony Activity Admin' }}</title>
    <link rel="icon" href="{{ asset('favicon.ico') }}?v=folony-20260805" sizes="any">
    <link rel="icon" type="image/png" href="{{ asset('favicon.png') }}?v=folony-20260805">
    <style>
        :root {
            --bg: #f6f2ea;
            --surface: #fffdf9;
            --surface-alt: #f3ece1;
            --line: #e4d7c6;
            --text: #213224;
            --muted: #6e7667;
            --primary: #2f5b2d;
            --primary-deep: #234724;
            --primary-soft: #e7efe1;
            --accent: #f86a10;
            --accent-soft: #fff0e5;
            --danger: #b84b32;
            --success: #2f7f57;
            --warning: #d97706;
            --shadow: 0 20px 45px rgba(57, 50, 35, 0.08);
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: Arial, Helvetica, sans-serif;
            background:
                radial-gradient(circle at top left, rgba(248, 106, 16, 0.08), transparent 24%),
                linear-gradient(180deg, #faf7f1 0%, var(--bg) 100%);
            color: var(--text);
        }
        a { color: inherit; text-decoration: none; }
        .shell { min-height: 100vh; display: grid; grid-template-columns: 292px minmax(0, 1fr); }
        .sidebar {
            background:
                linear-gradient(180deg, rgba(248, 106, 16, 0.12) 0%, rgba(248, 106, 16, 0) 20%),
                linear-gradient(180deg, var(--primary) 0%, var(--primary-deep) 100%);
            color: #f7f5ef;
            padding: 30px 22px;
            position: relative;
            overflow: hidden;
        }
        .sidebar::after {
            content: '';
            position: absolute;
            right: -55px;
            bottom: -40px;
            width: 220px;
            height: 220px;
            background: radial-gradient(circle, rgba(248, 106, 16, 0.18), transparent 60%);
            pointer-events: none;
        }
        .brand {
            font-size: 25px;
            font-weight: 800;
            margin-bottom: 8px;
            letter-spacing: 0.02em;
        }
        .brand small {
            display: block;
            color: rgba(247, 245, 239, 0.74);
            font-size: 13px;
            margin-top: 6px;
        }
        .nav { margin-top: 28px; display: grid; gap: 10px; }
        .nav a {
            padding: 13px 14px;
            border-radius: 14px;
            color: rgba(247, 245, 239, 0.84);
            border: 1px solid transparent;
            transition: 160ms ease;
        }
        .nav a.active, .nav a:hover {
            background: rgba(255,255,255,0.08);
            color: #fff;
            border-color: rgba(248, 106, 16, 0.28);
            transform: translateX(2px);
        }
        .content { padding: 32px; }
        .topbar { display: flex; justify-content: space-between; align-items: center; gap: 16px; margin-bottom: 24px; }
        .panel {
            background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(255,253,249,0.98));
            border: 1px solid var(--line);
            border-radius: 22px;
            box-shadow: var(--shadow);
        }
        .panel.pad { padding: 24px; }
        .grid { display: grid; gap: 18px; }
        .grid.cols-4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }
        .grid.cols-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
        .grid.cols-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .card-kpi {
            padding: 20px;
            border-radius: 18px;
            background:
                linear-gradient(135deg, rgba(248, 106, 16, 0.08), rgba(255,255,255,0) 44%),
                linear-gradient(180deg, #fffefb, #fffaf5);
            border: 1px solid var(--line);
            position: relative;
        }
        .card-kpi::before {
            content: '';
            position: absolute;
            inset: 0 auto 0 0;
            width: 6px;
            border-radius: 18px 0 0 18px;
            background: linear-gradient(180deg, var(--accent), var(--primary));
        }
        .card-kpi .label { color: var(--muted); font-size: 13px; margin-bottom: 10px; }
        .card-kpi .value { font-size: 32px; font-weight: 800; }
        .muted { color: var(--muted); }
        .pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 7px 12px;
            border-radius: 999px;
            font-size: 13px;
            background: var(--surface-alt);
            color: var(--text);
            border: 1px solid rgba(47, 91, 45, 0.08);
        }
        .pill.success { background: #e8f5ee; color: var(--success); }
        .pill.warning { background: var(--accent-soft); color: var(--warning); }
        .pill.danger { background: #fde9e3; color: var(--danger); }
        .actions { display: flex; gap: 10px; flex-wrap: wrap; }
        .btn, button.btn {
            border: 0;
            cursor: pointer;
            padding: 11px 16px;
            border-radius: 14px;
            font-weight: 700;
            transition: 160ms ease;
        }
        .btn:hover, button.btn:hover { transform: translateY(-1px); }
        .btn.primary {
            background: linear-gradient(135deg, var(--accent), #ff7c29);
            color: #fff;
            box-shadow: 0 10px 24px rgba(248, 106, 16, 0.22);
        }
        .btn.secondary {
            background: var(--primary-soft);
            color: var(--primary-deep);
            border: 1px solid rgba(47, 91, 45, 0.10);
        }
        .btn.warn {
            background: linear-gradient(135deg, var(--primary), #3d6f3b);
            color: #fff;
            box-shadow: 0 10px 24px rgba(47, 91, 45, 0.18);
        }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 14px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }
        tbody tr { transition: background 120ms ease; }
        tbody tr:hover { background: rgba(248, 106, 16, 0.04); }
        th { font-size: 13px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted); }
        .table-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 18px; }
        .table-wrap table { min-width: 780px; }
        .stack { display: grid; gap: 6px; }
        .eyebrow { font-size: 12px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); }
        .toolbar {
            display: flex;
            justify-content: space-between;
            gap: 16px;
            align-items: center;
            margin-bottom: 18px;
            padding-bottom: 4px;
        }
        .filters { display: flex; gap: 10px; flex-wrap: wrap; }
        input, select, textarea {
            width: 100%;
            border: 1px solid var(--line);
            border-radius: 14px;
            padding: 12px 14px;
            font-size: 14px;
            background: rgba(255,255,255,0.88);
            color: var(--text);
            outline: none;
            transition: 160ms ease;
        }
        input:focus, select:focus, textarea:focus {
            border-color: rgba(248, 106, 16, 0.48);
            box-shadow: 0 0 0 4px rgba(248, 106, 16, 0.08);
        }
        label { display: block; font-size: 13px; font-weight: 700; margin-bottom: 8px; color: var(--muted); }
        .form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; }
        .form-grid .full { grid-column: 1 / -1; }
        .status-banner {
            padding: 14px 16px;
            margin-bottom: 18px;
            border-radius: 16px;
            background: linear-gradient(135deg, rgba(47, 91, 45, 0.12), rgba(255,255,255,0.92));
            color: var(--primary);
            font-weight: 700;
            border: 1px solid rgba(47, 91, 45, 0.12);
        }
        .error-banner {
            padding: 12px 16px;
            margin-bottom: 16px;
            border-radius: 16px;
            background: #fff1ec;
            color: var(--danger);
            border: 1px solid rgba(184, 75, 50, 0.16);
        }
        .detail-list { display: grid; gap: 12px; }
        .detail-item { display: grid; grid-template-columns: 180px minmax(0, 1fr); gap: 12px; }
        .metric-inline { display: flex; gap: 18px; flex-wrap: wrap; color: var(--muted); font-size: 13px; }
        .pagination {
            margin-top: 16px;
            border-top: 1px solid var(--line);
            padding-top: 14px;
        }
        .pagination nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }
        .pagination nav > div:first-child {
            color: var(--muted);
            font-size: 13px;
        }
        .pagination nav > div:last-child {
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
        }
        .pagination a,
        .pagination nav > div:last-child > span,
        .pagination [aria-current="page"] > span {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 42px;
            height: 42px;
            padding: 0 14px;
            border-radius: 12px;
            border: 1px solid var(--line);
            background: rgba(255,255,255,0.96);
            color: var(--text);
            font-size: 14px;
            font-weight: 700;
            line-height: 1;
            transition: 160ms ease;
        }
        .pagination a:hover {
            background: var(--primary-soft);
            border-color: rgba(47, 91, 45, 0.18);
            color: var(--primary-deep);
        }
        .pagination [aria-current="page"] > span {
            background: linear-gradient(135deg, var(--primary), #3d6f3b);
            border-color: rgba(47, 91, 45, 0.28);
            color: #fff;
            box-shadow: 0 10px 24px rgba(47, 91, 45, 0.16);
        }
        .pagination nav > div:last-child > span {
            color: var(--muted);
            background: rgba(243, 236, 225, 0.7);
        }
        .pagination svg {
            width: 16px;
            height: 16px;
            flex: 0 0 16px;
        }
        .attachment-gallery {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
            gap: 14px;
        }
        .attachment-card {
            display: grid;
            gap: 10px;
            padding: 14px;
            border-radius: 18px;
            border: 1px solid var(--line);
            background: linear-gradient(180deg, #fffefb, #fff9f1);
        }
        .attachment-card img {
            width: 100%;
            height: 118px;
            object-fit: cover;
            border-radius: 12px;
            border: 1px solid rgba(47, 91, 45, 0.08);
            background: #fff;
        }
        .attachment-meta {
            display: grid;
            gap: 4px;
            min-width: 0;
        }
        .attachment-name {
            font-size: 13px;
            font-weight: 700;
            color: var(--text);
            overflow-wrap: anywhere;
        }
        .attachment-link {
            color: var(--primary);
            font-size: 13px;
            font-weight: 700;
        }
        .note-callout {
            padding: 14px 16px;
            border-radius: 16px;
            border: 1px solid rgba(248, 106, 16, 0.14);
            background: linear-gradient(135deg, rgba(248, 106, 16, 0.08), rgba(255,255,255,0.96));
        }
        @media (max-width: 1080px) {
            .shell { grid-template-columns: 1fr; }
            .sidebar { padding-bottom: 0; }
            .grid.cols-4, .grid.cols-3, .grid.cols-2, .form-grid { grid-template-columns: 1fr; }
            .detail-item { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    @if(request()->routeIs('admin.login'))
        @yield('content')
    @else
        <div class="shell">
            <aside class="sidebar">
                <div class="brand">Folony Activity<small>Web Admin HR</small></div>
                <div class="muted" style="color:rgba(247,245,239,0.74);">Monitoring karyawan, absensi, cuti, dan aktivitas lapangan.</div>
                <nav class="nav">
                    <a href="{{ route('admin.dashboard') }}" class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">Dashboard</a>
                    <a href="{{ route('admin.employees.index') }}" class="{{ request()->routeIs('admin.employees.*') ? 'active' : '' }}">Master Karyawan</a>
                    <a href="{{ route('admin.attendance.index') }}" class="{{ request()->routeIs('admin.attendance.*') ? 'active' : '' }}">Monitoring Absensi</a>
                    <a href="{{ route('admin.leaves.index') }}" class="{{ request()->routeIs('admin.leaves.*') ? 'active' : '' }}">Cuti / Izin</a>
                    <a href="{{ route('admin.wfa.index') }}" class="{{ request()->routeIs('admin.wfa.*') ? 'active' : '' }}">Monitoring WFA</a>
                    <a href="{{ route('admin.approvals.index') }}" class="{{ request()->routeIs('admin.approvals.*') ? 'active' : '' }}">Approval Center</a>
                    <a href="{{ route('admin.network.index') }}" class="{{ request()->routeIs('admin.network.*') ? 'active' : '' }}">Monitoring Jaringan</a>
                    <a href="{{ route('admin.reports.index') }}" class="{{ request()->routeIs('admin.reports.*') ? 'active' : '' }}">Laporan HR</a>
                </nav>
            </aside>
            <main class="content">
                <div class="topbar">
                    <div>
                        <h1 style="margin:0 0 6px;">{{ $heading ?? 'Folony Activity Admin' }}</h1>
                        @isset($subheading)
                            <div class="muted">{{ $subheading }}</div>
                        @endisset
                    </div>
                    <div class="actions">
                        <div class="pill">{{ auth()->user()->full_name }} &middot; {{ \App\Support\Workflow\UserRole::label(auth()->user()->role) }}</div>
                        <form method="POST" action="{{ route('admin.logout') }}">
                            @csrf
                            <button type="submit" class="btn secondary">Logout</button>
                        </form>
                    </div>
                </div>
                @if(session('status'))
                    <div class="status-banner">{{ session('status') }}</div>
                @endif
                @yield('content')
            </main>
        </div>
    @endif
</body>
</html>
