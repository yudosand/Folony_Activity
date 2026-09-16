@extends('admin.layouts.app')
@php
    $title = 'Detail Absensi Harian';
    $heading = 'Absensi — '.($day['user']?->full_name ?? $day['user_id']);
    $subheading = \Illuminate\Support\Carbon::parse($day['date'])->format('d M Y').' · '.config('app.timezone');
@endphp
@section('content')
    <div class="toolbar"><a class="btn secondary" href="{{ route('admin.attendance.index', ['date' => $day['date']]) }}">Kembali ke rekap harian</a></div>
    <div class="panel pad">
        <h3>Total waktu kerja: {{ $day['duration_label'] }}</h3>
        <p class="muted">Durasi dari pasangan check-in/check-out yang berhasil. Jeda dan sesi yang belum selesai tidak dihitung. Interval bertumpang tindih dihitung satu kali.</p>
        @if($day['open_sessions'])<p>Ada {{ $day['open_sessions'] }} sesi yang belum selesai.</p>@endif
        @include('admin.attendance.records')
    </div>
@endsection
