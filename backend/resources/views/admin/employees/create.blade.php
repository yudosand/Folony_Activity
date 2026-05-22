@extends('admin.layouts.app')

@php
    $title = 'Tambah Karyawan';
    $heading = 'Tambah Karyawan';
    $subheading = 'Gunakan form ini untuk mendaftarkan akun mobile baru dari sisi HR.';
@endphp

@section('content')
    @if($errors->any())
        <div class="error-banner">{{ $errors->first() }}</div>
    @endif
    <div class="grid cols-2">
        <div class="panel pad">
            <div class="eyebrow" style="margin-bottom:10px;">Master Data</div>
            <h3 style="margin:0 0 10px;">Profil Karyawan Baru</h3>
            <p class="muted" style="margin:0;">Isi identitas, role, lokasi kerja, saldo cuti awal, dan akses login mobile secara lengkap.</p>
        </div>
        <div class="panel pad">
            <form method="POST" action="{{ $action }}">
                @include('admin.employees._form')
            </form>
        </div>
    </div>
@endsection
